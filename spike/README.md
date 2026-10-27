# Spike: filter architecture

Goal: choose how filters reach widgets before building further. The current
package rebuilds each widget in JavaScript from raw data, which loses R-side
styling (colours, row names, formatting, formula transforms). Two alternatives
were prototyped, both standalone (no package code), sharing the same inputs:

- **A: crosstalk.** Each input owns a `crosstalk.FilterHandle`; DT, plotly and
  ggplotly react natively to `SharedData`.
- **B: own row mask.** A small store intersects per-input key sets; adapters
  hide rows/points in the widgets R already built (DT via `ext.search`, plotly
  by filtering each trace's per-point arrays by a `key` injected before
  `plotly_build()`).

Shared input layer (`common.R`, `inputs.js`): radio and dropdown with an "All"
option and a configurable default. Values are stringified once in R, so R and
JS always compare identical text. Row keys are row names in both prototypes.

## Files

| File | Purpose |
|---|---|
| `common.R`, `inputs.js` | shared inputs; call `window.qrSpikeSink(group, variable)` |
| `sink_crosstalk.js`, `a_*.qmd` | prototype A |
| `rowmask.R`, `rowmask.js`, `b_*.qmd` | prototype B |
| `measure.R`, `measure_hard.R` | headless-Edge harness (chromote): clicks filters, compares with counts computed in R |

Run from this folder:

```
quarto render a_crosstalk.qmd; quarto render b_rowmask.qmd
quarto render a_hard.qmd;     quarto render b_hard.qmd
Rscript measure.R a_crosstalk.html b_rowmask.html
Rscript measure_hard.R a_hard.html b_hard.html
```

## Results (2026-10-27)

Scenario 1 (`measure.R`): scatter coloured by `factor(cyl)` + DT, three filters,
`am` defaulting to 1, then five filter changes. Scenario 2 (`measure_hard.R`):
plotly histogram, ggplotly scatter, DT on a row subset (`mpg > 20`).

| | A: crosstalk | B: row mask |
|---|---|---|
| Correct counts, all steps, both scenarios | yes, **after a workaround** | yes |
| Default selection on load | plotly ignores a filter set before it subscribes; fixed by re-applying on `window.load` | works (store replays state to late subscribers) |
| R colours per group kept | yes | yes |
| Row names kept / row-subset tables | yes | yes |
| Histogram, ggplotly | yes, natively | yes; ggplotly needed its own key injection (`aes(key = ...)`) |
| Empty groups | trace removed from legend | trace stays in legend, empty |
| HTML size (mtcars) | 27 KB | 27 KB |
| Console errors | none | none |
| Other widgets | leaflet, reactable, etc. support crosstalk already (not tested here) | one adapter per widget type |
| APIs relied on | crosstalk's public `FilterHandle` | plotly internals (`x$visdat`, `x$attrs`), DataTables `ext.search` |
| Side effects | `SharedData` also turns on crosstalk selection/highlighting in plotly and DT (not tested here) | none |

Also found: B first gave every widget on a group the same element id, so a
second plot never rendered. The package has the same bug
(`paste0("qr-plotly-", store_id)`).

## Recommendation

Use **crosstalk as the filter bus** (A), with quartoReactive providing what
crosstalk lacks: good inputs (radio, defaults, "All", cascading later), the
pipe API, and a reliable default-on-load mechanism. For widgets without
crosstalk support (e.g. echarts), write small B-style adapters that listen on
a `crosstalk.FilterHandle` instead of a private store, so there is one bus.

API consequence: widgets bind to `SharedData` natively, so `reactive()` and the
expression-walking store detection can go. `interactive_df()` would wrap or
return a `SharedData` instead of a data.frame subclass, which changes how users
subset columns for tables (e.g. a second `SharedData` on the same group, as in
`a_crosstalk.qmd`).

Open questions before committing to A (questions 1 and 2 are partly answered by spike 2):
1. Is the selection/highlight behaviour that `SharedData` switches on acceptable,
   or must it be turned off by default?
2. Is the default-on-load workaround robust (slow pages, widgets in tabsets)?
3. Pre-aggregated charts (e.g. rates per region computed in R) cannot be
   filtered by either approach; is that in scope?

---

# Spike 2: book-wide persistent inputs (`book/`, `qrspike/`)

Goal: inputs that select municipalities across a whole Quarto book, plus a
custom htmlwidget, with crosstalk only as a bridge for standard widgets.

## Design

- `qrspike/` is a throwaway package (htmlwidgets need an installed package).
- `qr-state.js`: one store of named params (`gemeente` = array of codes).
  Persists in `sessionStorage` (survives switching chapters) and mirrors to the
  URL query (`?gemeente=GM9003,GM9005`; the URL wins on load, so links share a
  comparison). It also wires every `[data-qr-param]` input and bridges each
  param to a crosstalk `FilterHandle` on the group of the same name.
- `qr_book_includes()` (run as the book's `pre-render`) writes
  `_qr-header.html` (store + config: default selection, `always = "NL"`) and
  `_qr-sidebar.html` (a selector moved into the book sidebar on every page).
- `qr_input()` emits markup only; `qr_shared()` is `SharedData` keyed on the
  municipality code with `group = param`; `qr_iconfill()` is a custom
  htmlwidget that subscribes to the store directly.
- Data are synthetic, for fictional municipalities (`GM90xx` are not real codes).

Run: install `qrspike` (`R CMD INSTALL qrspike`), then in `book/`:
`quarto render` and `Rscript measure_book.R` (serves `_book` over HTTP).

## Results (2026-10-27): all 10 harness steps pass, no console errors

1. First visit shows the configured default in sidebar, inline input, plotly, DT.
2. Sidebar change updates the inline input, plot and table on the same page.
3. Plain navigation to another chapter restores the selection everywhere.
4. A chapter without widgets keeps and shows the selection.
5–7. An inline input change carries over to other chapters.
8. A shared link opened in a new session shows the linked selection.
9–10. Empty selection shows everything, also after navigating.

Covered along the way: duplicate crosstalk keys (one key per municipality,
many years) work in plotly and DT; R's per-group colours are stable; the
plotly "filter before subscribe" workaround holds on every page load.

## Found and fixed

- **Empty bar slots.** `plotly_build()` pins category axes to all levels, so
  plotly.js keeps gaps for filtered-out categories between visible ones. The
  bridge now shrinks each pinned axis to the present categories, in R's order.
  The harness checks the drawn categories (it caught the bug before the fix).
- **Palette warning in output** (9 groups > Set2's 8): chunk `warning: false`
  here; the real package should pick a palette that fits.

## Open for the real design

- **Mobile:** the selector works inside Quarto's slide-out sidebar, but with
  the menu closed nothing shows the current selection. Add a compact
  "Showing: A, B" bar per chapter.
- **Scale:** ~340 municipalities need a searchable multi-select (and the map
  selector), not a checkbox list.
- **Storage key:** `qr-state` is shared by every book on the same origin
  (e.g. one GitHub Pages site); namespace it per book.
- Not tested yet: leaflet, widgets inside tabsets (hidden plots have zero
  size), `quarto preview` reloads, chapters whose data lack a selected code,
  municipality mergers between data years.

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

Open questions before committing to A:
1. Is the selection/highlight behaviour that `SharedData` switches on acceptable,
   or must it be turned off by default?
2. Is the default-on-load workaround robust (slow pages, widgets in tabsets)?
3. Pre-aggregated charts (e.g. rates per region computed in R) cannot be
   filtered by either approach; is that in scope?

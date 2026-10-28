# Architecture

quartoReactive gives a Quarto book (or a single document) named **selection
parameters**, such as `gemeente`: the municipalities a reader wants to compare.
Inputs change a parameter; widgets on every page follow it. There is no server:
everything runs in the browser from the rendered HTML.

## Moving parts

```
 R (render time)                         Browser (every page)
 ───────────────                         ────────────────────
 qr_book_setup()  ── _qr-header.html ──▶ qr-state.js: the store
   params: qr_param(default, always,        values per param, colour slots
                    colors)                 ▲  persisted in sessionStorage
          ── _qr-sidebar.html ─▶ sidebar     │  mirrored to the URL query
                                 input ──────┤
 qr_select() / qr_checkbox() /               │ subscribe / set
 qr_radio()  ── markup + dependency ─────────┤
                                             │
 qr_data(df, key, param)                     ├──▶ crosstalk FilterHandle(param)
   = crosstalk SharedData(group = param) ◀───┘      plotly, DT, leaflet, ...
                                             │
 qr_iconfill(), later qr_map_select() ◀──┘ subscribe directly
```

### The store (`inst/htmlwidgets/lib/qr-state/qr-state.js`)

- One global `window.qrState`, guarded so that loading it twice (book header and
  widget dependencies) is harmless.
- **Resolution on load**, per parameter: URL query, else sessionStorage, else
  the configured `default`. The URL wins so shared links show what was shared.
- **Persistence**: sessionStorage under `qr-state:<id>`, where `id` defaults to
  the book folder name, so books on one site do not share state. Switching
  chapters is a full page load; the state comes back from storage.
- **API** for widgets: `get`, `set`, `subscribe` (fires immediately, returns an
  unsubscribe function), `always`, `visible` (selection plus `always`, or `null`
  for "show everything"), `color`, `max`.
- **Selection order**: `set` keeps keys in the order they were selected
  (inputs report display order), so the URL reads in that order and `max`
  drops the newest keys. `max` is enforced in the store as well as by each
  input, because custom widgets call `set` directly.
- **Inputs** are plain markup with `data-qr-param`; the store wires them both
  ways on `DOMContentLoaded`. A `<select data-qr-search>` is upgraded to Tom
  Select (bundled, 2.6.2) when the library is on the page, else it stays a
  plain list box. At `max`, unchecked checkboxes are disabled.
- **Selection bar** (`data-qr-bar`): chips with label, colour and a remove
  button. When sticky, it tracks the bottom of Quarto's fixed header, which
  slides in and out on narrow screens.
- **Colour slots** (only with `qr_param(colors = )`): a newly selected key takes
  the lowest free slot and keeps it while selected, so changing the selection
  never repaints other series. Slots are stored with the selection.

`qr_book_setup()` writes the include files by inlining the store plus every
htmlDependency of the `sidebar` and `top` content (e.g. Tom Select), because
include files are pasted into each page as is.

### Standard widgets: crosstalk as the bridge

For every parameter the store owns a `crosstalk.FilterHandle` on the group of
the same name, and `qr_data()` creates `SharedData` with that group and the
parameter's key column. Any crosstalk-aware widget then follows the selection
with no adapter code, and R-side styling (colours, formatting, row names) is
kept because the widget is built by its own R package.

Workarounds the bridge carries (all covered by the browser tests):

1. **Filter before subscribe.** plotly ignores a filter set before it
   subscribed; the bridge re-applies after `window.load`.
2. **Pinned category axes.** `plotly_build()` pins category axes to all levels,
   leaving gaps for filtered-out bars; the bridge shrinks the axis to the
   categories still present, in R's order.
3. **Selection colours.** Traces holding a single key are restyled to that
   key's slot colour after each filter.

### Own widgets

Widgets crosstalk cannot express (icon fill, map selector) are
htmlwidgets in this package that call `qrState.subscribe(param, fn)` and
render what `qrState.visible()` returns. They attach the store as a dependency,
so they also work in a standalone document.

## Why this design (spike results, October 2026)

The first version rebuilt widgets in JavaScript from raw data behind a
`reactive()` wrapper that walked R expressions to find the data. That lost
R-side styling and required an adapter per widget type. Two alternatives were
prototyped and measured with a headless browser:

| | crosstalk bus | own row mask |
|---|---|---|
| Correct after every filter change | yes, with workaround 1 | yes |
| Uses only public APIs | yes | no (plotly internals, DataTables `ext.search`) |
| Works for leaflet, reactable, ... | already crosstalk-aware | adapter per widget |

crosstalk lacks what a book needs (persistence across pages, defaults, radio
inputs, shareable links, custom widgets), so the store adds that and uses
crosstalk only as the bridge to standard widgets. The spike code is in git
history (`spike/`, commit ff3344e).

## Tests

- Unit tests (`tests/testthat/test-*.R`) for the R API.
- Browser tests (`test-browser.R`) render `tests/testthat/fixtures/book` with
  Quarto, serve it over HTTP (sessionStorage is unreliable on `file://`) and
  drive it with chromote: defaults, sidebar and inline inputs, navigation,
  shared links, empty selection, colour slots, console errors. When run from
  the source tree they first install the package into a temporary library, so
  Quarto's R process renders with the code under test. They skip without
  Quarto (`QUARTO_PATH`) or Chrome/Edge (`CHROMOTE_CHROME`), and on CRAN.

## Roadmap

1. ~~Core: store, bridge, inputs, book setup, icon fill, tests~~ (0.2.0)
2. ~~Searchable multi-select, selection bar, maximum selection size~~ (0.3.0)
3. ~~Icon fill: any SVG icon, fill animation~~ (0.4.0; sunburst dropped)
4. Map selector from municipality polygons (`inst/extdata/hart_voor_brabant.gpkg`)
5. Robustness: leaflet, widgets in tabsets, `quarto preview`, documentation site

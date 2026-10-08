# quartoReactive — Architecture Outline

> **Working title.** Alternatives: `reactiveDF`, `quartoLink`, `linkedWidgets`
>
> A standalone R package that provides reactive, filter-driven interactivity
> for Quarto HTML documents. Visual-agnostic core with thin per-widget adapters.
> Completely independent of `quartoWidgets`.

---

## 1. Concept

**User-facing API (3 functions):**
```r
# 1. DEFINE — data + filters as one coherent object
interactive_df <- interactive_df(mtcars) |>
  filter_on("cyl",  input = "radio",    label = "Cylinders") |>
  filter_on("gear", input = "dropdown", label = "Gears")

# 2. PLACE — render filter controls in the document
render_inputs(interactive_df)         # all at once, OR
render_input(interactive_df, "cyl")   # one by one for custom layout

# 3. CONNECT — wrap any JS widget with reactive()
reactive(plot_ly(interactive_df, x = ~mpg, y = ~hp, color = ~factor(cyl)))
reactive(datatable(interactive_df))
```

**Under the hood:**
```
┌─────────────────────────────────────────────────────────────────┐
│  Rendered HTML (client-side, no server)                          │
│                                                                 │
│  ┌──────────────┐    ┌──────────────────────────────────────┐   │
│  │ render_input │    │  ReactiveDataStore (JS)               │   │
│  │              │    │                                      │   │
│  │ radio        ├───►│  Full dataset (JSON)                 │   │
│  │ dropdown     ├───►│  Active filters: {cyl: [6], gear: …} │   │
│  │ checkbox     ├───►│  getFilteredData() → filtered rows   │   │
│  │ slider       ├───►│                                      │   │
│  └──────────────┘    │  Notifies subscribers on change       │   │
│                       └──────┬───────────┬───────────┬───────┘   │
│                              │           │           │           │
│                       reactive()  reactive()  reactive()         │
│                              │           │           │           │
│                              ▼           ▼           ▼           │
│                     ┌────────────┐ ┌──────────┐ ┌──────────┐    │
│                     │  Plotly     │ │ DT       │ │ Leaflet  │    │
│                     │  .react()   │ │ .clear() │ │ .clear() │    │
│                     └────────────┘ └──────────┘ └──────────┘    │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

The user writes standard R/Quarto code. The library:
1. Embeds the full dataset as JSON in the HTML at render time
2. Creates JS-side filter logic that runs in the browser
3. Connects inputs → data store → widget adapters (auto-detected)

No server, no Shiny, no runtime R. Everything runs client-side in the
rendered HTML file.

---

## 2. Package Structure

```
quartoReactive/
├── DESCRIPTION
├── NAMESPACE
├── LICENSE
├── R/
│   ├── interactive_df.R        # Core: interactive_df() + filter_on()
│   ├── render.R                # render_inputs(), render_input()
│   ├── reactive.R              # Universal reactive() wrapper + adapter dispatch
│   ├── adapters/
│   │   ├── plotly.R            # .adapt_plotly() — Plotly-specific logic
│   │   ├── dt.R                # .adapt_dt() — DataTables-specific logic
│   │   └── leaflet.R           # .adapt_leaflet() — Leaflet-specific logic
│   ├── dependencies.R          # htmlDependency + CDN refs
│   └── utils.R                 # Internal helpers (.as_js, .js_on_ready, etc.)
├── inst/
│   ├── js/
│   │   └── quarto-reactive.js  # Single bundled IIFE (all JS)
│   └── css/
│       └── quarto-reactive.css # Minimal default styles for inputs
├── man/                        # roxygen2 docs
└── examples/
    └── basic_example.qmd       # Working demo
```

### DESCRIPTION (key fields)

```
Package: quartoReactive
Title: Reactive Data-Driven Interactivity for Quarto HTML Documents
Version: 0.1.0
Imports:
    htmltools (>= 0.5.0),
    jsonlite
Suggests:
    plotly,
    DT,
    leaflet,
    echarts4r
```

Note: widget packages are in `Suggests`, not `Imports`. The core
works without any of them installed — adapters only load when called.

---

## 3. R API (B+C combined design)

The API has three layers:
1. **Define** — `interactive_df()` + `filter_on()` (pipe chain)
2. **Place** — `render_inputs()` / `render_input()` (emit HTML controls)
3. **Connect** — `reactive()` (universal wrapper, auto-detects widget type)

Design principles:
- `interactive_df` IS a real `data.frame` subclass — pass it directly
  to plotly, DT, leaflet. No data duplication.
- Filters are declared on the data, placed separately in the layout.
- One universal `reactive()` function instead of per-widget wrappers.
- Dependencies are injected lazily (on first `render_*` or `reactive()` call).

---

### 3.1 interactive_df()

The foundation. Returns a **data.frame subclass** with reactive metadata.

```r
interactive_df <- interactive_df(
  data,                 # A data.frame
  id = NULL,            # Unique HTML namespace (auto-generated if omitted)
  columns = NULL        # Optional: restrict which columns are serialised
                        # (reduces HTML size for wide dataframes)
)
```

**Key design decision:** the returned object IS a `data.frame`.
It works everywhere a data.frame works — `plot_ly(interactive_df, ...)`,
`datatable(interactive_df)`, `interactive_df[, cols]`, etc.

**Class chain:**
```r
class(interactive_df)
# [1] "quarto_reactive_df" "data.frame"
```

**Attributes (carried through pipe chain):**
```r
attr(interactive_df, "qr_id")        # "qr-a1b2c3" (auto-generated or user-supplied)
attr(interactive_df, "qr_meta")      # list(columns = list(cyl = "categorical", mpg = "numeric", ...))
attr(interactive_df, "qr_filters")   # list() — populated by filter_on()
attr(interactive_df, "qr_rendered")  # FALSE — flipped to TRUE on first HTML emission
```

Because it's a data.frame, standard operations work:
```r
interactive_df[, c("mpg", "cyl", "hp")]   # subset columns (still quarto_reactive_df)
subset(interactive_df, cyl == 6)            # subset rows
head(interactive_df)                        # inspect
```

**What happens at HTML emission time** (lazy, triggered by first
`render_*` or `reactive()` call that gets printed):

1. Serialises `data` as JSON inside `<script type="application/json">`
2. Serialises column metadata (names, types: categorical vs numeric)
3. Emits a boot `<script>` that creates:
   `window.__quartoReactive.stores[id] = new ReactiveDataStore(data, meta)`
4. Includes the `htmlDependency` for the JS/CSS bundle (once per document)
5. Sets `qr_rendered = TRUE` so the boot scripts are only emitted once

---

### 3.2 filter_on() — Declaring filters (pipe-friendly)

Filters are **declared** on the data object, **not** immediately rendered.
This separates data modelling from visual layout.

```r
interactive_df <- interactive_df(mtcars) |>
  filter_on("cyl",  input = "radio",    label = "Cylinders", show_all = TRUE) |>
  filter_on("gear", input = "dropdown", label = "Gears") |>
  filter_on("mpg",  input = "slider",   label = "MPG Range")
```

**Signature:**
```r
filter_on(
  .data,                  # A quarto_reactive_df object (piped in)
  variable,               # Column name to filter on (string)
  input = "dropdown",     # Input type: "radio", "dropdown", "checkbox", "slider"
  label = NULL,           # Display label (defaults to variable name)
  default = NULL,         # Pre-selected value(s)
  ...                     # Input-type-specific options:
                          #   radio:    show_all = FALSE
                          #   dropdown: multiple = FALSE, search = TRUE, placeholder = NULL
                          #   checkbox: (no extras)
                          #   slider:   min = NULL, max = NULL, step = NULL
)
```

**Returns:** the same `quarto_reactive_df` with the filter appended to
`attr(.data, "qr_filters")`. This means the pipe chain returns the
same data.frame — it's still usable as data everywhere.

**Internally, each filter is stored as:**
```r
list(
  variable = "cyl",
  input    = "radio",
  label    = "Cylinders",
  default  = NULL,
  options  = list(show_all = TRUE),
  values   = c(4, 6, 8)            # unique values, computed at declaration time
)
```

---

### 3.3 render_inputs() / render_input() — Placing filters in the layout

Filters are declared on the data but **placed** in the document
wherever the QMD designer wants them.

#### render_inputs() — Emit all filters at once

```r
render_inputs(interactive_df)
```

Emits all declared filter controls in declaration order.
Convenient for a quick "filter panel" section.

Optional layout control:
```r
render_inputs(interactive_df, layout = "inline")  # side by side (default)
render_inputs(interactive_df, layout = "stacked") # one per row
```

#### render_input() — Emit a single filter

```r
render_input(interactive_df, "cyl")
```

Emits only the filter for the specified variable.
Use this for custom layouts (e.g. Quarto column panels):

```qmd
::: {.columns}
::: {.column width="50%"}
``{r}
render_input(interactive_df, "cyl")
``
:::
::: {.column width="50%"}
``{r}
render_input(interactive_df, "gear")
``
:::
:::
```

**Both functions return** an `htmltools::tagList` that, when printed:
1. On first use: also emits the data store boot scripts (lazy injection)
2. Emits the HTML for the input control(s)
3. Emits boot script(s) connecting each input to the DataStore

---

### 3.4 reactive() — Universal visual wrapper

One function that wraps ANY supported htmlwidget and connects it
to the reactive data store. Auto-detects the widget type.

```r
reactive(
  widget,                 # Any supported htmlwidget (plotly, DT, leaflet, ...)
  mapping = NULL,         # Optional explicit column spec (see 3.5)
  ...                     # Widget-type-specific adapter options
)
```

**Usage (the common case):**

```r
# Plotly — pass interactive_df directly as data, reactive() auto-detects
reactive(plot_ly(interactive_df, x = ~mpg, y = ~hp, color = ~factor(cyl)))

# DT — same pattern
reactive(datatable(interactive_df))

# Leaflet
reactive(
  leaflet(interactive_df) |> addTiles() |> addMarkers(~lon, ~lat, popup = ~name),
  mapping = list(type = "markers", lng = "lon", lat = "lat", popup = "name")
)

# ggplotly (the ggplot workaround)
reactive(ggplotly(ggplot(interactive_df, aes(mpg, hp)) + geom_point()))
```

**How auto-detection works (inside `reactive()`):**

```r
reactive <- function(widget, mapping = NULL, ...) {
  # 1. Detect widget type from class
  adapter <- if (inherits(widget, "plotly"))     .adapt_plotly(widget, mapping, ...)
             else if (inherits(widget, "datatables")) .adapt_dt(widget, mapping, ...)
             else if (inherits(widget, "leaflet"))     .adapt_leaflet(widget, mapping, ...)
             else stop("Unsupported widget type: ", class(widget)[1])

  # 2. Extract the qr_id from the widget's data
  #    (the interactive_df was passed as data to the widget constructor)
  store_id <- .find_reactive_store(widget)
  if (is.null(store_id) && is.null(mapping))
    stop("Could not detect reactive data. Pass an interactive_df as data to the widget.")

  # 3. Return htmltools::tagList with:
  #    - The original widget (initial full-data render)
  #    - Boot script connecting the adapter to the DataStore
  #    - Data store boot scripts (if not yet emitted)
  adapter$render(store_id)
}
```

**Store discovery** — `.find_reactive_store()` scans the widget for
an `interactive_df` in its data slot:

```r
.find_reactive_store <- function(widget) {
  # Plotly: widget$x$visdat stores the original data
  # DT: widget$x$data stores the data frame
  # Leaflet: widget$x$calls contains data references
  # Each adapter knows where to look.
  data_obj <- .extract_data_from_widget(widget)
  if (inherits(data_obj, "quarto_reactive_df")) {
    return(attr(data_obj, "qr_id"))
  }
  NULL
}
```

---

### 3.5 Adapter internals (inside `reactive()`)

Each adapter is an internal module. The user never calls them directly.

#### Plotly adapter

**Auto-extraction:** plotly objects store original formulas in
`widget$x$attrs` (e.g. `list(x = ~mpg, y = ~hp, color = ~cyl)`).
The adapter parses these to build the column spec automatically.

```r
.extract_plotly_mapping <- function(widget) {
  attrs <- widget$x$attrs
  if (is.null(attrs)) return(NULL)
  a <- attrs[[1]]
  mapping <- list()
  for (prop in c("x", "y", "z", "color", "size", "text", "symbol")) {
    if (!is.null(a[[prop]]) && inherits(a[[prop]], "formula")) {
      mapping[[prop]] <- deparse(a[[prop]][[2]])
      mapping[[prop]] <- gsub("^.*\\((.+)\\)$", "\\1", mapping[[prop]])
    }
  }
  mapping$type <- a$type %||% "scatter"
  mapping$mode <- a$mode %||% "markers"
  mapping
}
```

**Explicit mapping override** (when auto-extraction fails):
```r
reactive(
  plot_ly(interactive_df, x = ~mpg, y = ~hp),
  mapping = list(x = "mpg", y = "hp", type = "scatter", mode = "markers")
)
```

**What it emits at render time:**
1. Renders the plotly widget normally (initial full-data view)
2. Assigns a known `elementId` to the plotly div
3. Serialises the column spec as an inline JSON `<script>`
4. Emits a boot script: `new PlotlyAdapter(divId, storeId, spec)`

#### DT adapter

Simplest adapter. DT displays rows directly.

```r
reactive(datatable(interactive_df[, c("mpg", "cyl", "hp", "wt")]))
```

Column list is inferred from the datatable object. On filter change:
```js
table.clear().rows.add(filteredRows).draw();
```

#### Leaflet adapter

Leaflet requires an explicit `mapping` because layer types vary.
Base map tiles and non-data layers are untouched — only the
data-driven layer group is rebuilt on filter change.

```r
reactive(
  leaflet(interactive_df) |> addTiles() |> addMarkers(~lon, ~lat),
  mapping = list(type = "markers", lng = "lon", lat = "lat", popup = "name")
)
```

On filter change:
```js
layerGroup.clearLayers();
filteredRows.forEach(row => L.marker([row.lat, row.lng]).addTo(layerGroup));
```

#### Future adapters

- **echarts4r** — `chart.setOption()` API, straightforward
- **highcharter** — `chart.series[0].setData()`, doable
- New adapters are added by implementing a single `.adapt_*()` function

---

## 4. JavaScript Architecture

Single bundled file: `inst/js/quarto-reactive.js` (IIFE)

### 4.1 Global Namespace

```js
window.__quartoReactive = {
  stores: {},              // id → ReactiveDataStore instances
  register(id, store) { ... },
  get(id) { ... }
};
```

Multiple `interactive_df()` calls in one document each get their own
namespaced DataStore. Inputs and adapters reference stores by `id`.

### 4.2 ReactiveDataStore

```js
class ReactiveDataStore {
  constructor(data, meta) {
    this._data = data;           // Full dataset (Array<Object>)
    this._meta = meta;           // Column metadata
    this._filters = new Map();   // variable → Set<value> (categorical)
    this._rangeFilters = new Map(); // variable → [min, max] (numeric)
    this._subscribers = [];      // Callback functions
    this._cache = null;          // Cached filtered result
  }

  // ── Filter API (called by inputs) ──────────────────────────

  setFilter(variable, values) {
    // values: array of allowed values (categorical)
    if (!values || values.length === 0) {
      this._filters.delete(variable);
    } else {
      this._filters.set(variable, new Set(values));
    }
    this._invalidate();
  }

  setRangeFilter(variable, range) {
    // range: [min, max] (numeric)
    this._rangeFilters.set(variable, range);
    this._invalidate();
  }

  clearFilter(variable) {
    this._filters.delete(variable);
    this._rangeFilters.delete(variable);
    this._invalidate();
  }

  clearAll() {
    this._filters.clear();
    this._rangeFilters.clear();
    this._invalidate();
  }

  // ── Data access (called by adapters) ───────────────────────

  getFilteredData() {
    if (this._cache) return this._cache;

    let rows = this._data;

    // Apply categorical filters
    for (const [variable, allowed] of this._filters) {
      rows = rows.filter(r => allowed.has(r[variable]));
    }

    // Apply range filters
    for (const [variable, [min, max]] of this._rangeFilters) {
      rows = rows.filter(r => {
        const v = r[variable];
        return v != null && v >= min && v <= max;
      });
    }

    this._cache = rows;
    return rows;
  }

  getFullData() {
    return this._data;
  }

  getColumnValues(variable) {
    // Unique values for a column (for dynamic input population)
    return [...new Set(this._data.map(r => r[variable]))]
      .filter(v => v != null)
      .sort();
  }

  getActiveFilters() {
    // Returns current filter state (for display/debug)
    const result = {};
    for (const [k, v] of this._filters) result[k] = [...v];
    for (const [k, v] of this._rangeFilters) result[k] = v;
    return result;
  }

  // ── Subscription (called by adapters) ──────────────────────

  subscribe(callback) {
    this._subscribers.push(callback);
    // Fire immediately with current data
    callback(this.getFilteredData(), this.getActiveFilters());
    // Return unsubscribe function
    return () => {
      this._subscribers = this._subscribers.filter(cb => cb !== callback);
    };
  }

  // ── Internal ───────────────────────────────────────────────

  _invalidate() {
    this._cache = null;
    const filtered = this.getFilteredData();
    const filters = this.getActiveFilters();
    this._subscribers.forEach(cb => cb(filtered, filters));
  }
}
```

### 4.3 Adapter Modules

#### PlotlyAdapter

```js
class PlotlyAdapter {
  constructor(divId, storeId, columnSpec) {
    this.div = document.getElementById(divId);
    this.spec = columnSpec;
    this._originalLayout = null;
    this._originalConfig = null;

    // Wait for plotly to finish rendering, then capture layout
    this.div.on('plotly_afterplot', () => {
      if (!this._originalLayout) {
        this._originalLayout = Plotly.makeTemplate(this.div).layout;
        // Alternatively: structuredClone(this.div.layout)
      }
    });

    // Subscribe to data store
    const store = window.__quartoReactive.get(storeId);
    store.subscribe((filteredData) => this._update(filteredData));
  }

  _update(data) {
    const traces = this._buildTraces(data);
    const layout = this._originalLayout || this.div.layout || {};
    Plotly.react(this.div, traces, layout);
  }

  _buildTraces(data) {
    // Single trace (no grouping)
    if (!this.spec.color) {
      return [{
        x: data.map(r => r[this.spec.x]),
        y: data.map(r => r[this.spec.y]),
        type: this.spec.type || 'scatter',
        mode: this.spec.mode || 'markers',
        ...this.spec.style  // Preserved styling
      }];
    }

    // Grouped traces (one per color value)
    const groups = new Map();
    data.forEach(r => {
      const key = r[this.spec.color];
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(r);
    });

    return Array.from(groups, ([name, rows]) => ({
      name,
      x: rows.map(r => r[this.spec.x]),
      y: rows.map(r => r[this.spec.y]),
      type: this.spec.type || 'scatter',
      mode: this.spec.mode || 'markers'
    }));
  }
}
```

#### DataTableAdapter

```js
class DataTableAdapter {
  constructor(tableId, storeId, columns) {
    this.tableId = tableId;
    this.columns = columns;   // ["name", "mpg", "hp", ...]

    const store = window.__quartoReactive.get(storeId);
    store.subscribe((filteredData) => this._update(filteredData));
  }

  _update(data) {
    // HTMLWidgets stores the DT instance; find it
    const wrapper = document.getElementById(this.tableId);
    const table = $(wrapper).find('table').DataTable();

    table.clear();
    data.forEach(row => {
      table.row.add(this.columns.map(col => row[col]));
    });
    table.draw();
  }
}
```

#### LeafletAdapter

```js
class LeafletAdapter {
  constructor(mapId, storeId, layerSpec) {
    this.spec = layerSpec;

    // HTMLWidgets stores leaflet maps on the element
    const mapEl = document.getElementById(mapId);
    this.map = HTMLWidgets.find('#' + mapId).getMap();
    this.layerGroup = L.layerGroup().addTo(this.map);

    const store = window.__quartoReactive.get(storeId);
    store.subscribe((filteredData) => this._update(filteredData));
  }

  _update(data) {
    this.layerGroup.clearLayers();

    data.forEach(row => {
      const lat = row[this.spec.lat];
      const lng = row[this.spec.lng];
      if (lat == null || lng == null) return;

      let layer;
      if (this.spec.type === 'circles') {
        layer = L.circleMarker([lat, lng], {
          radius: this.spec.radius ? row[this.spec.radius] : 6,
          color: this.spec.color ? row[this.spec.color] : '#3388ff'
        });
      } else {
        layer = L.marker([lat, lng]);
      }

      if (this.spec.popup) {
        layer.bindPopup(String(row[this.spec.popup]));
      }

      layer.addTo(this.layerGroup);
    });
  }
}
```

---

## 5. Event Flow (step by step)

```
1. RENDER TIME (R/Quarto)

   a) interactive_df(mtcars) |> filter_on("cyl", ...) |> filter_on("gear", ...)
      └─ R-side only: builds a data.frame with qr_filters attached
      └─ No HTML emitted yet (lazy)

   b) render_inputs(interactive_df)       [first use → triggers boot]
      └─ Emits: <script id="qr-xxx-data" type="application/json">{...}</script>
      └─ Emits: <script>boot: new ReactiveDataStore(data, meta)</script>
      └─ Emits: <div> with radio buttons for cyl [4, 6, 8]
      └─ Emits: <script>boot: attach onChange → store.setFilter("cyl", ...)</script>
      └─ Emits: <div> with dropdown for gear [3, 4, 5]
      └─ Emits: <script>boot: attach onChange → store.setFilter("gear", ...)</script>

   c) reactive(plot_ly(interactive_df, x = ~mpg, y = ~hp))
      └─ Detects: widget is plotly, data is quarto_reactive_df, id = "qr-xxx"
      └─ Extracts column spec from widget$x$attrs: {x: "mpg", y: "hp"}
      └─ Emits: plotly widget HTML (initial full-data render)
      └─ Emits: <script id="...-colspec">{...}</script>
      └─ Emits: <script>boot: new PlotlyAdapter(divId, "qr-xxx", spec)</script>

   d) reactive(datatable(interactive_df))
      └─ Detects: widget is datatables, data is quarto_reactive_df
      └─ Emits: DT widget HTML (initial full-data render)
      └─ Emits: <script>boot: new DataTableAdapter(tableId, "qr-xxx", cols)</script>

2. BROWSER (user interaction)
   User clicks radio button "6"
     → radio onChange fires
       → store.setFilter("cyl", ["6"])
         → store._invalidate()
           → store filters: 32 rows → 7 rows where cyl === "6"
             → PlotlyAdapter._update(7 rows)
               → Plotly.react(div, newTraces, layout)
             → DataTableAdapter._update(7 rows)
               → table.clear().rows.add(7 rows).draw()

3. User clicks "All" on cyl radio (show_all = TRUE)
     → store.clearFilter("cyl")
       → All 32 rows again (gear filter still active if set)
         → Both adapters update

4. Multiple filters combine with AND logic
   cyl = 6, gear = 4 → only rows where cyl === 6 AND gear === 4
```

---

## 6. Full QMD Example

```qmd
---
title: "Motor Trend Cars — Interactive Explorer"
format: html
---

```{r setup}
#| include: false
library(quartoReactive)
library(plotly)
library(DT)
```

```{r data}
#| include: false
interactive_df <- interactive_df(mtcars) |>
  filter_on("cyl",  input = "radio",    label = "Cylinders", show_all = TRUE) |>
  filter_on("gear", input = "dropdown", label = "Gears") |>
  filter_on("mpg",  input = "slider",   label = "MPG Range")
```

## Filters

```{r}
render_inputs(interactive_df)
```

Or, for a custom layout:

::: {.columns}
::: {.column width="33%"}
```{r}
render_input(interactive_df, "cyl")
```
:::
::: {.column width="33%"}
```{r}
render_input(interactive_df, "gear")
```
:::
::: {.column width="33%"}
```{r}
render_input(interactive_df, "mpg")
```
:::
:::

## Scatter Plot

```{r}
reactive(plot_ly(interactive_df, x = ~mpg, y = ~hp, color = ~factor(cyl),
                 type = "scatter", mode = "markers"))
```

## Data Table

```{r}
reactive(datatable(interactive_df[, c("mpg", "cyl", "hp", "wt", "gear")]))
```
```

---

## 7. Critical Design Decisions

### 7.1 Column Spec Auto-Extraction

For plotly, the R object stores the original formulas:

```r
p <- plot_ly(mtcars, x = ~mpg, y = ~hp, color = ~factor(cyl))
p$x$attrs
# $`abc123`
# $x = ~mpg
# $y = ~hp
# $color = ~factor(cyl)
```

The adapter can parse these:

```r
.extract_plotly_mapping <- function(widget) {
  attrs <- widget$x$attrs
  if (is.null(attrs)) return(NULL)
  # Take the first (primary) trace definition
  a <- attrs[[1]]
  mapping <- list()
  for (prop in c("x", "y", "z", "color", "size", "text", "symbol")) {
    if (!is.null(a[[prop]]) && inherits(a[[prop]], "formula")) {
      # Extract variable name from formula: ~mpg → "mpg"
      # Handle factor(): ~factor(cyl) → "cyl"
      mapping[[prop]] <- deparse(a[[prop]][[2]])
      # Strip function wrappers like factor()
      mapping[[prop]] <- gsub("^.*\\((.+)\\)$", "\\1", mapping[[prop]])
    }
  }
  mapping$type <- a$type %||% "scatter"
  mapping$mode <- a$mode %||% "markers"
  mapping
}
```

Fallback: if extraction fails, require `mapping` argument.

### 7.2 Widget Instance Discovery

The JS adapters need to find the live widget instances in the DOM.
htmlwidgets stores instances accessibly:

```js
// Plotly: the div IS the plotly instance
const plotlyDiv = document.getElementById(divId);
// After render: plotlyDiv.data, plotlyDiv.layout exist

// DT: HTMLWidgets.find() or jQuery
const dt = $("#" + tableId + " table").DataTable();

// Leaflet: HTMLWidgets stores it
const map = HTMLWidgets.find("#" + mapId).getMap();
```

Timing matters: adapters must wait for widgets to finish
rendering before capturing initial state. Use:
- `HTMLWidgets.addPostRenderHandler()` (reliable, framework-level)
- Plotly: `div.on('plotly_afterplot', ...)`
- Fallback: `setTimeout` / `MutationObserver`

Recommended universal approach:

```js
function whenWidgetReady(elementId, callback) {
  // HTMLWidgets fires this after all widgets render
  if (window.HTMLWidgets) {
    HTMLWidgets.addPostRenderHandler(() => {
      callback(document.getElementById(elementId));
    });
  } else {
    // Fallback for non-htmlwidget elements
    document.addEventListener('DOMContentLoaded', () => {
      callback(document.getElementById(elementId));
    });
  }
}
```

### 7.3 Multiple DataStores

A document can have multiple independent interactive datasets:

```r
cars_df <- interactive_df(mtcars) |>
  filter_on("cyl", input = "radio")

iris_df <- interactive_df(iris) |>
  filter_on("Species", input = "radio")

# Each render/reactive call auto-detects which store it belongs to
render_inputs(cars_df)    # filters cars only
render_inputs(iris_df)    # filters iris only

reactive(plot_ly(cars_df, x = ~mpg, y = ~hp))   # subscribes to cars store
reactive(datatable(iris_df))                      # subscribes to iris store
```

Each adapter subscribes to one specific DataStore (via the `qr_id`
attribute on the data.frame). No cross-contamination, no global
state leakage.

### 7.4 Cascading Inputs (future)

In the initial version, all inputs filter independently.
Future enhancement: cascading dropdowns where the options in
input B depend on the current selection in input A.

This is already solved in quartoWidgets. The pattern:
- Input A filters the DataStore
- Input B reads `dataStore.getFilteredColumnValues("col_b")`
  to repopulate its options

### 7.5 What About ggplot?

ggplot2 renders static SVG/PNG at render time.
There is **no JS-side data** to update.

Options for ggplot users:
1. Use `plotly::ggplotly()` to convert ggplot → plotly, then
   wrap with `reactive()` — this works seamlessly
2. Accept that ggplot visuals remain static (clearly documented)

```r
# This works:
reactive(ggplotly(ggplot(interactive_df, aes(mpg, hp, color = factor(cyl))) + geom_point()))

# This does NOT work (ggplot is server-rendered):
reactive(ggplot(interactive_df, aes(mpg, hp)) + geom_point())  # → error
```

---

## 8. Comparison with Existing Solutions

| Feature             | quartoReactive       | crosstalk         | Shiny/OJS       |
| ------------------- | -------------------- | ----------------- | --------------- |
| Static HTML         | Yes                  | Yes               | No (server)     |
| Data filtering      | Full (any column)    | Key-based only    | Full            |
| Range filters       | Yes (slider)         | Limited           | Yes             |
| Works with plotly   | Yes (adapter)        | Yes (built-in)    | Yes             |
| Works with DT       | Yes (adapter)        | Yes (built-in)    | Yes             |
| Works with leaflet  | Yes (adapter)        | Yes (built-in)    | Yes             |
| Custom inputs       | Yes                  | Limited           | Yes             |
| Multiple datasets   | Yes                  | Yes               | Yes             |
| No server needed    | Yes                  | Yes               | No              |
| R package           | Yes                  | Yes               | Yes             |
| Adapter needed      | Yes (thin)           | Widget must opt-in| N/A             |

Key advantages over crosstalk:
- **Richer inputs** — radio, searchable dropdown, checkbox, slider vs
  crosstalk's limited `filter_select()`
- **Pipe-friendly declaration** — `filter_on()` chain on the data object
- **One universal `reactive()`** instead of per-widget opt-in
- **Separated declaration and placement** — declare filters on data,
  place them anywhere in the QMD layout

---

## 9. Implementation Roadmap

### Phase 1: Core (MVP)
- [ ] `interactive_df()` — data.frame subclass + JSON serialisation
- [ ] `filter_on()` — pipe-friendly filter declaration (radio only)
- [ ] `render_inputs()` / `render_input()` — HTML emission
- [ ] `reactive()` — universal wrapper with DT adapter (simplest)
- [ ] ReactiveDataStore JS class
- [ ] DataTableAdapter JS class
- [ ] Lazy dependency injection (boot scripts on first render)
- [ ] Basic CSS for radio inputs
- [ ] Working QMD example with mtcars

### Phase 2: Plotly Adapter
- [ ] PlotlyAdapter JS class
- [ ] Column spec auto-extraction from `widget$x$attrs`
- [ ] `.find_reactive_store()` for plotly widget internals
- [ ] Handle single-trace and multi-trace (grouped by color) charts
- [ ] Handle scatter, bar, line chart types
- [ ] Preserve layout (axis labels, title, margins) across updates
- [ ] Explicit `mapping` fallback

### Phase 3: More Input Types
- [ ] `filter_on(input = "dropdown")` — TomSelect integration
- [ ] `filter_on(input = "checkbox")` — multi-value filter
- [ ] `filter_on(input = "slider")` — range filter for numeric columns
- [ ] `render_inputs(layout = "inline" | "stacked")` layout options

### Phase 4: More Adapters
- [ ] LeafletAdapter JS class + `.adapt_leaflet()`
- [ ] EchartsAdapter JS class + `.adapt_echarts()`
- [ ] `ggplotly()` pass-through support in `.find_reactive_store()`

### Phase 5: Polish
- [ ] Cascading input support (option B depends on filter A)
- [ ] Animation/transition options for adapters
- [ ] Filter state display widget ("Showing X of Y rows")
- [ ] Reset all filters button / `render_reset()`
- [ ] `reactive()` error messages for unsupported widget types
- [ ] Documentation + pkgdown site

---

## 10. Key Risks & Mitigations

### Risk: Plotly internal structure changes between versions
**Mitigation:** Pin to plotly.js CDN version in dependencies.
Test against plotly R package versions. The `Plotly.react()` API
is stable and documented.

### Risk: Large datasets make HTML files huge
**Mitigation:** The `columns` parameter in `interactive_df()` lets
users restrict serialised columns. Could also add optional
compression (e.g., columnar encoding instead of row-based JSON).

### Risk: Widget instance not found (timing)
**Mitigation:** Use `HTMLWidgets.addPostRenderHandler()` as the
primary mechanism. Add retry logic with MutationObserver as fallback.

### Risk: Complex plotly charts (facets, subplots, animations)
**Mitigation:** Phase 2 targets the common cases (scatter, bar, line).
Document unsupported configurations. The `mapping` argument provides
an escape hatch for users who need manual control.

---

## 11. Relationship with quartoWidgets

These are **independent packages**. No dependency in either direction.

```
quartoReactive                    quartoWidgets
├── interactive_df()              ├── widget_data()       (sunburst-specific)
├── filter_on()                  ├── radio_selector()    (dimension filter)
├── render_inputs/render_input   ├── widget_selectors()  (cascading filters)
├── reactive()  ───┬─ plotly     ├── sunburst_chart()    (custom D3 visual)
│               ├─ DT         ├── widget_table()      (custom DT)
│               ├─ leaflet    ├── widget_plot()       (custom Plotly)
│               └─ echarts    ├── polygon_selector()  (custom map)
└── ...                          └── ...                  (domain-specific)
```

quartoReactive is **general-purpose** (any data, any JS widget).
quartoWidgets is **domain-specific** (GGD sunburst dashboard components).

In the future, quartoWidgets COULD optionally consume
quartoReactive's DataStore instead of its own EventBus/DashboardData.
But that's a later concern — no coupling now.

# render.R -- Emit filter controls into the document

#' Render all declared filter inputs
#'
#' Emits HTML for all filters declared via \code{\link{filter_on}}.
#' On first use, also injects the data store boot scripts.
#'
#' @param data A \code{quarto_reactive_df} object with filters declared.
#' @param layout Layout style: \code{"inline"} (side by side) or
#'   \code{"stacked"} (one per row).
#'
#' @return An \code{htmltools::tagList} for printing in a QMD chunk.
#'
#' @export
render_inputs <- function(data, layout = "inline") {
  .check_reactive_df(data)
  filters <- attr(data, "qr_filters")
  if (length(filters) == 0L) {
    warning("No filters declared. Use filter_on() first.", call. = FALSE)
    return(htmltools::tagList())
  }

  parts <- list()

  # Inject data store boot scripts on first render
  parts[[1L]] <- .ensure_boot(data)

  # Build each input control
  for (f in filters) {
    parts[[length(parts) + 1L]] <- .build_input(data, f)
  }

  wrapper_class <- if (layout == "inline") "qr-inputs-inline" else "qr-inputs-stacked"
  htmltools::div(class = wrapper_class, do.call(htmltools::tagList, parts))
}

#' Render a single filter input
#'
#' Emits HTML for one specific filter, identified by variable name.
#' Use for custom layouts where you place each filter individually.
#'
#' @param data A \code{quarto_reactive_df} object.
#' @param variable The variable name of the filter to render.
#'
#' @return An \code{htmltools::tagList} for printing in a QMD chunk.
#'
#' @export
render_input <- function(data, variable) {
  .check_reactive_df(data)
  filters <- attr(data, "qr_filters")
  idx <- which(vapply(filters, `[[`, "", "variable") == variable)
  if (length(idx) == 0L)
    stop("No filter declared for variable '", variable,
         "'. Use filter_on() first.", call. = FALSE)

  htmltools::tagList(
    .ensure_boot(data),
    .build_input(data, filters[[idx[1L]]])
  )
}

# -- Internal: ensure data store boot scripts are injected once -----------

.ensure_boot <- function(data) {
  id <- attr(data, "qr_id")

  # Serialise data to JSON
  serialise_cols <- attr(data, "qr_columns") %||% names(data)
  data_subset <- as.data.frame(data)[, serialise_cols, drop = FALSE]
  data_json <- jsonlite::toJSON(data_subset, dataframe = "rows",
                                 auto_unbox = TRUE, null = "null")

  # Column metadata
  meta <- attr(data, "qr_meta")
  meta_json <- jsonlite::toJSON(meta, auto_unbox = TRUE, null = "null")

  # Boot script
  boot_js <- .js_on_ready(paste0(
    '  var dataEl = document.getElementById("', id, '-data");\n',
    '  if (!dataEl) return;\n',
    '  var data = JSON.parse(dataEl.textContent);\n',
    '  var meta = JSON.parse(document.getElementById("', id, '-meta").textContent);\n',
    '  window.__quartoReactive = window.__quartoReactive || { stores: {} };\n',
    '  window.__quartoReactive.stores["', id, '"] = new ReactiveDataStore(data, meta);\n'
  ))

  # Use htmltools::singleton so these are only emitted once per document
  # even if render_input() is called multiple times
  htmltools::tagList(
    .qr_dependencies(),
    htmltools::singleton(htmltools::tags$script(
      id = paste0(id, "-data"),
      type = "application/json",
      htmltools::HTML(data_json)
    )),
    htmltools::singleton(htmltools::tags$script(
      id = paste0(id, "-meta"),
      type = "application/json",
      htmltools::HTML(meta_json)
    )),
    htmltools::singleton(htmltools::tags$script(htmltools::HTML(boot_js)))
  )
}

# -- Internal: build HTML for a single input control ----------------------

.build_input <- function(data, filter_def) {
  id       <- attr(data, "qr_id")
  variable <- filter_def$variable
  input    <- filter_def$input
  label    <- filter_def$label
  values   <- filter_def$values
  default  <- filter_def$default
  opts     <- filter_def$options

  div_id <- paste0(id, "-input-", gsub("[^a-zA-Z0-9]", "-", variable))

  switch(input,
    radio    = .build_radio(id, div_id, variable, label, values, default, opts),
    dropdown = .build_dropdown(id, div_id, variable, label, values, default, opts),
    checkbox = .build_checkbox(id, div_id, variable, label, values, default, opts),
    slider   = .build_slider(id, div_id, variable, label, values, default, opts),
    stop("Unknown input type: ", input, call. = FALSE)
  )
}

# -- Radio input builder --------------------------------------------------

.build_radio <- function(store_id, div_id, variable, label, values, default, opts) {
  show_all <- isTRUE(opts$show_all)
  if (is.null(default) && length(values) > 0L) default <- values[1L]

  # Build radio buttons
  all_values <- if (show_all) c("__all__", values) else values
  all_labels <- if (show_all) c("All", values) else values

  radios <- mapply(function(val, lab) {
    input_id <- paste0(div_id, "-", gsub("[^a-zA-Z0-9]", "-", val))
    is_checked <- if (show_all && is.null(default)) val == "__all__"
                  else if (show_all && !is.null(default)) val == default
                  else val == default
    htmltools::tags$label(
      class = "qr-radio-option",
      htmltools::tags$input(
        type = "radio", name = div_id, value = val,
        checked = if (is_checked) NA else NULL
      ),
      htmltools::tags$span(lab)
    )
  }, all_values, all_labels, SIMPLIFY = FALSE)

  # Boot script to connect radio to DataStore
  boot <- .js_on_ready(paste0(
    '  var store = window.__quartoReactive.stores["', store_id, '"];\n',
    '  if (!store) return;\n',
    '  var container = document.getElementById("', div_id, '");\n',
    '  if (!container) return;\n',
    '  container.addEventListener("change", function(e) {\n',
    '    var val = e.target.value;\n',
    '    if (val === "__all__") store.clearFilter("', variable, '");\n',
    '    else store.setFilter("', variable, '", [val]);\n',
    '  });\n',
    '  // Apply default\n',
    '  var checked = container.querySelector("input:checked");\n',
    '  if (checked && checked.value !== "__all__") {\n',
    '    store.setFilter("', variable, '", [checked.value]);\n',
    '  }\n'
  ))

  htmltools::tagList(
    htmltools::div(
      id = div_id, class = "qr-input qr-radio",
      htmltools::tags$div(class = "qr-input-label", label),
      htmltools::div(class = "qr-radio-group", do.call(htmltools::tagList, radios))
    ),
    htmltools::tags$script(htmltools::HTML(boot))
  )
}

# -- Dropdown input builder (Phase 3 -- stub) -----------------------------

.build_dropdown <- function(store_id, div_id, variable, label, values, default, opts) {
  # Phase 3: full TomSelect implementation
  # For now, emit a basic <select>
  if (is.null(default) && length(values) > 0L) default <- values[1L]

  options_html <- lapply(values, function(v) {
    htmltools::tags$option(value = v, selected = if (v == default) NA else NULL, v)
  })

  boot <- .js_on_ready(paste0(
    '  var store = window.__quartoReactive.stores["', store_id, '"];\n',
    '  if (!store) return;\n',
    '  var el = document.querySelector("#', div_id, ' select");\n',
    '  if (!el) return;\n',
    '  el.addEventListener("change", function() {\n',
    '    store.setFilter("', variable, '", [el.value]);\n',
    '  });\n',
    '  if (el.value) store.setFilter("', variable, '", [el.value]);\n'
  ))

  htmltools::tagList(
    htmltools::div(
      id = div_id, class = "qr-input qr-dropdown",
      htmltools::tags$div(class = "qr-input-label", label),
      htmltools::tags$select(do.call(htmltools::tagList, options_html))
    ),
    htmltools::tags$script(htmltools::HTML(boot))
  )
}

# -- Checkbox input builder (Phase 3 -- stub) -----------------------------

.build_checkbox <- function(store_id, div_id, variable, label, values, default, opts) {
  stop("Checkbox input is coming in Phase 3.", call. = FALSE)
}

# -- Slider input builder (Phase 3 -- stub) -------------------------------

.build_slider <- function(store_id, div_id, variable, label, values, default, opts) {
  stop("Slider input is coming in Phase 3.", call. = FALSE)
}

# adapters/dt.R — DataTables adapter for reactive()

#' @keywords internal
.adapt_dt <- function(widget, mapping = NULL, ...) {
  # Find the reactive store id
  store_id <- .find_reactive_store(widget)

  if (is.null(store_id)) {
    stop(
      "Could not detect reactive data in the datatable widget. ",
      "Make sure you pass an interactive_df as data: datatable(interactive_df).",
      call. = FALSE
    )
  }

  # Ensure the widget has a known element id
  widget_id <- widget$elementId
  if (is.null(widget_id)) {
    widget_id <- paste0("qr-dt-", store_id)
    widget$elementId <- widget_id
  }

  # Extract column names from the DT widget
  # DT stores column names in widget$x$colnames (character vector)
  col_names <- widget$x$colnames
  if (is.null(col_names)) {
    col_names <- names(widget$x$data)
  }

  col_spec_json <- jsonlite::toJSON(col_names, auto_unbox = TRUE)

  # Boot script: create DataTableAdapter
  boot <- .js_on_ready(paste0(
    '  if (typeof DataTableAdapter !== "undefined") {\n',
    '    new DataTableAdapter("', widget_id, '", "', store_id, '", ', col_spec_json, ');\n',
    '  }\n'
  ))

  htmltools::tagList(
    .ensure_boot_if_needed(store_id),
    widget,
    htmltools::tags$script(htmltools::HTML(boot))
  )
}

# Emit boot scripts only if they haven't been emitted yet.
# This is needed when reactive() is called but render_inputs() was already
# called (which would have emitted the boot scripts).
# Uses a singleton pattern.
.ensure_boot_if_needed <- function(store_id) {
  htmltools::singleton(
    htmltools::tags$script(
      id = paste0(store_id, "-adapter-check"),
      htmltools::HTML(paste0(
        '// Adapter registration marker for store: ', store_id, '\n'
      ))
    )
  )
}

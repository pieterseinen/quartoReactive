# adapter_plotly.R -- Plotly adapter for reactive()

#' @keywords internal
.adapt_plotly <- function(widget, store_id, mapping = NULL, ...) {
  # Auto-extract column mapping from plotly widget attrs if not supplied
  spec <- mapping
  if (is.null(spec)) {
    spec <- .extract_plotly_mapping(widget)
  }
  if (is.null(spec) || is.null(spec$x) || is.null(spec$y)) {
    stop(
      "Could not auto-detect plotly column mapping. ",
      "Pass an explicit mapping: reactive(plot_ly(...), mapping = list(x = 'col1', y = 'col2')).",
      call. = FALSE
    )
  }

  # Ensure the plotly div has a known element id
  widget_id <- widget$elementId
  if (is.null(widget_id)) {
    widget_id <- paste0("qr-plotly-", store_id)
    widget$elementId <- widget_id
  }

  spec_json <- jsonlite::toJSON(spec, auto_unbox = TRUE, null = "null")

  # Boot script: create PlotlyAdapter
  boot <- .js_on_ready(paste0(
    '  if (typeof PlotlyAdapter !== "undefined") {\n',
    '    new PlotlyAdapter("', widget_id, '", "', store_id, '", ', spec_json, ');\n',
    '  }\n'
  ))

  htmltools::tagList(
    .ensure_boot_if_needed(store_id),
    widget,
    htmltools::tags$script(htmltools::HTML(boot))
  )
}

#' Extract column mapping from a plotly object
#'
#' Parses widget$x$attrs to build a column spec automatically.
#' Handles formulas (~ mpg), wrapped functions (~ factor(cyl)),
#' and literal column names.
#'
#' @param widget A plotly object.
#' @return A named list of column mappings, or NULL.
#' @keywords internal
.extract_plotly_mapping <- function(widget) {
  attrs <- widget$x$attrs
  if (is.null(attrs)) return(NULL)

  # Take the first (primary) trace definition
  a <- attrs[[1]]
  mapping <- list()

  for (prop in c("x", "y", "z", "color", "size", "text", "symbol")) {
    val <- a[[prop]]
    if (is.null(val)) next

    if (inherits(val, "formula")) {
      # ~ mpg  or  ~ factor(cyl)
      col_name <- deparse(val[[2]])
      # Strip function wrappers: factor(cyl) -> cyl
      col_name <- gsub("^.*\\((.+)\\)$", "\\1", col_name)
      mapping[[prop]] <- col_name
    } else if (is.character(val) && length(val) == 1L) {
      # Literal column name string
      mapping[[prop]] <- val
    }
  }

  # Chart type and mode
  mapping$type <- a$type %||% "scatter"
  mapping$mode <- a$mode %||% "markers"

  # Only return if we got at least x and y

  if (is.null(mapping$x) || is.null(mapping$y)) return(NULL)
  mapping
}

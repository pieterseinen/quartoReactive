# reactive.R — Universal reactive() wrapper with auto-detection

#' Connect an htmlwidget to a reactive data store
#'
#' Wraps any supported htmlwidget (plotly, DT, leaflet, etc.) and connects
#' it to the reactive data store. Auto-detects the widget type and extracts
#' the store id from the data.frame used to build the widget.
#'
#' @param widget_expr A supported htmlwidget object (plotly, DT::datatable, leaflet).
#' @param mapping Optional explicit column spec for the adapter. Required for
#'   leaflet, optional override for plotly.
#' @param ... Additional adapter-specific options.
#'
#' @return An \code{htmltools::tagList} containing the widget and boot scripts.
#'
#' @examples
#' \dontrun{
#' interactive_df <- interactive_df(mtcars) |>
#'   filter_on("cyl", input = "radio")
#'
#' reactive(datatable(interactive_df))
#' reactive(plot_ly(interactive_df, x = ~mpg, y = ~hp))
#' }
#'
#' @export
reactive <- function(widget_expr, mapping = NULL, ...) {
  # Capture the unevaluated expression so we can scan it for
  # quarto_reactive_df objects (widget constructors like datatable()
  # strip our custom class/attributes from the data).
  expr <- substitute(widget_expr)
  env  <- parent.frame()

  # Evaluate the expression to get the widget object
  widget <- eval(expr, env)

  # 1. Try to find the reactive store from widget internals
  store_id <- .find_reactive_store(widget)

  # 2. If that fails, walk the unevaluated expression tree to find
  #    any quarto_reactive_df arguments (NSE approach)
  if (is.null(store_id)) {
    store_id <- .find_store_from_expr(expr, env)
  }

  if (is.null(store_id)) {
    stop(
      "Could not detect reactive data. ",
      "Make sure you pass an interactive_df as data to the widget, e.g.: ",
      "reactive(datatable(interactive_df)).",
      call. = FALSE
    )
  }

  # Detect widget type and dispatch to adapter
  if (inherits(widget, "datatables")) {
    return(.adapt_dt(widget, store_id, mapping, ...))
  } else if (inherits(widget, "plotly")) {
    return(.adapt_plotly(widget, store_id, mapping, ...))
  } else if (inherits(widget, "leaflet")) {
    return(.adapt_leaflet(widget, store_id, mapping, ...))
  } else {
    stop(
      "Unsupported widget type: ", paste(class(widget), collapse = ", "), ". ",
      "reactive() currently supports: plotly, DT (datatables), leaflet.",
      call. = FALSE
    )
  }
}

#' Find the reactive store id from a widget's internal data
#'
#' Scans widget internals for a quarto_reactive_df. This works for widgets
#' that preserve the original data.frame (e.g. plotly's visdat). For widgets
#' that strip custom classes (e.g. DT), this returns NULL and the caller
#' falls back to the NSE-based .find_store_from_expr().
#'
#' @param widget An htmlwidget object.
#' @return The qr_id string, or NULL if not found.
#' @noRd
.find_reactive_store <- function(widget) {
  # Plotly: data stored in widget$x$visdat (list of environments/functions)
  if (inherits(widget, "plotly")) {
    vis <- widget$x$visdat
    if (is.list(vis)) {
      for (v in vis) {
        df <- if (is.function(v)) tryCatch(v(), error = function(e) NULL) else v
        if (inherits(df, "quarto_reactive_df")) {
          return(attr(df, "qr_id"))
        }
      }
    }
  }

  # DT and Leaflet strip our class — return NULL so the NSE fallback is used.
  NULL
}

#' Find the reactive store id by walking the unevaluated expression tree
#'
#' When widget constructors like datatable() strip our quarto_reactive_df
#' class, we walk the original call expression to find any symbols or
#' sub-expressions that evaluate to a quarto_reactive_df.
#'
#' @param expr An unevaluated R expression (from substitute()).
#' @param env The environment in which to evaluate symbols.
#' @return The qr_id string, or NULL if not found.
#' @noRd
.find_store_from_expr <- function(expr, env) {
  if (is.symbol(expr)) {
    # A bare variable name — evaluate it and check
    obj <- tryCatch(eval(expr, env), error = function(e) NULL)
    if (inherits(obj, "quarto_reactive_df")) {
      return(attr(obj, "qr_id"))
    }
  } else if (is.call(expr)) {
    # A function call — check each argument recursively
    for (i in seq_along(expr)) {
      result <- .find_store_from_expr(expr[[i]], env)
      if (!is.null(result)) return(result)
    }
  }
  NULL
}

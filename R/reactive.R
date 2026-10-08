# reactive.R — Universal reactive() wrapper with auto-detection

#' Connect an htmlwidget to a reactive data store
#'
#' Wraps any supported htmlwidget (plotly, DT, leaflet, etc.) and connects
#' it to the reactive data store. Auto-detects the widget type and extracts
#' the store id from the data.frame used to build the widget.
#'
#' @param widget A supported htmlwidget object (plotly, DT::datatable, leaflet).
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
reactive <- function(widget, mapping = NULL, ...) {
  # Detect widget type and dispatch to adapter
  if (inherits(widget, "datatables")) {
    return(.adapt_dt(widget, mapping, ...))
  } else if (inherits(widget, "plotly")) {
    return(.adapt_plotly(widget, mapping, ...))
  } else if (inherits(widget, "leaflet")) {
    return(.adapt_leaflet(widget, mapping, ...))
  } else {
    stop(
      "Unsupported widget type: ", paste(class(widget), collapse = ", "), ". ",
      "reactive() currently supports: plotly, DT (datatables), leaflet.",
      call. = FALSE
    )
  }
}

#' Find the reactive store id from a widget's data
#'
#' Scans widget internals for a quarto_reactive_df and returns its qr_id.
#'
#' @param widget An htmlwidget object.
#' @return The qr_id string, or NULL if not found.
#' @keywords internal
.find_reactive_store <- function(widget) {
  # DT: data is stored in widget$x$data (a list of column vectors)
  #     but also in widget$x$options$data or the original data attribute
  if (inherits(widget, "datatables")) {
    # DT stores the original data in a private env; check the attr
    data_obj <- attr(widget, "qr_source_data")
    if (!is.null(data_obj) && inherits(data_obj, "quarto_reactive_df")) {
      return(attr(data_obj, "qr_id"))
    }
    # Fallback: scan widget$x for data attribute
    if (!is.null(widget$x$data)) {
      # DT converts to list of columns; check if we stashed the id
      return(attr(widget$x, "qr_id"))
    }
  }

  # Plotly: data stored in widget$x$visdat (list of environments)
  if (inherits(widget, "plotly")) {
    vis <- widget$x$visdat
    if (is.list(vis)) {
      for (v in vis) {
        if (is.function(v)) {
          df <- tryCatch(v(), error = function(e) NULL)
        } else {
          df <- v
        }
        if (inherits(df, "quarto_reactive_df")) {
          return(attr(df, "qr_id"))
        }
      }
    }
    # Fallback: check attrs
    data_obj <- widget$x$source
    if (inherits(data_obj, "quarto_reactive_df")) {
      return(attr(data_obj, "qr_id"))
    }
  }

  # Leaflet: data may be stored in widget$x$calls
  if (inherits(widget, "leaflet")) {
    data_obj <- attr(widget, "qr_source_data")
    if (!is.null(data_obj) && inherits(data_obj, "quarto_reactive_df")) {
      return(attr(data_obj, "qr_id"))
    }
  }

  NULL
}

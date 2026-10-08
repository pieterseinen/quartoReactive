# adapters/plotly.R — Plotly adapter for reactive() (Phase 2)

#' @keywords internal
.adapt_plotly <- function(widget, store_id, mapping = NULL, ...) {
  stop(
    "Plotly adapter is coming in Phase 2. ",
    "For now, use reactive() with DT::datatable().",
    call. = FALSE
  )
}

#' Extract column mapping from a plotly object
#'
#' Parses widget$x$attrs to build a column spec automatically.
#'
#' @param widget A plotly object.
#' @return A named list of column mappings, or NULL.
#' @keywords internal
.extract_plotly_mapping <- function(widget) {
  attrs <- widget$x$attrs
  if (is.null(attrs)) return(NULL)
  a <- attrs[[1]]
  mapping <- list()
  for (prop in c("x", "y", "z", "color", "size", "text", "symbol")) {
    if (!is.null(a[[prop]]) && inherits(a[[prop]], "formula")) {
      mapping[[prop]] <- deparse(a[[prop]][[2]])
      # Strip function wrappers like factor()
      mapping[[prop]] <- gsub("^.*\\((.+)\\)$", "\\1", mapping[[prop]])
    }
  }
  mapping$type <- a$type %||% "scatter"
  mapping$mode <- a$mode %||% "markers"
  mapping
}

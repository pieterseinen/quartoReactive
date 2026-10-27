# Spike B: tag already-built widgets with source row keys so rowmask.js can hide
# rows/points instead of rebuilding the widget from raw data.
# Keys are row names, so they survive row subsets and match spike_filters() keys.

mask_plotly <- function(p, group) {
  p$x$visdat <- lapply(p$x$visdat, function(f) {
    force(f)
    function() {
      d <- f()
      d$.qr_row <- rownames(d)
      d
    }
  })
  # plotly_build() splits `key` per trace along with x/y/colour, so every
  # point keeps its row key whatever grouping R applied.
  p$x$attrs <- lapply(p$x$attrs, function(a) {
    a$key <- a$key %||% ~.qr_row
    a
  })
  mask_attach(plotly::plotly_build(p), group, "qrMaskPlotly")
}

# ggplotly() builds traces straight from the ggplot, so the key goes in as an aesthetic.
mask_ggplotly <- function(gg, group) {
  gg$data$.qr_row <- rownames(gg$data)
  mask_attach(plotly::ggplotly(gg + ggplot2::aes(key = .qr_row)), group, "qrMaskPlotly")
}

mask_dt <- function(dt, group) {
  # With rownames = TRUE, DT stores them as the first data column: use them as keys.
  keys <- if (identical(names(dt$x$data)[1], " ")) as.character(dt$x$data[[1]])
  mask_attach(dt, group, "qrMaskDT", keys)
}

.mask_counter <- local({ n <- 0; function() { n <<- n + 1; n } })

mask_attach <- function(widget, group, adapter, keys = NULL) {
  # One id per widget: several widgets can share a group.
  id <- widget$elementId %||% paste0("qr-", group, "-", .mask_counter())
  widget$elementId <- id
  htmltools::tagList(
    widget,
    htmltools::tags$script(htmltools::HTML(sprintf(
      'document.addEventListener("DOMContentLoaded", function () { %s("%s", "%s", %s); });',
      adapter, id, group, if (is.null(keys)) "null" else jsonlite::toJSON(keys)
    )))
  )
}

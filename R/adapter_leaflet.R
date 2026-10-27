# adapters/leaflet.R — Leaflet adapter for reactive() (Phase 4)

#' @noRd
.adapt_leaflet <- function(widget, store_id, mapping = NULL, ...) {
  stop(
    "Leaflet adapter is coming in Phase 4. ",
    "For now, use reactive() with DT::datatable().",
    call. = FALSE
  )
}

#' quartoReactive: selections that span a Quarto book
#'
#' Inputs set named selection parameters (for example the municipalities to
#' compare); widgets on any page of the book follow them, without a server.
#' The selection persists while the reader moves between chapters and is kept
#' in the URL, so a comparison can be shared as a link.
#'
#' * Configure: [qr_param()] with [qr_book_setup()] (book) or [qr_config()]
#'   (single document).
#' * Inputs: [qr_select()], [qr_checkbox()], [qr_radio()].
#' * Widgets: pass [qr_data()] to any crosstalk-aware widget (plotly, DT,
#'   leaflet), or use the package's own widgets such as [qr_iconfill()].
#'
#' @keywords internal
"_PACKAGE"

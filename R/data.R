#' Data that follows a selection parameter
#'
#' Wraps `data` in a crosstalk [crosstalk::SharedData] so that widgets with
#' crosstalk support (plotly, DT, leaflet and others) show only the rows whose
#' key is selected. Rows may share a key, e.g. one row per municipality per
#' year.
#'
#' @param data A data frame.
#' @param key Column holding the parameter's keys: a column name or a
#'   one-sided formula such as `~code`.
#' @param param Name of the selection parameter.
#'
#' @return A `SharedData` object; pass it to a widget instead of `data`.
#' @export
#' @examples
#' d <- data.frame(code = c("GM0855", "GM0828"), inwoners = c(230357, 99602))
#' sd <- qr_data(d, "code", "gemeente")
#' if (requireNamespace("plotly", quietly = TRUE)) {
#'   plotly::plot_ly(sd, x = ~code, y = ~inwoners, type = "bar")
#' }
qr_data <- function(data, key, param) {
  .check_param(param)
  if (!is.data.frame(data)) stop("`data` must be a data frame.", call. = FALSE)
  if (is.character(key)) {
    .check_column(data, key, "key")
    key <- stats::as.formula(paste0("~`", key, "`"))
  } else if (!inherits(key, "formula") || length(key) != 2) {
    stop("`key` must be a column name or a one-sided formula.", call. = FALSE)
  }
  crosstalk::SharedData$new(data, key = key, group = param)
}

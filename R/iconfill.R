#' Icons filled to a percentage
#'
#' Draws one icon per row, filled from the bottom up to the row's value, and
#' shows only the rows whose key is selected in `param` (plus its `always`
#' keys).
#'
#' @param data A data frame with one row per key.
#' @param key,value,label Column names: the key the parameter selects on, the
#'   percentage (0-100) and the caption.
#' @param param Name of the selection parameter.
#' @param digits Decimals shown in the caption.
#' @param color Fill colour; selected keys use the parameter's `colors`
#'   instead when it has them (see [qr_param()]).
#' @param width,height Widget size.
#' @param elementId Optional element id.
#'
#' @return An htmlwidget.
#' @export
#' @examples
#' d <- data.frame(code = c("GM0855", "GM0828"), naam = c("Tilburg", "Oss"),
#'                 pct = c(72.1, 73.8))
#' qr_iconfill(d, key = "code", value = "pct", label = "naam", param = "gemeente")
qr_iconfill <- function(data, key, value, label = key, param, digits = 0,
                        color = "#2a7ab0", width = "100%", height = 170,
                        elementId = NULL) {
  .check_param(param)
  for (arg in c("key", "value", "label")) .check_column(data, get(arg), arg)
  values <- data[[value]]
  if (!is.numeric(values)) stop("`value` must name a numeric column.", call. = FALSE)

  x <- list(
    param  = param,
    color  = color,
    # I() keeps one-row data as arrays in the JSON.
    keys   = I(as.character(data[[key]])),
    labels = I(as.character(data[[label]])),
    values = I(values),
    text   = I(ifelse(is.na(values), NA,
                      paste0(formatC(values, format = "f", digits = digits), "%")))
  )
  htmlwidgets::createWidget(
    "qr_iconfill", x, width = width, height = height, package = "quartoReactive",
    elementId = elementId, dependencies = list(qr_dependency())
  )
}

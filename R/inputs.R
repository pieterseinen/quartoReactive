#' Inputs that change a selection parameter
#'
#' Every input bound to the same `param` shows and changes the same selection,
#' also across the chapters of a book. Inputs can be placed in a chunk or in
#' the book sidebar (see [qr_book_setup()]).
#'
#' * `qr_select()`: a list box, multiple choice by default.
#' * `qr_checkbox()`: a checkbox per choice, multiple choice.
#' * `qr_radio()`: a radio button per choice, one choice.
#'
#' @param param Name of the selection parameter, e.g. `"gemeente"`.
#' @param choices Keys to choose from. Names, if any, are shown as labels:
#'   `c(Tilburg = "GM0855", Oss = "GM0828")`.
#' @param label Text above the input; `NULL` for none.
#'
#' @return An HTML tag.
#' @name qr_inputs
#' @examples
#' choices <- c(Tilburg = "GM0855", Oss = "GM0828", Vught = "GM0865")
#' qr_select("gemeente", choices, label = "Municipalities")
#' qr_radio("gemeente", choices)
NULL

#' @rdname qr_inputs
#' @param multiple Allow more than one choice.
#' @param size Number of visible rows; defaults to up to 8.
#' @export
qr_select <- function(param, choices, label = param, multiple = TRUE, size = NULL) {
  choices <- .check_choices(choices)
  size <- size %||% if (multiple) min(length(choices), 8L) else 1L
  options <- unname(Map(function(value, text) htmltools::tags$option(value = value, text),
                        choices, names(choices)))
  .qr_input(param, label, "select",
            htmltools::tags$select(multiple = if (multiple) NA, size = size, options))
}

#' @rdname qr_inputs
#' @export
qr_checkbox <- function(param, choices, label = param) {
  .qr_input(param, label, "checkbox", .qr_options(param, choices, "checkbox"))
}

#' @rdname qr_inputs
#' @export
qr_radio <- function(param, choices, label = param) {
  .qr_input(param, label, "radio", .qr_options(param, choices, "radio"))
}

.qr_input <- function(param, label, type, body) {
  .check_param(param)
  el <- htmltools::div(
    class = paste("qr-input", paste0("qr-input-", type)), `data-qr-param` = param,
    if (!is.null(label)) htmltools::div(class = "qr-input-label", label),
    body
  )
  htmltools::attachDependencies(el, qr_dependency())
}

.qr_options <- function(param, choices, type) {
  choices <- .check_choices(choices)
  # Names must be unique per input: two radio inputs for the same param
  # (sidebar and chapter) would otherwise form one browser radio group.
  name <- .next_id(paste0("qr-", param))
  unname(Map(function(value, text) {
    htmltools::tags$label(class = "qr-option",
                          htmltools::tags$input(type = type, name = name, value = value),
                          text)
  }, choices, names(choices)))
}

.check_choices <- function(choices) {
  if (is.factor(choices)) choices <- stats::setNames(as.character(choices), names(choices))
  if (!is.atomic(choices) || !length(choices) || anyNA(choices)) {
    stop("`choices` must be a non-empty vector without missing values.", call. = FALSE)
  }
  labels <- names(choices) %||% as.character(choices)
  labels[labels == ""] <- as.character(choices)[labels == ""]
  stats::setNames(as.character(choices), labels)
}

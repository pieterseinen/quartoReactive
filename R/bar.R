#' Show the current selection as a bar of chips
#'
#' Lists the selected keys by label, each with its selection colour (if the
#' parameter has `colors`) and a button to remove it. Useful on small screens,
#' where the book sidebar is hidden: pass it as `top` to [qr_book_setup()] to
#' show it at the top of every chapter, or place it in a chunk.
#'
#' @inheritParams qr_inputs
#' @param choices Keys with labels, as for the inputs. Keys without a label
#'   are shown as is.
#' @param label Text before the chips; `NULL` for none.
#' @param empty Text shown when nothing is selected.
#' @param remove Accessible name of the remove buttons, followed by the label.
#' @param sticky Keep the bar at the top of the window while scrolling.
#'
#' @return An HTML tag.
#' @export
#' @examples
#' qr_selection_bar("gemeente", c(Tilburg = "GM0855", Oss = "GM0828"),
#'                  label = "Vergelijking:", empty = "Alle gemeenten",
#'                  remove = "Verwijder")
qr_selection_bar <- function(param, choices, label = "Showing:",
                             empty = "Nothing selected: showing all.",
                             remove = "Remove", sticky = TRUE) {
  .check_param(param)
  choices <- .check_choices(choices)
  labels <- stats::setNames(as.list(names(choices)), choices)
  el <- htmltools::div(
    class = paste(c("qr-selection-bar", if (sticky) "qr-sticky"), collapse = " "),
    `data-qr-bar` = param,
    `data-qr-labels` = as.character(jsonlite::toJSON(labels, auto_unbox = TRUE)),
    `data-qr-remove` = remove,
    role = "status", `aria-live` = "polite",
    if (!is.null(label)) htmltools::span(class = "qr-bar-label", label),
    htmltools::tags$ul(class = "qr-chips"),
    htmltools::span(class = "qr-bar-empty", empty)
  )
  htmltools::attachDependencies(el, qr_dependency())
}

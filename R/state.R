#' Configure a selection parameter
#'
#' A parameter is a named selection that inputs change and widgets follow, for
#' example `gemeente` holding the codes of the selected municipalities.
#' Pass parameters to [qr_book_setup()] (a Quarto book) or [qr_config()] (a
#' single document).
#'
#' @param default Keys selected on a reader's first visit. Empty means nothing
#'   is selected, and widgets then show all rows.
#' @param always Keys that widgets keep showing whatever is selected, such as
#'   a national benchmark. They do not appear in inputs unless listed there.
#' @param colors Optional selection colours. Each selected key takes the next
#'   free colour and keeps it while it stays selected, so adding or removing a
#'   key never repaints the others. Applied to plotly traces that hold a
#'   single key (such as one line per municipality) and to the package's own
#'   widgets. `always` keys keep the colours given in R.
#' @param max Optional maximum number of selected keys. Inputs stop accepting
#'   more, and a longer selection from a link keeps its first `max` keys.
#'   With `colors`, a `max` of at most `length(colors)` keeps colours unique.
#'
#' @return A `qr_param` object.
#' @export
#' @examples
#' qr_param(default = c("GM0855", "GM0796"), always = "NL01",
#'          colors = c("#2a78d6", "#eb6834", "#1baf7a"), max = 3)
qr_param <- function(default = character(), always = character(), colors = NULL,
                     max = NULL) {
  if (!is.null(colors) && (!is.character(colors) || !length(colors) || anyNA(colors))) {
    stop("`colors` must be a character vector of colours.", call. = FALSE)
  }
  if (!is.null(max)) {
    if (!is.numeric(max) || length(max) != 1 || is.na(max) || max < 1 || max %% 1 != 0) {
      stop("`max` must be a whole number of at least 1.", call. = FALSE)
    }
    max <- as.integer(max)
    if (length(default) > max) {
      stop("`default` has more than `max` (", max, ") keys.", call. = FALSE)
    }
  }
  structure(
    list(default = as.character(default), always = as.character(always), colors = colors,
         max = max),
    class = "qr_param"
  )
}

#' @export
print.qr_param <- function(x, ...) {
  show <- function(v) if (length(v)) paste(v, collapse = ", ") else "(none)"
  cat("<qr_param>\n  default:", show(x$default), "\n  always: ", show(x$always),
      "\n  colors: ", show(x$colors), "\n  max:    ", show(x$max), "\n")
  invisible(x)
}

#' Configure selection parameters in a single document
#'
#' Use this in a standalone Quarto or R Markdown document, in a chunk that
#' comes before the inputs and widgets. In a book, use [qr_book_setup()]
#' instead, so that every chapter shares one configuration.
#'
#' @param params Named list of [qr_param()]s; names are the parameter names.
#' @param id Optional storage id. Documents with the same `id` share their
#'   selection while the browser tab is open.
#'
#' @return An HTML tag list to include in the document.
#' @export
#' @examples
#' qr_config(list(gemeente = qr_param(default = "GM0855", always = "NL01")))
qr_config <- function(params, id = NULL) {
  htmltools::tagList(
    qr_dependency(),
    htmltools::tags$script(htmltools::HTML(paste(.config_js(params, id), collapse = "\n")))
  )
}

# The store (JS + CSS) as an htmlDependency, attached by every input and
# custom widget so standalone documents work without further setup.
qr_dependency <- function() {
  htmltools::htmlDependency(
    name = "qr-state",
    version = as.character(utils::packageVersion("quartoReactive")),
    src = "htmlwidgets/lib/qr-state",
    package = "quartoReactive",
    script = "qr-state.js",
    stylesheet = "qr-state.css"
  )
}

# Tom Select (Apache-2.0, bundled in inst/htmlwidgets/lib/tom-select).
tom_select_dependency <- function() {
  htmltools::htmlDependency(
    name = "tom-select",
    version = "2.6.2",
    src = "htmlwidgets/lib/tom-select",
    package = "quartoReactive",
    script = "tom-select.complete.min.js",
    stylesheet = "tom-select.bootstrap5.min.css"
  )
}

# Keys stay arrays in JSON; `max` is a scalar; unset options are left out.
.config_list <- function(p) {
  p <- Filter(Negate(is.null), unclass(p))
  if (!is.null(p$max)) p$max <- jsonlite::unbox(p$max)
  p
}

.config_js <- function(params, id = NULL) {
  if (!is.list(params) || is.null(names(params)) || any(names(params) == "")) {
    stop("`params` must be a named list of qr_param() objects.", call. = FALSE)
  }
  for (p in names(params)) .check_param(p)
  bad <- !vapply(params, inherits, logical(1), "qr_param")
  if (any(bad)) {
    stop("`params` must contain qr_param() objects; not: ",
         paste(names(params)[bad], collapse = ", "), call. = FALSE)
  }
  c(
    if (!is.null(id)) sprintf("qrState.namespace(%s);", .json(id, auto_unbox = TRUE)),
    vapply(names(params), function(p) {
      sprintf("qrState.configure(%s, %s);", .json(p, auto_unbox = TRUE),
              .json(.config_list(params[[p]])))
    }, character(1), USE.NAMES = FALSE)
  )
}

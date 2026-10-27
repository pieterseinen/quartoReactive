#' Set up selection parameters for a Quarto book
#'
#' Writes two include files that give every chapter of the book the same
#' selection store and, optionally, an input in the book's sidebar:
#'
#' * `_qr-header.html`: the store and its configuration, for `include-in-header`;
#' * `_qr-sidebar.html`: the sidebar input, for `include-after-body`.
#'
#' Call it from a pre-render script, so the files are fresh on every render:
#'
#' ```yaml
#' project:
#'   type: book
#'   pre-render: _setup.R
#' format:
#'   html:
#'     include-in-header: _qr-header.html
#'     include-after-body: _qr-sidebar.html
#' ```
#'
#' @inheritParams qr_config
#' @param sidebar Optional input, such as [qr_checkbox()], shown in the book
#'   sidebar on every page.
#' @param id Storage id that keeps this book's selection apart from other
#'   books on the same website. Defaults to the name of the book's folder.
#' @param dir The book's project folder.
#'
#' @return The paths of the written files, invisibly.
#' @export
#' @examples
#' dir <- tempfile()
#' dir.create(dir)
#' qr_book_setup(
#'   params  = list(gemeente = qr_param(default = "GM0855", always = "NL01")),
#'   sidebar = qr_checkbox("gemeente", c(Tilburg = "GM0855", Oss = "GM0828")),
#'   dir     = dir
#' )
#' list.files(dir)
qr_book_setup <- function(params, sidebar = NULL, id = NULL, dir = ".") {
  id <- id %||% basename(normalizePath(dir, winslash = "/"))
  pkg_file <- function(...) system.file("htmlwidgets", "lib", "qr-state", ..., package = "quartoReactive")

  header <- c(
    "<style>", readLines(pkg_file("qr-state.css")), "</style>",
    "<script>", readLines(pkg_file("qr-state.js")), .config_js(params, id), "</script>"
  )

  # Quarto's sidebar is built after the body, so the input is moved into it
  # by script. Without a sidebar (e.g. on narrow screens) it stays at the end
  # of the page.
  body <- if (is.null(sidebar)) character() else c(
    '<div id="qr-sidebar-inputs">', as.character(sidebar), "</div>",
    "<script>",
    "(function () {",
    "  var el = document.getElementById('qr-sidebar-inputs');",
    "  var sidebar = document.querySelector('#quarto-sidebar .sidebar-menu-container') ||",
    "                document.getElementById('quarto-sidebar');",
    "  if (sidebar) sidebar.appendChild(el);",
    "})();",
    "</script>"
  )

  paths <- file.path(dir, c("_qr-header.html", "_qr-sidebar.html"))
  writeLines(header, paths[1], useBytes = TRUE)
  writeLines(body, paths[2], useBytes = TRUE)
  .check_quarto_yml(dir)
  invisible(paths)
}

# Warn when the book does not include the files we just wrote.
.check_quarto_yml <- function(dir) {
  yml <- file.path(dir, "_quarto.yml")
  if (!file.exists(yml)) return(invisible())
  text <- paste(readLines(yml, warn = FALSE), collapse = "\n")
  missing <- c("_qr-header.html", "_qr-sidebar.html")[
    !vapply(c("_qr-header.html", "_qr-sidebar.html"), grepl, logical(1), text, fixed = TRUE)]
  if (length(missing)) {
    warning("_quarto.yml does not include ", paste(missing, collapse = " and "),
            "; see ?qr_book_setup.", call. = FALSE)
  }
  invisible()
}

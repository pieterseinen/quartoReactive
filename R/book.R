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
#' @param sidebar Optional input, such as [qr_select()], shown in the book
#'   sidebar on every page.
#' @param top Optional content shown at the top of every chapter, below its
#'   title, typically a [qr_selection_bar()].
#' @param id Storage id that keeps this book's selection apart from other
#'   books on the same website. Defaults to the name of the book's folder.
#' @param dir The book's project folder.
#'
#' @return The paths of the written files, invisibly.
#' @export
#' @examples
#' dir <- tempfile()
#' dir.create(dir)
#' choices <- c(Tilburg = "GM0855", Oss = "GM0828")
#' qr_book_setup(
#'   params  = list(gemeente = qr_param(default = "GM0855", always = "NL01")),
#'   sidebar = qr_select("gemeente", choices),
#'   top     = qr_selection_bar("gemeente", choices),
#'   dir     = dir
#' )
#' list.files(dir)
qr_book_setup <- function(params, sidebar = NULL, top = NULL, id = NULL, dir = ".") {
  id <- id %||% basename(normalizePath(dir, winslash = "/"))

  # The include files are pasted into every page as is, so the store and the
  # libraries the sidebar and top content need (e.g. Tom Select) are inlined.
  deps <- htmltools::resolveDependencies(c(
    list(qr_dependency()), htmltools::findDependencies(htmltools::tagList(sidebar, top))
  ))
  header <- c(
    unlist(lapply(deps, .inline_dependency)),
    "<script>", .config_js(params, id), "</script>"
  )

  # Quarto builds the sidebar and title block before the body includes, so
  # the content is moved into place by script. Without a sidebar (e.g. on
  # narrow screens) the input stays at the end of the page.
  body <- c(
    character(),
    if (!is.null(top)) c(
      '<div id="qr-top">', as.character(top), "</div>",
      "<script>",
      "(function () {",
      "  var el = document.getElementById('qr-top');",
      "  var main = document.querySelector('main#quarto-document-content') || document.querySelector('main');",
      "  if (!main) return;",
      "  var title = main.querySelector('#title-block-header');",
      "  if (title) title.after(el); else main.prepend(el);",
      "})();",
      "</script>"
    ),
    if (!is.null(sidebar)) c(
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
  )

  paths <- file.path(dir, c("_qr-header.html", "_qr-sidebar.html"))
  writeLines(header, paths[1], useBytes = TRUE)
  writeLines(body, paths[2], useBytes = TRUE)
  .check_quarto_yml(dir)
  invisible(paths)
}

# An htmlDependency's stylesheets and scripts as inline <style>/<script> lines.
.inline_dependency <- function(dep) {
  dir <- if (!is.null(dep$package)) system.file(dep$src$file, package = dep$package) else dep$src$file
  read <- function(files) {
    files <- unlist(lapply(files, function(f) if (is.list(f)) f$src else f))
    unlist(lapply(file.path(dir, files), readLines, warn = FALSE, encoding = "UTF-8"))
  }
  c(
    if (length(dep$stylesheet)) c("<style>", read(dep$stylesheet), "</style>"),
    if (length(dep$script)) c("<script>", read(dep$script), "</script>")
  )
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

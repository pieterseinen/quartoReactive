# Spike 2: one selection store for a whole Quarto book.
# Inputs and widgets talk to window.qrState (inst/htmlwidgets/lib/qr-state);
# standard widgets follow it through crosstalk, our own widgets subscribe directly.

`%||%` <- function(a, b) if (is.null(a)) b else a

.input_counter <- local({ n <- 0; function() { n <<- n + 1; n } })

#' Input bound to a book-wide parameter.
#' @param choices Named character vector: values are keys, names are labels.
qr_input <- function(param, choices, label = param, type = c("checkbox", "select", "radio")) {
  type   <- match.arg(type)
  values <- unname(choices)
  labels <- names(choices) %||% values

  body <- if (type == "select") {
    htmltools::tags$select(
      multiple = NA, size = min(length(values), 8),
      unname(Map(function(v, l) htmltools::tags$option(value = v, l), values, labels))
    )
  } else {
    # Radio names must be unique per instance: the sidebar and an inline copy
    # of the same param would otherwise form one browser radio group.
    name <- paste0("qr-", param, "-", .input_counter())
    unname(Map(function(v, l) {
      htmltools::tags$label(class = "qr-option",
                            htmltools::tags$input(type = type, name = name, value = v), l)
    }, values, labels))
  }

  htmltools::div(class = "qr-input", `data-qr-param` = param,
                 htmltools::div(class = "qr-input-label", label), body)
}

#' SharedData whose crosstalk group is the param, keyed on the param's values.
qr_shared <- function(data, key, param) {
  crosstalk::SharedData$new(data, key = key, group = param)
}

#' Icons filled to a percentage, one per selected key.
qr_iconfill <- function(data, key, value, label, param, width = "100%", height = 170) {
  x <- list(
    param  = param,
    keys   = as.character(data[[key]]),
    values = data[[value]],
    labels = as.character(data[[label]])
  )
  htmlwidgets::createWidget("qr_iconfill", x, width = width, height = height, package = "qrspike")
}

#' Write the book-level includes: the state store for every page's <head>,
#' and a sidebar selector for the end of every page's <body>.
#' @param params Named list of options per param: default, always.
#' @param sidebar Optional qr_input() placed in the book sidebar on every page.
qr_book_includes <- function(params, sidebar = NULL, dir = ".") {
  js <- readLines(system.file("htmlwidgets", "lib", "qr-state", "qr-state.js", package = "qrspike"))
  configure <- vapply(names(params), function(p) {
    sprintf('qrState.configure("%s", %s);', p, jsonlite::toJSON(params[[p]]))
  }, "")

  header <- c(
    "<style>",
    "#qr-sidebar-inputs { padding: .75rem 1rem; border-top: 1px solid #dee2e6; }",
    "#qr-sidebar-inputs .qr-option { display: block; font-size: .9rem; }",
    ".qr-input-label { font-weight: 600; margin-bottom: .25rem; }",
    ".qr-input { margin-bottom: 1rem; }",
    "</style>",
    "<script>", js, configure, "</script>"
  )
  writeLines(header, file.path(dir, "_qr-header.html"))

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
  writeLines(body, file.path(dir, "_qr-sidebar.html"))
  invisible(dir)
}

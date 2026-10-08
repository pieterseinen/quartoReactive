# dependencies.R — HTML dependency management for quartoReactive

# Core JS/CSS bundle dependency (included once per document)
.qr_dependencies <- function() {
  htmltools::tagList(
    # TomSelect (for dropdown inputs)
    htmltools::singleton(htmltools::tags$link(
      rel = "stylesheet",
      href = "https://cdn.jsdelivr.net/npm/tom-select/dist/css/tom-select.css"
    )),
    htmltools::singleton(htmltools::tags$script(
      src = "https://cdn.jsdelivr.net/npm/tom-select/dist/js/tom-select.complete.min.js"
    )),
    # jQuery + DataTables (for DT adapter)
    htmltools::singleton(htmltools::tags$script(
      src = "https://code.jquery.com/jquery-3.7.1.min.js"
    )),
    htmltools::singleton(htmltools::tags$link(
      rel = "stylesheet",
      href = "https://cdn.datatables.net/2.0.0/css/dataTables.dataTables.min.css"
    )),
    htmltools::singleton(htmltools::tags$script(
      src = "https://cdn.datatables.net/2.0.0/js/dataTables.min.js"
    )),
    # quartoReactive core bundle
    htmltools::htmlDependency(
      name       = "quartoReactive",
      version    = "0.1.0",
      src        = system.file("js", package = "quartoReactive"),
      script     = "quarto-reactive.js",
      all_files  = FALSE
    ),
    htmltools::htmlDependency(
      name       = "quartoReactive-css",
      version    = "0.1.0",
      src        = system.file("css", package = "quartoReactive"),
      stylesheet = "quarto-reactive.css",
      all_files  = FALSE
    )
  )
}

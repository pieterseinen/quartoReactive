# Shared spike helpers: identical filter inputs for both prototypes.
# Only the "sink" (where a filter goes) differs between A and B.

spike_dep <- function(name, script) {
  htmltools::htmlDependency(name, "0.0.1", src = normalizePath("."),
                            script = script, all_files = FALSE)
}

# Option values in display order: factor levels, otherwise a typed sort.
spike_values <- function(col) {
  if (is.factor(col)) levels(col) else as.character(sort(unique(col)))
}

# filters: named list, e.g. list(cyl = list(input = "radio", label = "Cylinders"))
# Every value is stringified once in R, so R and JS always compare the same text.
spike_filters <- function(data, group, keys, filters) {
  cols <- lapply(names(filters), function(v) as.character(data[[v]]))
  names(cols) <- names(filters)
  payload <- jsonlite::toJSON(list(keys = as.character(keys), cols = cols))

  controls <- lapply(names(filters), function(v) {
    spike_control(data[[v]], group, v, filters[[v]])
  })

  htmltools::tagList(
    spike_dep("qr-spike-inputs", "inputs.js"),
    htmltools::tags$script(id = paste0(group, "-filterdata"),
                           type = "application/json", htmltools::HTML(payload)),
    htmltools::div(class = "qr-spike-filters", `data-group` = group,
                   style = "display:flex;gap:2em;margin-bottom:1em", controls)
  )
}

spike_control <- function(col, group, v, spec) {
  values  <- c("__all__", spike_values(col))
  labels  <- c("All", spike_values(col))
  default <- spec$default %||% "__all__"
  title   <- htmltools::div(style = "font-weight:600", spec$label %||% v)

  if (identical(spec$input, "radio")) {
    opts <- Map(function(val, lab) {
      htmltools::tags$label(
        style = "margin-right:.6em",
        htmltools::tags$input(type = "radio", name = paste0(group, "-", v), value = val,
                              checked = if (val == default) NA),
        lab
      )
    }, values, labels)
    htmltools::div(`data-qr-var` = v, title, unname(opts))
  } else {
    opts <- Map(function(val, lab) {
      htmltools::tags$option(value = val, selected = if (val == default) NA, lab)
    }, values, labels)
    htmltools::div(`data-qr-var` = v, title, htmltools::tags$select(unname(opts)))
  }
}

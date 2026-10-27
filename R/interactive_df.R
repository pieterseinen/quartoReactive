# interactive_df.R — Core data.frame subclass + filter_on() pipe

#' Create a reactive data.frame for interactive Quarto documents
#'
#' Returns a \code{data.frame} subclass that carries reactive metadata.
#' Pass the result directly to \code{plot_ly()}, \code{datatable()}, etc.
#' — it works everywhere a data.frame works.
#'
#' @param data A data.frame.
#' @param id Optional unique HTML namespace. Auto-generated if omitted.
#' @param columns Optional character vector restricting which columns are
#'   serialised to JSON (reduces HTML size for wide data.frames).
#'
#' @return A \code{quarto_reactive_df} object (subclass of \code{data.frame}).
#'
#' @examples
#' \dontrun{
#' interactive_df <- interactive_df(mtcars)
#' interactive_df <- interactive_df(mtcars) |>
#'   filter_on("cyl", input = "radio", label = "Cylinders")
#' }
#'
#' @export
interactive_df <- function(data, id = NULL, columns = NULL) {
  if (!is.data.frame(data))
    stop("data must be a data.frame.", call. = FALSE)

  id <- id %||% .auto_id()

  # Detect column types for metadata
  meta <- .detect_column_types(data)

  # Determine which columns to serialise
  serialise_cols <- if (!is.null(columns)) {
    intersect(columns, names(data))
  } else {
    names(data)
  }

  # Build the reactive data.frame subclass
  result <- data
  class(result) <- c("quarto_reactive_df", class(data))
  attr(result, "qr_id")        <- id
  attr(result, "qr_meta")      <- meta
  attr(result, "qr_filters")   <- list()
  attr(result, "qr_rendered")  <- FALSE
  attr(result, "qr_columns")   <- serialise_cols

  result
}

#' Declare a filter on a reactive data.frame
#'
#' Pipe-friendly function that attaches a filter declaration to the data.
#' Filters are not rendered immediately — use \code{\link{render_inputs}} or
#' \code{\link{render_input}} to place them in the document.
#'
#' @param .data A \code{quarto_reactive_df} object.
#' @param variable Column name to filter on (string).
#' @param input Input type: \code{"radio"}, \code{"dropdown"},
#'   \code{"checkbox"}, or \code{"slider"}.
#' @param label Display label. Defaults to the variable name.
#' @param default Pre-selected value(s). Defaults to the first value for
#'   radio/dropdown, all values for checkbox, and full range for slider.
#' @param ... Input-type-specific options:
#'   \describe{
#'     \item{radio:}{\code{show_all = FALSE} — include an "All" option}
#'     \item{dropdown:}{\code{multiple = FALSE}, \code{search = TRUE},
#'       \code{placeholder = NULL}}
#'     \item{slider:}{\code{min = NULL}, \code{max = NULL},
#'       \code{step = NULL}}
#'   }
#'
#' @return The same \code{quarto_reactive_df} with the filter appended.
#'
#' @examples
#' \dontrun{
#' interactive_df <- interactive_df(mtcars) |>
#'   filter_on("cyl", input = "radio", label = "Cylinders", show_all = TRUE) |>
#'   filter_on("gear", input = "dropdown", label = "Gears")
#' }
#'
#' @export
filter_on <- function(.data, variable, input = "dropdown", label = NULL, default = NULL, ...) {
  .check_reactive_df(.data, ".data")

  if (!variable %in% names(.data))
    stop("Variable '", variable, "' not found in data.", call. = FALSE)

  valid_inputs <- c("radio", "dropdown", "checkbox", "slider")
  if (!input %in% valid_inputs)
    stop("input must be one of: ", paste(valid_inputs, collapse = ", "), call. = FALSE)

  label <- label %||% variable

  # Compute unique values at declaration time
  col <- .data[[variable]]
  if (input == "slider") {
    if (!is.numeric(col))
      stop("slider input requires a numeric column.", call. = FALSE)
    values <- range(col, na.rm = TRUE)
  } else {
    values <- sort(unique(as.character(col)))
    values <- values[!is.na(values) & nzchar(values)]
  }

  extra_opts <- list(...)

  filter_def <- list(
    variable = variable,
    input    = input,
    label    = label,
    default  = default,
    options  = extra_opts,
    values   = values
  )

  filters <- attr(.data, "qr_filters")
  filters[[length(filters) + 1L]] <- filter_def
  attr(.data, "qr_filters") <- filters

  .data
}

#' @export
print.quarto_reactive_df <- function(x, ...) {
  cat(sprintf(
    "<quarto_reactive_df> [%d x %d] id='%s' filters=%d\n",
    nrow(x), ncol(x), attr(x, "qr_id"), length(attr(x, "qr_filters"))
  ))
  filters <- attr(x, "qr_filters")
  if (length(filters) > 0L) {
    for (f in filters) {
      cat(sprintf("  filter: %s (%s) - %s\n", f$variable, f$input, f$label))
    }
  }
  invisible(x)
}

# Preserve attributes through subsetting
#' @export
`[.quarto_reactive_df` <- function(x, ...) {
  result <- NextMethod()
  if (is.data.frame(result)) {
    class(result) <- c("quarto_reactive_df", class(result)[class(result) != "quarto_reactive_df"])
    for (a in c("qr_id", "qr_meta", "qr_filters", "qr_rendered", "qr_columns")) {
      attr(result, a) <- attr(x, a)
    }
  }
  result
}

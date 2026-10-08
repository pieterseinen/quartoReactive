# utils.R — Internal helpers for quartoReactive

# Null-coalescing operator
`%||%` <- function(a, b) if (is.null(a)) b else a

# Convert R value to JS literal string
.as_js <- function(x) {
  if (is.null(x)) "null"
  else as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = "null"))
}

# Wrap JS code in a DOMContentLoaded listener
.js_on_ready <- function(js_body) {
  paste0(
    'document.addEventListener("DOMContentLoaded", function() {\n',
    js_body,
    '\n});' 
  )
}

# Auto-generate a unique id if none provided
.auto_id <- function() {
  paste0("qr-", paste0(sample(c(letters, 0:9), 8, replace = TRUE), collapse = ""))
}

# Detect column types from a data.frame
.detect_column_types <- function(data) {
  lapply(data, function(col) {
    if (is.numeric(col)) "numeric"
    else if (is.logical(col)) "logical"
    else if (inherits(col, "Date") || inherits(col, "POSIXt")) "date"
    else "categorical"
  })
}

# Validate that object is a quarto_reactive_df
.check_reactive_df <- function(x, arg_name = "data") {
  if (!inherits(x, "quarto_reactive_df")) {
    stop(
      arg_name, " must be a quarto_reactive_df object. ",
      "Did you forget to call interactive_df() first?",
      call. = FALSE
    )
  }
}

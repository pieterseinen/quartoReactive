# Internal helpers

`%||%` <- function(a, b) if (is.null(a)) b else a

# Unique suffixes for element ids and radio names, without touching the RNG.
.next_id <- local({
  n <- 0
  function(prefix) {
    n <<- n + 1
    paste0(prefix, "-", n)
  }
})

.check_param <- function(param) {
  if (!is.character(param) || length(param) != 1 || is.na(param) ||
      !grepl("^[A-Za-z][A-Za-z0-9_]*$", param)) {
    stop("`param` must be a single name of letters, digits and underscores, ",
         "starting with a letter.", call. = FALSE)
  }
  invisible(param)
}

.check_column <- function(data, column, arg) {
  if (!is.character(column) || length(column) != 1 || !column %in% names(data)) {
    stop("`", arg, "` must name a column of `data`.", call. = FALSE)
  }
  invisible(column)
}

# JSON for inline <script>s; "</" is escaped so a value cannot close the tag.
.json <- function(x, ...) {
  gsub("</", "<\\/", as.character(jsonlite::toJSON(x, ...)), fixed = TRUE)
}

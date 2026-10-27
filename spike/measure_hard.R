# Hard cases: histogram, ggplotly and a row-subset table, filtered on cyl.
# Usage: Rscript measure_hard.R a_hard.html b_hard.html
Sys.setenv(CHROMOTE_CHROME = Sys.getenv("CHROMOTE_CHROME",
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"))
library(chromote)

expected <- function(cyl) {
  keep <- if (is.null(cyl)) rep(TRUE, nrow(mtcars)) else mtcars$cyl == cyl
  c(histogram = sum(keep), ggplotly = sum(keep), table = sum(keep & mtcars$mpg > 20))
}

snapshot_js <- '(function () {
  var plots = Array.from(document.querySelectorAll(".plotly.html-widget")).map(function (div) {
    return div.data.filter(function (t) { return t.visible !== false; })
                   .reduce(function (n, t) { return n + (t.x || []).length; }, 0);
  });
  var dt = $(".datatables table").DataTable();
  return JSON.stringify({ histogram: plots[0], ggplotly: plots[1], table: dt.page.info().recordsDisplay });
})()'

run_page <- function(path) {
  b <- ChromoteSession$new()
  on.exit(b$close())
  errors <- character()
  b$Runtime$enable()
  b$Runtime$exceptionThrown(callback = function(m) {
    errors <<- c(errors, m$exceptionDetails$exception$description %||% m$exceptionDetails$text)
  })
  invisible(b$Page$navigate(paste0("file:///", normalizePath(path, winslash = "/"))))
  invisible(b$Page$loadEventFired())
  Sys.sleep(2)
  js <- function(code) b$Runtime$evaluate(code, returnByValue = TRUE)$result$value

  cat("\n=====", basename(path), "=====\n")
  for (cyl in list(NULL, 6, 8, NULL)) {
    val <- if (is.null(cyl)) "__all__" else as.character(cyl)
    js(sprintf('document.querySelector("[data-qr-var=cyl] input[value=\\"%s\\"]").click()', val))
    Sys.sleep(0.7)
    got <- unlist(jsonlite::fromJSON(js(snapshot_js)))
    exp <- expected(cyl)[names(got)]
    cat(sprintf("cyl = %-3s  %s\n", if (is.null(cyl)) "All" else cyl,
                paste(sprintf("%s %d/%d %s", names(got), got, exp, ifelse(got == exp, "ok", "FAIL")), collapse = " | ")))
  }
  cat("console errors:", if (length(errors)) paste(unique(errors), collapse = "\n  ") else "none", "\n")
}

for (p in commandArgs(trailingOnly = TRUE)) run_page(p)

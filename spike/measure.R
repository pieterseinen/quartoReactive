# Drives both spike pages through the same filter scenario in headless Edge and
# reports what the widgets show. Usage: Rscript measure.R a_crosstalk.html b_rowmask.html
Sys.setenv(CHROMOTE_CHROME = Sys.getenv("CHROMOTE_CHROME",
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"))
library(chromote)

steps <- list(
  list(label = "initial (am default = 1)", js = NULL,                  f = list(am = 1)),
  list(label = "cyl = 6",                  js = 'radio("cyl", "6")',    f = list(am = 1, cyl = 6)),
  list(label = "gear = 4",                 js = 'select("gear", "4")',  f = list(am = 1, cyl = 6, gear = 4)),
  list(label = "cyl = All",                js = 'radio("cyl", "__all__")', f = list(am = 1, gear = 4)),
  list(label = "am = All",                 js = 'radio("am", "__all__")',  f = list(gear = 4))
)

expected_rows <- function(f) {
  keep <- rep(TRUE, nrow(mtcars))
  for (v in names(f)) keep <- keep & mtcars[[v]] == f[[v]]
  sum(keep)
}

# R's own colour per cyl group, from the unfiltered build.
ref <- plotly::plotly_build(plotly::plot_ly(mtcars, x = ~mpg, y = ~hp, color = ~factor(cyl),
                                            type = "scatter", mode = "markers"))$x$data
ref_colors <- setNames(vapply(ref, function(t) t$marker$color, ""), vapply(ref, `[[`, "", "name"))

helpers <- '
  window.radio = function (v, val) {
    document.querySelector("[data-qr-var=" + v + "] input[value=\\"" + val + "\\"]").click();
  };
  window.select = function (v, val) {
    var s = document.querySelector("[data-qr-var=" + v + "] select");
    s.value = val; s.dispatchEvent(new Event("change", { bubbles: true }));
  };
  window.snapshot = function () {
    var dt = $(".datatables table").DataTable();
    var rows = dt.rows({ search: "applied" }).data();
    var pl = document.querySelector(".plotly.html-widget");
    var traces = pl.data
      .filter(function (t) { return t.visible !== false; })
      .map(function (t) {
        var n = (t.x || []).length;
        return { name: t.name, n: n, color: (t.marker && typeof t.marker.color === "string") ? t.marker.color : "?" };
      });
    return JSON.stringify({
      table: dt.page.info().recordsDisplay,
      first: rows.length ? String(rows[0][0]) : "",
      points: traces.reduce(function (n, t) { return n + t.n; }, 0),
      traces: traces
    });
  };'

run_page <- function(path) {
  b <- ChromoteSession$new()
  on.exit(b$close())
  errors <- character()
  b$Runtime$enable()
  b$Runtime$exceptionThrown(callback = function(m) {
    errors <<- c(errors, m$exceptionDetails$exception$description %||% m$exceptionDetails$text)
  })
  b$Runtime$consoleAPICalled(callback = function(m) {
    if (m$type == "error") errors <<- c(errors, paste(vapply(m$args, function(a) as.character(a$value %||% a$description %||% ""), ""), collapse = " "))
  })
  invisible(b$Page$navigate(paste0("file:///", normalizePath(path, winslash = "/"))))
  invisible(b$Page$loadEventFired())
  Sys.sleep(2)
  js <- function(code) b$Runtime$evaluate(code, returnByValue = TRUE)$result$value
  js(helpers)

  cat("\n=====", basename(path), sprintf("(%.0f KB html)", file.size(path) / 1024), "=====\n")
  for (s in steps) {
    if (!is.null(s$js)) { js(s$js); Sys.sleep(0.7) }
    snap <- jsonlite::fromJSON(js("snapshot()"), simplifyVector = FALSE)
    exp <- expected_rows(s$f)
    colors_ok <- all(vapply(snap$traces, function(t) {
      t$n == 0 || is.null(ref_colors[t$name]) || identical(unname(ref_colors[t$name]), t$color)
    }, TRUE))
    cat(sprintf("%-26s expected %2d | table %2d | points %2d | %s | colours %s | first row: %s\n",
                s$label, exp, snap$table, snap$points,
                if (snap$table == exp && snap$points == exp) "OK  " else "FAIL",
                if (colors_ok) "kept" else "CHANGED", snap$first))
    cat("    traces:", paste(vapply(snap$traces, function(t) sprintf("%s=%d %s", t$name, t$n, t$color), ""), collapse = ", "), "\n")
  }
  cat("console errors:", if (length(errors)) paste(unique(errors), collapse = "\n  ") else "none", "\n")
}

for (p in commandArgs(trailingOnly = TRUE)) run_page(p)

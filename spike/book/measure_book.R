# Serves _book over HTTP and walks one browser tab through the chapters,
# checking that every input and widget shows the stored selection.
# Usage (from spike/book): Rscript measure_book.R
Sys.setenv(CHROMOTE_CHROME = Sys.getenv("CHROMOTE_CHROME",
  "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"))
library(chromote)
source("data.R")

port <- 8765
base <- sprintf("http://127.0.0.1:%d/", port)
server <- httpuv::startServer("127.0.0.1", port, list(
  staticPaths = list("/" = httpuv::staticPath(normalizePath("_book"), indexhtml = TRUE))
))
on.exit(httpuv::stopServer(server), add = TRUE)

name_of <- setNames(areas$name, areas$code)

# What each part of the page should show for a selection (empty = everything).
expected <- function(sel) {
  shown <- if (length(sel)) c(sel, "NL") else areas$code
  list(inputs = sort(sel), codes = sort(shown), names = sort(unname(name_of[shown])))
}

snapshot_js <- '(function () {
  function vals(sel) { return Array.from(document.querySelectorAll(sel)).map(function (e) { return e.value; }).sort(); }
  var out = {
    url: decodeURIComponent(location.search),
    sidebar: vals("#qr-sidebar-inputs input:checked"),
    inline: vals("main .qr-input select option:checked"),
    hasInline: !!document.querySelector("main .qr-input select"),
    icons: Array.from(document.querySelectorAll(".qr-icon")).map(function (f) { return f.dataset.key; }).sort(),
    plots: Array.from(document.querySelectorAll(".plotly.html-widget")).map(function (div) {
      var shown = [];
      div.data.forEach(function (t) {
        if (!t.x || t.x.length === 0 || t.visible === false) return;
        if (t.type === "bar") shown = shown.concat(t.x); else shown.push(t.name);
      });
      return shown.sort();
    }),
    // Category slots plotly actually draws (catches empty gaps between bars).
    axes: Array.from(document.querySelectorAll(".plotly.html-widget")).map(function (div) {
      var ax = div._fullLayout.xaxis;
      if (ax.type !== "category") return null;
      var lo = Math.ceil(ax.range[0]), hi = Math.floor(ax.range[1]);
      return ax._categories.slice(Math.max(lo, 0), hi + 1).sort();
    }),
    tables: Array.from(document.querySelectorAll(".datatables table.dataTable")).map(function (tb) {
      return $(tb).DataTable().rows({ search: "applied" }).data().toArray().map(function (r) { return String(r[0]); }).sort();
    })
  };
  return JSON.stringify(out);
})()'

check <- function(b, label, sel) {
  s <- jsonlite::fromJSON(b$Runtime$evaluate(snapshot_js, returnByValue = TRUE)$result$value, simplifyVector = FALSE)
  e <- expected(sel)
  same <- function(got, want) identical(sort(unlist(got) %||% character()), want %||% character())
  numbered <- function(xs, prefix, want) {
    if (!length(xs)) return(logical())
    setNames(vapply(xs, same, TRUE, want = want), paste0(prefix, seq_along(xs)))
  }
  results <- c(
    sidebar = same(s$sidebar, e$inputs),
    inline  = if (isTRUE(s$hasInline)) same(s$inline, e$inputs),
    icons   = if (length(s$icons) || grepl("transit", label)) same(s$icons, e$codes),
    numbered(s$plots, "plot", e$names),
    numbered(Filter(Negate(is.null), s$axes), "axis", e$names),
    numbered(s$tables, "table", e$codes)
  )
  cat(sprintf("%-46s %s  %s\n    url: %s\n", label,
              if (all(results)) "OK  " else "FAIL",
              paste(sprintf("%s=%s", names(results), ifelse(results, "ok", "FAIL")), collapse = " "),
              s$url))
  if (!all(results)) str(s[names(results)[!results] |> sub(pattern = "\\d+$", replacement = "s")])
}

go <- function(b, path) {
  loaded <- b$Page$loadEventFired(wait_ = FALSE)
  b$Page$navigate(paste0(base, path), wait_ = FALSE)
  b$wait_for(loaded)
  Sys.sleep(1.5)
}

js <- function(b, code) { b$Runtime$evaluate(code); Sys.sleep(0.8) }
click_sidebar <- function(b, codes) {
  for (code in codes) js(b, sprintf('document.querySelector("#qr-sidebar-inputs input[value=\\"%s\\"]").click()', code))
}

errors <- character()
watch <- function(b) {
  b$Runtime$enable()
  b$Runtime$exceptionThrown(callback = function(m) {
    errors <<- c(errors, m$exceptionDetails$exception$description %||% m$exceptionDetails$text)
  })
}

cat("--- tab 1: fresh session ---\n")
b <- ChromoteSession$new(); watch(b)
go(b, "health.html");  check(b, "1. health, first visit (default)", c("GM9001", "GM9002"))
click_sidebar(b, c("GM9001", "GM9002", "GM9003", "GM9005", "GM9007"))
check(b, "2. health, sidebar -> 3,5,7", c("GM9003", "GM9005", "GM9007"))
go(b, "transit.html"); check(b, "3. transit via plain link", c("GM9003", "GM9005", "GM9007"))
go(b, "index.html");   check(b, "4. index (no widgets)", c("GM9003", "GM9005", "GM9007"))
go(b, "health.html");  check(b, "5. back to health", c("GM9003", "GM9005", "GM9007"))
js(b, '(function () { var s = document.querySelector("main .qr-input select");
  Array.from(s.options).forEach(function (o) { o.selected = o.value === "GM9008"; });
  s.dispatchEvent(new Event("change", { bubbles: true })); })()')
check(b, "6. health, inline select -> 8", "GM9008")
go(b, "transit.html"); check(b, "7. transit after inline change", "GM9008")
b$close()

cat("--- tab 2: shared link in a new session ---\n")
b <- ChromoteSession$new(); watch(b)
go(b, "transit.html?gemeente=GM9004,GM9006"); check(b, "8. transit from shared link", c("GM9004", "GM9006"))
click_sidebar(b, c("GM9004", "GM9006"))
check(b, "9. transit, empty selection (shows all)", character())
go(b, "health.html");  check(b, "10. health, empty selection", character())
b$close()

cat("console errors:", if (length(errors)) paste(unique(errors), collapse = "\n  ") else "none", "\n")

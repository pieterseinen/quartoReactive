# Helpers for the browser tests: render a fixture book with Quarto, serve it
# over HTTP (sessionStorage is unreliable on file:// pages) and drive it with a
# headless Chromium browser through chromote.

skip_if_no_browser_stack <- function() {
  skip_on_cran()
  for (pkg in c("chromote", "httpuv", "plotly", "DT", "withr", "sf")) skip_if_not_installed(pkg)
  if (!nzchar(quarto_bin())) skip("Quarto not found (set QUARTO_PATH)")
  chrome <- tryCatch(chromote::find_chrome(), error = function(e) NULL)
  if (is.null(chrome) || !nzchar(chrome)) skip("No Chrome/Edge found (set CHROMOTE_CHROME)")
}

quarto_bin <- function() {
  path <- Sys.getenv("QUARTO_PATH", unname(Sys.which("quarto")))
  if (nzchar(path) && file.exists(path)) path else ""
}

# When testing from the source tree (devtools::test()), Quarto's R process
# would load whatever version of the package is installed. Install the
# current source into a temporary library and put it first on R_LIBS.
# Under R CMD check the package under test is already on R_LIBS.
use_package_under_test <- function(env = parent.frame()) {
  root <- normalizePath(test_path("..", ".."), winslash = "/")
  if (!file.exists(file.path(root, "DESCRIPTION"))) return(invisible())
  lib <- withr::local_tempdir("qr-lib", .local_envir = env)
  r <- file.path(R.home("bin"), "R")
  out <- system2(r, c("CMD", "INSTALL", "--no-docs", "--no-multiarch", "--no-test-load",
                      "-l", shQuote(lib), shQuote(root)), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(out, "status"))) stop("Installing the package failed:\n", paste(out, collapse = "\n"))
  libs <- c(lib, strsplit(Sys.getenv("R_LIBS"), .Platform$path.sep)[[1]])
  withr::local_envvar(R_LIBS = paste(libs, collapse = .Platform$path.sep), .local_envir = env)
}

# Copies a fixture book to a temp dir, renders it and returns the _book path.
render_fixture_book <- function(name, env = parent.frame()) {
  use_package_under_test(env)
  dir <- file.path(withr::local_tempdir(.local_envir = env), name)
  dir.create(dir)
  file.copy(list.files(test_path("fixtures", name), full.names = TRUE), dir, recursive = TRUE)
  out <- system2(quarto_bin(), c("render", shQuote(dir), "--quiet"), stdout = TRUE, stderr = TRUE)
  if (!is.null(attr(out, "status"))) stop("quarto render failed:\n", paste(out, collapse = "\n"))
  file.path(dir, "_book")
}

serve_dir <- function(dir, env = parent.frame()) {
  port <- httpuv::randomPort()
  server <- httpuv::startServer("127.0.0.1", port, list(
    staticPaths = list("/" = httpuv::staticPath(dir, indexhtml = TRUE))
  ))
  withr::defer(httpuv::stopServer(server), envir = env)
  sprintf("http://127.0.0.1:%d/", port)
}

# A browser tab that records uncaught JS errors in `$errors()`.
browser_tab <- function(base, reduced_motion = FALSE, env = parent.frame()) {
  b <- chromote::ChromoteSession$new()
  withr::defer(b$close(), envir = env)
  if (reduced_motion) {
    b$Emulation$setEmulatedMedia(features = list(list(name = "prefers-reduced-motion",
                                                      value = "reduce")))
  }
  errors <- character()
  b$Runtime$enable()
  b$Runtime$exceptionThrown(callback = function(m) {
    errors <<- c(errors, m$exceptionDetails$exception$description %||% m$exceptionDetails$text)
  })
  list(
    go = function(path) {
      loaded <- b$Page$loadEventFired(wait_ = FALSE)
      b$Page$navigate(paste0(base, path), wait_ = FALSE)
      b$wait_for(loaded)
      Sys.sleep(1.5)
    },
    run = function(js) {
      b$Runtime$evaluate(js)
      Sys.sleep(0.8)
    },
    eval = function(js) b$Runtime$evaluate(js, returnByValue = TRUE)$result$value,
    # Presses a key on the focused element.
    press = function(key, code = key, keycode = 13) {
      for (type in c("keyDown", "keyUp")) {
        b$Input$dispatchKeyEvent(type = type, key = key, code = code,
                                 windowsVirtualKeyCode = keycode)
      }
      Sys.sleep(0.5)
    },
    # Types into the focused element and presses Enter, as a reader would.
    type = function(text) {
      b$Input$insertText(text)
      Sys.sleep(0.3)
      for (type in c("keyDown", "keyUp")) {
        b$Input$dispatchKeyEvent(type = type, key = "Enter", code = "Enter",
                                 windowsVirtualKeyCode = 13)
      }
      Sys.sleep(0.8)
    },
    errors = function() errors
  )
}

# What each part of the page shows, as plain lists of keys/names.
page_snapshot <- function(tab) {
  js <- '(function () {
    function vals(sel) { return Array.from(document.querySelectorAll(sel)).map(function (e) { return e.value; }); }
    return JSON.stringify({
      url: decodeURIComponent(location.search),
      storage: Object.keys(sessionStorage),
      sidebar: vals("#qr-sidebar-inputs input:checked"),
      inline: document.querySelector("main .qr-input select") ? vals("main .qr-input select option:checked") : null,
      search: document.querySelector("main .ts-wrapper") ?
        Array.from(document.querySelectorAll("main .ts-control .item")).map(function (e) { return e.dataset.value; }) : null,
      bar: Array.from(document.querySelectorAll(".qr-selection-bar .qr-chip")).map(function (e) { return e.dataset.key; }),
      disabled: document.querySelectorAll("#qr-sidebar-inputs input:disabled").length,
      icons: Array.from(document.querySelectorAll(".qr-icon")).map(function (f) { return f.dataset.key; }),
      plots: Array.from(document.querySelectorAll(".plotly.html-widget")).map(function (div) {
        var shown = [];
        div.data.forEach(function (t) {
          if (!t.x || t.x.length === 0 || t.visible === false) return;
          if (t.type === "bar") shown = shown.concat(t.x); else shown.push(t.name);
        });
        return shown;
      }),
      // Category slots plotly draws (catches empty gaps between bars).
      axes: Array.from(document.querySelectorAll(".plotly.html-widget")).map(function (div) {
        var ax = div._fullLayout.xaxis;
        if (ax.type !== "category") return null;
        return ax._categories.slice(Math.max(Math.ceil(ax.range[0]), 0), Math.floor(ax.range[1]) + 1);
      }).filter(function (a) { return a !== null; }),
      tables: Array.from(document.querySelectorAll(".datatables table.dataTable")).map(function (tb) {
        return $(tb).DataTable().rows({ search: "applied" }).data().toArray().map(function (r) { return String(r[0]); });
      })
    });
  })()'
  s <- jsonlite::fromJSON(tab$eval(js), simplifyVector = FALSE)
  sorted <- function(x) sort(as.character(unlist(x)))
  s$storage <- sorted(s$storage)
  for (part in c("sidebar", "inline", "search", "bar", "icons")) {
    if (!is.null(s[[part]])) s[[part]] <- sorted(s[[part]])
  }
  for (part in c("plots", "axes", "tables")) s[[part]] <- lapply(s[[part]], sorted)
  s
}

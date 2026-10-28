# End-to-end: one selection shared by every chapter of a rendered book.
# The fixture book (fixtures/book) has a sidebar checkbox input on every page,
# an inline select and a plotly line chart + DT table on "health", and icons +
# a plotly bar chart on "transit". "NL" is always shown next to a selection.

skip_if_no_browser_stack()

book <- render_fixture_book("book")
base <- serve_dir(book)
source(test_path("fixtures", "book", "data.R"), local = TRUE)
name_of <- stats::setNames(areas$name, areas$code)

# Checks every input and widget on the current page against a selection
# (empty = everything shown).
expect_page_shows <- function(tab, selection, step) {
  s <- page_snapshot(tab)
  shown <- if (length(selection)) c(selection, "NL") else areas$code
  codes <- sort(shown)
  names <- sort(unname(name_of[shown]))
  selection <- sort(selection)

  expect_identical(s$sidebar, selection, label = paste(step, "sidebar"))
  # The URL lists keys in selection order.
  expect_identical(sort(strsplit(sub("^\\?gemeente=", "", s$url), ",")[[1]]), selection,
                   label = paste(step, "url"))
  expect_identical(s$storage, "qr-state:fixture", label = paste(step, "storage key"))
  expect_identical(s$bar, selection, label = paste(step, "selection bar"))
  # max = 4: at the maximum, the unchecked boxes are disabled.
  expect_identical(s$disabled, if (length(selection) >= 4) nrow(municipalities) - 4L else 0L,
                   label = paste(step, "disabled checkboxes"))
  if (!is.null(s$inline)) expect_identical(s$inline, selection, label = paste(step, "inline input"))
  if (!is.null(s$search)) expect_identical(s$search, selection, label = paste(step, "search chips"))
  if (length(s$icons) || grepl("transit", step)) expect_identical(s$icons, codes, label = paste(step, "icons"))
  for (i in seq_along(s$plots)) expect_identical(s$plots[[i]], names, label = paste(step, "plot", i))
  for (i in seq_along(s$axes)) expect_identical(s$axes[[i]], names, label = paste(step, "axis", i))
  for (i in seq_along(s$tables)) expect_identical(s$tables[[i]], codes, label = paste(step, "table", i))
}

click_sidebar <- function(tab, codes) {
  for (code in codes) {
    tab$run(sprintf('document.querySelector("#qr-sidebar-inputs input[value=\\"%s\\"]").click()', code))
  }
}

test_that("a selection follows the reader through the book", {
  tab <- browser_tab(base)
  tab$go("health.html")
  expect_page_shows(tab, c("GM9001", "GM9002"), "1. health, first visit (default)")

  click_sidebar(tab, c("GM9001", "GM9002", "GM9003", "GM9005", "GM9007"))
  expect_page_shows(tab, c("GM9003", "GM9005", "GM9007"), "2. health, sidebar change")

  tab$go("transit.html")
  expect_page_shows(tab, c("GM9003", "GM9005", "GM9007"), "3. transit via plain link")

  tab$go("index.html")
  expect_page_shows(tab, c("GM9003", "GM9005", "GM9007"), "4. index (no widgets)")

  tab$go("health.html")
  expect_page_shows(tab, c("GM9003", "GM9005", "GM9007"), "5. back to health")

  tab$run('document.querySelector("main .ts-control input").focus()')
  tab$type("Zand")
  expect_page_shows(tab, c("GM9003", "GM9005", "GM9007", "GM9008"), "6. health, search select")

  tab$go("transit.html")
  expect_page_shows(tab, c("GM9003", "GM9005", "GM9007", "GM9008"), "7. transit after search")

  tab$run('document.querySelector(".qr-chip[data-key=\\"GM9003\\"] button").click()')
  expect_page_shows(tab, c("GM9005", "GM9007", "GM9008"), "8. transit, chip removed")

  expect_identical(tab$errors(), character())
})

test_that("max caps every way of selecting", {
  tab <- browser_tab(base)
  tab$go("health.html?gemeente=GM9001,GM9002,GM9003,GM9004,GM9005")
  expect_page_shows(tab, c("GM9001", "GM9002", "GM9003", "GM9004"), "9. link with 5 keys keeps 4")

  tab$run('document.querySelector("main .ts-control input").focus()')
  tab$type("Zand")
  expect_page_shows(tab, c("GM9001", "GM9002", "GM9003", "GM9004"), "10. search at max adds nothing")

  # Custom widgets (e.g. a map selector) call the store directly.
  tab$run('qrState.set("gemeente", ["GM9006", "GM9001", "GM9002", "GM9003", "GM9004", "GM9005"])')
  expect_page_shows(tab, c("GM9001", "GM9002", "GM9003", "GM9004"), "10b. qrState.set keeps the oldest 4")
  expect_identical(tab$errors(), character())
})

test_that("selected keys keep their colour while the selection changes", {
  tab <- browser_tab(base)
  line_colors <- function() {
    cols <- jsonlite::fromJSON(tab$eval('JSON.stringify(Object.fromEntries(
      document.querySelector(".plotly.html-widget").data
        .filter(function (t) { return t.x && t.x.length; })
        .map(function (t) { return [t.name, t.line.color]; })))'))
    unlist(cols)[order(names(cols))]
  }
  icon_color <- function(key) {
    tab$eval(sprintf('document.querySelector(".qr-icon[data-key=\\"%s\\"] .qr-icon-fill").getAttribute("fill")', key))
  }
  nl <- function(cols) cols[setdiff(names(cols), "Nederland")]

  tab$go("health.html")  # default: GM9001, GM9002 take slots 1 and 2
  expect_identical(nl(line_colors()), c(Beekdal = "#aa0000", Heidebroek = "#00aa00"))
  nl_color <- line_colors()[["Nederland"]]

  click_sidebar(tab, "GM9001")  # Heidebroek keeps its colour
  expect_identical(nl(line_colors()), c(Heidebroek = "#00aa00"))
  click_sidebar(tab, "GM9004")  # Lindenoord takes the free first slot
  expect_identical(nl(line_colors()), c(Heidebroek = "#00aa00", Lindenoord = "#aa0000"))
  expect_identical(line_colors()[["Nederland"]], nl_color)

  tab$go("transit.html")  # slots survive navigation, also in our own widget
  expect_identical(icon_color("GM9004"), "#aa0000")
  expect_identical(icon_color("GM9002"), "#00aa00")
  chip_color <- tab$eval('document.querySelector(".qr-chip[data-key=\\"GM9004\\"]").style.getPropertyValue("--qr-chip-color")')
  expect_identical(chip_color, "#aa0000")
  expect_identical(tab$errors(), character())
})

# Filled share of each icon's shape (fill height / shape height), by key.
icon_fill_js <- 'JSON.stringify(Object.fromEntries(Array.from(document.querySelectorAll(".qr-icon"))
  .map(function (f) {
    var fill = f.querySelector(".qr-icon-fill"), back = f.querySelector("rect");
    return [f.dataset.key, +fill.getAttribute("height") / +back.getAttribute("height")];
  })))'
icon_fills <- function(tab) unlist(jsonlite::fromJSON(tab$eval(icon_fill_js)))
pct_of <- stats::setNames(transit_data()$pct_near_stop / 100, transit_data()$code)

test_that("icons fill up to their value, measured on the icon's shape", {
  tab <- browser_tab(base)
  tab$go("transit.html?gemeente=GM9001,GM9003")
  fills <- icon_fills(tab)
  expect_equal(fills, pct_of[names(fills)], tolerance = 1e-6)
  # The person icon does not fill its 16x16 viewBox, so the shape box is smaller.
  shape_height <- tab$eval('+document.querySelector(".qr-icon rect").getAttribute("height")')
  expect_lt(shape_height, 16)
  expect_identical(tab$eval('document.querySelector(".qr-icon[data-key=\\"GM9001\\"] strong").textContent'),
                   paste0(transit_data()$pct_near_stop[1], "%"))
  expect_identical(tab$errors(), character())
})

test_that("a new icon fills up from empty; icons already shown stay put", {
  tab <- browser_tab(base)
  tab$go("transit.html?gemeente=GM9001")
  # In one go: mark the shown icon, add a key, read the new icon at once.
  res <- jsonlite::fromJSON(tab$eval('(function () {
    var old = document.querySelector(".qr-icon[data-key=\\"GM9001\\"]");
    old.dataset.marker = "kept";
    qrState.set("gemeente", ["GM9001", "GM9004"]);
    var fresh = document.querySelector(".qr-icon[data-key=\\"GM9004\\"] .qr-icon-fill");
    return JSON.stringify({
      newHeight: +fresh.getAttribute("height"),
      kept: document.querySelector(".qr-icon[data-key=\\"GM9001\\"]").dataset.marker || null
    });
  })()'))
  expect_identical(res$newHeight, 0L)
  expect_identical(res$kept, "kept")
  Sys.sleep(1)
  expect_equal(icon_fills(tab)[["GM9004"]], pct_of[["GM9004"]], tolerance = 1e-6)
  expect_identical(tab$errors(), character())
})

test_that("an icon out of view waits until it is scrolled into view", {
  tab <- browser_tab(base)
  tab$go("transit.html?gemeente=GM9001")
  tab$run('document.body.style.paddingBottom = "4000px"; window.scrollTo(0, 3500);
           qrState.set("gemeente", ["GM9001", "GM9005"]);')
  Sys.sleep(1)
  expect_identical(icon_fills(tab)[["GM9005"]], 0)
  tab$run('document.querySelector(".qr-icon[data-key=\\"GM9005\\"]").scrollIntoView({block: "center"})')
  Sys.sleep(1)
  expect_equal(icon_fills(tab)[["GM9005"]], pct_of[["GM9005"]], tolerance = 1e-6)
  expect_identical(tab$errors(), character())
})

test_that("with reduced motion icons are full at once", {
  tab <- browser_tab(base, reduced_motion = TRUE)
  tab$go("transit.html?gemeente=GM9001")
  res <- tab$eval('(function () {
    qrState.set("gemeente", ["GM9001", "GM9006"]);
    var f = document.querySelector(".qr-icon[data-key=\\"GM9006\\"]");
    return +f.querySelector(".qr-icon-fill").getAttribute("height") /
           +f.querySelector("rect").getAttribute("height");
  })()')
  expect_equal(res, pct_of[["GM9006"]], tolerance = 1e-6)
})

test_that("a shared link opens with its selection, and empty means everything", {
  tab <- browser_tab(base)
  tab$go("transit.html?gemeente=GM9004,GM9006")
  expect_page_shows(tab, c("GM9004", "GM9006"), "11. transit from shared link")

  click_sidebar(tab, c("GM9004", "GM9006"))
  expect_page_shows(tab, character(), "12. transit, empty selection")

  tab$go("health.html")
  expect_page_shows(tab, character(), "13. health, empty selection")

  expect_identical(tab$errors(), character())
})

test_that("the map selects by click and keyboard, in sync with other inputs", {
  tab <- browser_tab(base)
  map_state <- function() {
    jsonlite::fromJSON(tab$eval('JSON.stringify(Array.from(document.querySelectorAll(".qr-input-map path"))
      .map(function (p) { return { key: p.dataset.key, pressed: p.getAttribute("aria-pressed"),
        disabled: p.getAttribute("aria-disabled"), fill: p.style.fill }; }))'))
  }
  click_map <- function(code) {
    tab$run(sprintf('document.querySelector(".qr-input-map path[data-key=\\"%s\\"]")
      .dispatchEvent(new MouseEvent("click", { bubbles: true }))', code))
  }

  tab$go("index.html")  # default GM9001, GM9002 in slots 1 and 2
  m <- map_state()
  expect_identical(m$key[m$pressed == "true"], c("GM9001", "GM9002"))
  expect_identical(m$fill[m$key %in% c("GM9001", "GM9002")], c("rgb(170, 0, 0)", "rgb(0, 170, 0)"))

  click_map("GM9004")
  expect_page_shows(tab, c("GM9001", "GM9002", "GM9004"), "map: click adds")

  tab$run('document.querySelector(".qr-input-map path[data-key=\\"GM9001\\"]").focus()')
  tab$press("Enter")
  expect_page_shows(tab, c("GM9002", "GM9004"), "map: Enter removes")
  expect_identical(tab$eval('document.querySelector(".qr-map-hover").textContent'), "Beekdal")

  click_sidebar(tab, "GM9006")  # another input: the map follows
  m <- map_state()
  expect_identical(m$key[m$pressed == "true"], c("GM9002", "GM9004", "GM9006"))

  click_map("GM9007")  # fourth key: max reached
  m <- map_state()
  expect_identical(m$key[m$disabled == "true"], c("GM9001", "GM9003", "GM9005", "GM9008"))
  click_map("GM9008")  # at max: nothing happens
  expect_page_shows(tab, c("GM9002", "GM9004", "GM9006", "GM9007"), "map: max holds")
  expect_identical(tab$errors(), character())
})

test_that("widgets in a hidden tab are right when the tab is shown", {
  tab <- browser_tab(base)
  tab$go("extra.html?gemeente=GM9001")
  tab$run('qrState.set("gemeente", ["GM9003", "GM9005"])')   # while the tab is hidden
  tab$run('Array.from(document.querySelectorAll(".panel-tabset .nav-link"))
             .find(function (a) { return a.textContent.trim() === "Hidden"; }).click()')
  Sys.sleep(1.5)
  s <- page_snapshot(tab)
  shown <- c("GM9003", "GM9005", "NL")
  expect_identical(s$plots[[1]], sort(unname(name_of[shown])))
  expect_identical(s$axes[[1]], sort(unname(name_of[shown])))
  expect_identical(s$tables[[1]], sort(shown))
  expect_identical(s$icons, sort(shown))
  expect_gt(tab$eval('document.querySelector(".plotly.html-widget").getBoundingClientRect().width'), 100)
  # Icons created while hidden are measured on their shape once shown: the
  # person icon's shape is shorter than its 16-unit viewBox.
  fills <- icon_fills(tab)
  expect_equal(fills, pct_of[names(fills)], tolerance = 1e-6)
  shape_heights <- jsonlite::fromJSON(tab$eval('JSON.stringify(Array.from(document.querySelectorAll(".qr-icon"))
    .map(function (f) { return +f.querySelector("rect").getAttribute("height"); }))'))
  expect_true(all(shape_heights < 16))
  expect_identical(tab$errors(), character())
})

test_that("leaflet markers follow the selection", {
  tab <- browser_tab(base)
  count_markers <- function() {
    tab$eval('(function () {
      var n = 0;
      HTMLWidgets.find(".leaflet").getMap().eachLayer(function (l) { if (l instanceof L.CircleMarker) n++; });
      return n;
    })()')
  }
  tab$go("extra.html?gemeente=GM9001,GM9002")
  expect_identical(count_markers(), 3L)   # plus NL
  tab$run('qrState.set("gemeente", ["GM9004"])')
  expect_identical(count_markers(), 2L)
  tab$run('qrState.set("gemeente", [])')
  expect_identical(count_markers(), 9L)
  expect_identical(tab$errors(), character())
})

test_that("keys no input on the page knows are dropped from a link", {
  tab <- browser_tab(base)
  tab$go("health.html?gemeente=GM9001,GM9999")
  expect_page_shows(tab, "GM9001", "unknown key dropped")
  expect_identical(tab$errors(), character())
})

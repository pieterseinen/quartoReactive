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
    tab$eval(sprintf('document.querySelector(".qr-icon[data-key=\\"%s\\"] stop").getAttribute("stop-color")', key))
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

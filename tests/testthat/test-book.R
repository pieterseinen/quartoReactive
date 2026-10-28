test_that("qr_book_setup writes header and sidebar includes", {
  dir <- withr::local_tempdir("my-book")
  paths <- qr_book_setup(list(g = qr_param("A")), sidebar = qr_checkbox("g", c("A", "B")),
                         dir = dir)
  header <- paste(readLines(paths[1]), collapse = "\n")
  sidebar <- paste(readLines(paths[2]), collapse = "\n")
  expect_match(header, "window.qrState", fixed = TRUE)
  expect_match(header, sprintf('qrState.namespace("%s")', basename(dir)), fixed = TRUE)
  expect_match(header, 'qrState.configure("g"', fixed = TRUE)
  expect_match(sidebar, 'id="qr-sidebar-inputs"', fixed = TRUE)
  expect_match(sidebar, 'data-qr-param="g"', fixed = TRUE)
})

test_that("without a sidebar the sidebar include is empty", {
  dir <- withr::local_tempdir()
  paths <- qr_book_setup(list(g = qr_param()), id = "x", dir = dir)
  expect_length(readLines(paths[2]), 0)
  expect_match(paste(readLines(paths[1]), collapse = ""), 'namespace("x")', fixed = TRUE)
})

test_that("a _quarto.yml without the includes gets a warning", {
  dir <- withr::local_tempdir()
  writeLines("project:\n  type: book", file.path(dir, "_quarto.yml"))
  expect_warning(qr_book_setup(list(g = qr_param()), dir = dir), "_qr-header.html")
  writeLines(c("format:", "  html:", "    include-in-header: _qr-header.html",
               "    include-after-body: _qr-sidebar.html"), file.path(dir, "_quarto.yml"))
  expect_no_warning(qr_book_setup(list(g = qr_param()), dir = dir))
})

test_that("libraries used by sidebar and top content are inlined", {
  dir <- withr::local_tempdir()
  choices <- c(A = "a", B = "b")
  paths <- qr_book_setup(list(g = qr_param()), sidebar = qr_select("g", choices),
                         top = qr_selection_bar("g", choices), dir = dir)
  header <- readLines(paths[1])
  expect_true(any(grepl("Tom Select v2.6.2", header, fixed = TRUE)))
  expect_identical(sum(grepl("if (window.qrState) return", header, fixed = TRUE)), 1L)
  body <- paste(readLines(paths[2]), collapse = "\n")
  expect_match(body, 'id="qr-top"', fixed = TRUE)
  expect_match(body, 'data-qr-bar="g"', fixed = TRUE)

  plain <- qr_book_setup(list(g = qr_param()), sidebar = qr_checkbox("g", choices), dir = dir)
  expect_false(any(grepl("Tom Select v2.6.2", readLines(plain[1]), fixed = TRUE)))
})

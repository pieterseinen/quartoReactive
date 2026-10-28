d <- data.frame(code = c("A", "B"), naam = c("Aa", "Bb"), pct = c(72.15, NA))

test_that("qr_iconfill passes keys, values and formatting", {
  w <- qr_iconfill(d, "code", "pct", "naam", param = "g", digits = 1, decimal_mark = ",")
  expect_s3_class(w, "qr_iconfill")
  expect_identical(w$x$param, "g")
  expect_identical(unclass(w$x$values), c(72.15, NA))
  expect_identical(w$x$digits, 1)
  expect_identical(w$x$decimal, ",")
  expect_identical(w$x$suffix, "%")
  expect_identical(vapply(w$dependencies, `[[`, "", "name"), "qr-state")
})

test_that("one row still serialises as arrays", {
  w <- qr_iconfill(d[1, ], "code", "pct", "naam", param = "g")
  json <- htmlwidgets:::toJSON(w$x)
  expect_match(json, '"keys":["A"]', fixed = TRUE)
})

test_that("qr_iconfill checks its columns", {
  expect_error(qr_iconfill(d, "code", "nope", param = "g"), "value")
  expect_error(qr_iconfill(d, "code", "naam", param = "g"), "numeric")
})

test_that("built-in icons are listed and readable", {
  expect_true(all(c("house", "person", "people", "heart", "droplet", "smile") %in% qr_icons()))
  for (name in qr_icons()) {
    icon <- .read_icon(name)
    expect_identical(icon$viewBox, "0 0 16 16", label = name)
    expect_match(icon$content, "^<path", label = name)
  }
})

test_that("icons can come from a file or markup", {
  svg <- '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 12"><circle cx="6" cy="6" r="5"/><script>alert(1)</script></svg>'
  file <- withr::local_tempfile(fileext = ".svg")
  writeLines(svg, file)
  for (icon in list(.read_icon(svg), .read_icon(file))) {
    expect_identical(icon$viewBox, "0 0 24 12")
    expect_identical(icon$content, '<circle cx="6" cy="6" r="5"/>')
  }
  # Without a viewBox, width and height define it.
  expect_identical(.read_icon('<svg width="20px" height="10"><rect/></svg>')$viewBox, "0 0 20 10")
})

test_that("bad icons are rejected", {
  expect_error(.read_icon("nope"), "Unknown icon")
  expect_error(.read_icon("<svg viewBox='0 0 1 1'>"), "valid SVG")
  expect_error(.read_icon("<svg><rect/></svg>"), "viewBox")
  expect_error(qr_iconfill(d, "code", "pct", param = "g", icon = 1), "icon")
})

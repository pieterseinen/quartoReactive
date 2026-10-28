d <- data.frame(code = c("A", "B"), naam = c("Aa", "Bb"), pct = c(72.15, NA))

test_that("qr_iconfill passes keys, values and captions", {
  w <- qr_iconfill(d, "code", "pct", "naam", param = "g", digits = 1)
  expect_s3_class(w, "qr_iconfill")
  expect_identical(w$x$param, "g")
  expect_identical(unclass(w$x$text), c("72.2%", NA))
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

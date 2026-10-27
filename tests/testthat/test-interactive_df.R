test_that("interactive_df() returns a data.frame subclass with metadata", {
  x <- interactive_df(mtcars, id = "cars")
  expect_s3_class(x, "quarto_reactive_df")
  expect_s3_class(x, "data.frame")
  expect_equal(attr(x, "qr_id"), "cars")
  expect_equal(attr(x, "qr_columns"), names(mtcars))
  expect_equal(attr(x, "qr_meta")$mpg, "numeric")
})

test_that("interactive_df() rejects non-data.frames", {
  expect_error(interactive_df(1:3), "must be a data.frame")
})

test_that("filter_on() appends filter declarations", {
  x <- interactive_df(mtcars) |>
    filter_on("cyl", input = "radio", label = "Cylinders") |>
    filter_on("gear")
  filters <- attr(x, "qr_filters")
  expect_length(filters, 2)
  expect_equal(filters[[1]]$label, "Cylinders")
  expect_equal(filters[[2]]$input, "dropdown")
  expect_equal(filters[[1]]$values, c("4", "6", "8"))
})

test_that("filter_on() validates its arguments", {
  x <- interactive_df(mtcars)
  expect_error(filter_on(mtcars, "cyl"), "quarto_reactive_df")
  expect_error(filter_on(x, "nope"), "not found")
  expect_error(filter_on(x, "cyl", input = "knob"), "input must be one of")
})

test_that("column subsetting keeps the store id", {
  x <- interactive_df(mtcars, id = "cars")
  sub <- x[, c("mpg", "cyl")]
  expect_s3_class(sub, "quarto_reactive_df")
  expect_equal(attr(sub, "qr_id"), "cars")
})

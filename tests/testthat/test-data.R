d <- data.frame(code = c("A", "A", "B"), year = c(1, 2, 1), y = 1:3)

test_that("qr_data groups by param and keys on the column", {
  sd <- qr_data(d, "code", "gemeente")
  expect_s3_class(sd, "SharedData")
  expect_identical(sd$groupName(), "gemeente")
  expect_identical(sd$key(), c("A", "A", "B"))
  expect_identical(qr_data(d, ~code, "g")$key(), c("A", "A", "B"))
})

test_that("qr_data rejects bad keys", {
  expect_error(qr_data(d, "nope", "g"), "column")
  expect_error(qr_data(d, code ~ year, "g"), "formula")
  expect_error(qr_data(list(code = 1), "code", "g"), "data frame")
})

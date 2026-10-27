test_that("qr_param stores keys as character", {
  p <- qr_param(default = c(1, 2), always = "NL01")
  expect_s3_class(p, "qr_param")
  expect_identical(p$default, c("1", "2"))
  expect_identical(qr_param()$default, character())
  expect_output(print(p), "default: 1, 2")
})

test_that("config JS keeps arrays, also for one or no key", {
  js <- .config_js(list(g = qr_param(default = "A"), h = qr_param()), id = "book")
  expect_identical(js, c(
    'qrState.namespace("book");',
    'qrState.configure("g", {"default":["A"],"always":[]});',
    'qrState.configure("h", {"default":[],"always":[]});'
  ))
})

test_that("config JS cannot close its script tag", {
  js <- .config_js(list(g = qr_param(default = "</script><b>")))
  expect_false(grepl("</script>", js, fixed = TRUE))
})

test_that("config rejects unnamed, invalid or non-qr_param entries", {
  expect_error(.config_js(list(qr_param())), "named list")
  expect_error(.config_js(list(`bad name` = qr_param())), "param")
  expect_error(.config_js(list(g = list(default = "A"))), "qr_param")
})

test_that("qr_config attaches the store", {
  out <- htmltools::renderTags(qr_config(list(g = qr_param("A"))))
  expect_match(out$html, 'qrState.configure("g"', fixed = TRUE)
  expect_identical(vapply(out$dependencies, `[[`, "", "name"), "qr-state")
})

test_that("colors are optional and validated", {
  js <- .config_js(list(g = qr_param(colors = "#123456")))
  expect_identical(js, 'qrState.configure("g", {"default":[],"always":[],"colors":["#123456"]});')
  expect_error(qr_param(colors = 1), "colors")
  expect_output(print(qr_param(colors = c("red", "blue"))), "colors:  red, blue")
})

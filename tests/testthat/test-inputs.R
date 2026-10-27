choices <- c(Tilburg = "GM0855", Oss = "GM0828")

test_that("inputs carry their param and attach the store", {
  for (f in list(qr_select, qr_checkbox, qr_radio)) {
    out <- htmltools::renderTags(f("gemeente", choices))
    expect_match(out$html, 'data-qr-param="gemeente"', fixed = TRUE)
    expect_true("qr-state" %in% vapply(out$dependencies, `[[`, "", "name"))
  }
})

test_that("choices become values with labels", {
  html <- as.character(qr_select("g", choices))
  expect_match(html, '<option value="GM0855">Tilburg</option>', fixed = TRUE)
  expect_match(html, "multiple")
  expect_no_match(as.character(qr_select("g", choices, multiple = FALSE)), "multiple")
  # Unnamed choices are their own labels.
  expect_match(as.character(qr_checkbox("g", c("A", "B"))), 'value="A"/>\\s*A')
})

test_that("labels are escaped", {
  html <- as.character(qr_radio("g", c("<b>x</b>" = "1"), label = "a & b"))
  expect_match(html, "&lt;b&gt;x&lt;/b&gt;", fixed = TRUE)
  expect_match(html, "a &amp; b", fixed = TRUE)
})

test_that("each radio input is its own group", {
  name <- function(x) regmatches(as.character(x), regexpr('name="[^"]+"', as.character(x)))
  expect_false(identical(name(qr_radio("g", choices)), name(qr_radio("g", choices))))
})

test_that("label = NULL omits the label", {
  expect_no_match(as.character(qr_checkbox("g", choices, label = NULL)), "qr-input-label")
})

test_that("bad params and choices are rejected", {
  expect_error(qr_select("my param", choices), "param")
  expect_error(qr_select("g", character()), "choices")
  expect_error(qr_select("g", c("A", NA)), "choices")
})

test_that("qr_select is searchable by default, with Tom Select attached", {
  deps <- function(x) vapply(htmltools::renderTags(x)$dependencies, `[[`, "", "name")
  searchable <- qr_select("g", choices, placeholder = "Zoek")
  expect_match(as.character(searchable), "data-qr-search")
  expect_match(as.character(searchable), 'data-qr-placeholder="Zoek"', fixed = TRUE)
  expect_setequal(deps(searchable), c("qr-state", "tom-select"))
  plain <- qr_select("g", choices, search = FALSE)
  expect_no_match(as.character(plain), "data-qr-search")
  expect_identical(deps(plain), "qr-state")
})

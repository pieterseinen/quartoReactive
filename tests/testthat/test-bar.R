test_that("qr_selection_bar carries param, labels and texts", {
  bar <- qr_selection_bar("g", c(Tilburg = "GM0855", "O<s>s" = "GM0828"),
                          label = "Vergelijking:", empty = "Alles", remove = "Verwijder")
  html <- as.character(bar)
  expect_match(html, 'data-qr-bar="g"', fixed = TRUE)
  expect_match(html, "qr-sticky", fixed = TRUE)
  expect_match(html, "Vergelijking:", fixed = TRUE)
  expect_match(html, 'data-qr-remove="Verwijder"', fixed = TRUE)
  labels <- regmatches(html, regexpr("data-qr-labels=\"[^\"]*\"", html))
  expect_match(labels, "GM0855&quot;:&quot;Tilburg", fixed = TRUE)
  expect_match(labels, "O&lt;s&gt;s", fixed = TRUE)
  expect_identical(vapply(htmltools::renderTags(bar)$dependencies, `[[`, "", "name"), "qr-state")
  expect_no_match(as.character(qr_selection_bar("g", "A", sticky = FALSE, label = NULL)),
                  "qr-sticky|qr-bar-label")
})

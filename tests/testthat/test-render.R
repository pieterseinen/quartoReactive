test_that("render_inputs() embeds the data store and one input per filter", {
  x <- interactive_df(mtcars, id = "cars") |>
    filter_on("cyl", input = "radio") |>
    filter_on("gear", input = "dropdown")
  html <- as.character(htmltools::renderTags(render_inputs(x))$html)
  expect_match(html, 'id="cars-data"', fixed = TRUE)
  expect_match(html, 'id="cars-meta"', fixed = TRUE)
  expect_match(html, 'id="cars-input-cyl"', fixed = TRUE)
  expect_match(html, 'id="cars-input-gear"', fixed = TRUE)
})

test_that("render_inputs() warns when no filters are declared", {
  expect_warning(render_inputs(interactive_df(mtcars)), "No filters declared")
})

test_that("reactive() finds the store through widget constructors", {
  skip_if_not_installed("DT")
  skip_if_not_installed("plotly")
  x <- interactive_df(mtcars, id = "cars") |> filter_on("cyl", input = "radio")

  dt <- as.character(reactive(DT::datatable(x[, c("mpg", "cyl")])))
  expect_match(dt, 'new DataTableAdapter("qr-dt-cars", "cars"', fixed = TRUE)

  p <- as.character(reactive(plotly::plot_ly(x, x = ~mpg, y = ~hp)))
  expect_match(p, 'new PlotlyAdapter("qr-plotly-cars", "cars"', fixed = TRUE)
})

test_that("reactive() errors on plain data.frames", {
  skip_if_not_installed("DT")
  expect_error(reactive(DT::datatable(mtcars)), "Could not detect reactive data")
})

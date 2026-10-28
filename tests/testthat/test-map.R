skip_if_not_installed("sf")

square <- function(x0, y0, s = 10) {
  matrix(c(x0, y0, x0 + s, y0, x0 + s, y0 + s, x0, y0 + s, x0, y0), ncol = 2, byrow = TRUE)
}
shapes <- sf::st_sf(
  code = c("A", "B", "C"),
  naam = c("Aa", "Bee", "Cee"),
  geometry = sf::st_sfc(
    sf::st_multipolygon(list(list(square(0, 0)))),
    # B has a hole.
    sf::st_multipolygon(list(list(square(10, 0), square(12, 2, 2)))),
    # C has two parts.
    sf::st_multipolygon(list(list(square(0, 10)), list(square(15, 15, 5)))),
    crs = 28992
  )
)

test_that("each area becomes a focusable path with key and name", {
  html <- as.character(qr_map_select("g", shapes, key = "code", name = "naam"))
  expect_identical(lengths(regmatches(html, gregexpr("<path ", html))), 3L)
  expect_match(html, 'data-key="B"', fixed = TRUE)
  expect_match(html, 'aria-label="Bee"', fixed = TRUE)
  expect_match(html, '<title>Bee</title>', fixed = TRUE)
  expect_match(html, 'tabindex="0"', fixed = TRUE)
  expect_match(html, 'data-qr-param="g"', fixed = TRUE)
  expect_identical(vapply(htmltools::renderTags(qr_map_select("g", shapes, "code"))$dependencies,
                          `[[`, "", "name"), "qr-state")
})

test_that("geometry is scaled to 1000 units, y down, with holes and parts as subpaths", {
  svg <- .svg_paths(sf::st_geometry(shapes))
  # 20 x 20 map units -> 1000 x 1000.
  expect_identical(svg$viewBox, "0 0 1000 1000")
  # A: square from (0,0) to (10,10) map units; y flips, so it starts at (0, 1000).
  expect_identical(svg$d[1], "M0 1000l500 0 0 -500 -500 0z")
  # B: outer ring plus hole; C: two parts.
  expect_identical(lengths(regmatches(svg$d, gregexpr("M", svg$d))), c(1L, 2L, 2L))
})

test_that("relative steps reproduce the rounded absolute coordinates", {
  wiggly <- sf::st_sfc(sf::st_polygon(list(rbind(
    c(0, 0), c(3.333, 0.017), c(7.777, 1.111), c(9.999, 9.876), c(1.234, 8.888), c(0, 0)
  ))), crs = 28992)
  d <- .svg_paths(wiggly)$d
  nums <- as.numeric(strsplit(gsub("[Mlz]", " ", d), " +")[[1]][-1])
  pts <- matrix(nums, ncol = 2, byrow = TRUE)
  ends <- apply(pts, 2, cumsum)
  # The last point is the sum of the start and all steps; it must equal the
  # last vertex, rounded to 0.1 unit.
  scale <- 1000 / 9.999
  expect_equal(ends[nrow(ends), ], round(c(1.234, 9.876 - 8.888) * scale, 1), tolerance = 1e-9)
})

test_that("longitude/latitude shapes are projected", {
  ll <- sf::st_transform(shapes, 4326)
  expect_match(as.character(qr_map_select("g", ll, "code")), "<path", fixed = TRUE)
})

test_that("bad input is rejected", {
  expect_error(qr_map_select("g", as.data.frame(shapes), "code"), "sf")
  expect_error(qr_map_select("g", shapes, "nope"), "key")
  dup <- shapes; dup$code[2] <- "A"
  expect_error(qr_map_select("g", dup, "code"), "unique")
  pts <- sf::st_sf(code = "A", geometry = sf::st_sfc(sf::st_point(c(0, 0))))
  expect_error(qr_map_select("g", pts, "code"), "polygons")
})

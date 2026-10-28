# Synthetic data for fictional municipalities. GM90xx codes are not real CBS codes.

municipalities <- data.frame(
  code = sprintf("GM90%02d", 1:8),
  name = c("Beekdal", "Heidebroek", "Kanaalzijde", "Lindenoord",
           "Molenveld", "Polderwijk", "Rivierstad", "Zandhoven")
)
benchmark <- data.frame(code = "NL", name = "Nederland")
areas <- rbind(municipalities, benchmark)

choices <- setNames(municipalities$code, municipalities$name)

health_data <- function() {
  withr::with_seed(42, {
    d <- expand.grid(code = areas$code, year = 2018:2024, stringsAsFactors = FALSE)
    d$name <- areas$name[match(d$code, areas$code)]
    base <- setNames(runif(nrow(areas), 70, 85), areas$code)
    d$good_health <- round(base[d$code] + (d$year - 2018) * runif(nrow(d), -0.6, 0.4), 1)
    d
  })
}

transit_data <- function() {
  withr::with_seed(7, {
    data.frame(areas, pct_near_stop = round(runif(nrow(areas), 35, 95)))
  })
}

# A 4 x 2 grid of squares, one per municipality, for the map selector.
municipality_shapes <- function() {
  square <- function(i) {
    x <- ((i - 1) %% 4) * 10
    y <- ((i - 1) %/% 4) * 10
    sf::st_polygon(list(matrix(c(x, y, x + 10, y, x + 10, y + 10, x, y + 10, x, y),
                               ncol = 2, byrow = TRUE)))
  }
  sf::st_sf(municipalities, geometry = sf::st_sfc(lapply(1:8, square), crs = 28992))
}

# A point per area (fictional, around 's-Hertogenbosch) for leaflet markers.
area_points <- function() {
  data.frame(areas, lng = 5.0 + seq_len(nrow(areas)) * 0.05, lat = 51.6 + (seq_len(nrow(areas)) %% 3) * 0.05)
}

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

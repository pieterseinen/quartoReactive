# Builds the example data in inst/extdata for the municipalities of GGD Hart
# voor Brabant: boundaries plus CBS figures on population, income and health.
# Run from the package root: Rscript data-raw/hart_voor_brabant.R
# Needs sf, jsonlite and an internet connection (CBS OData v4).

library(sf)

out <- "inst/extdata"
dir.create(out, showWarnings = FALSE, recursive = TRUE)

# ---- Which municipalities: CBS table 86247NED (Gebieden in Nederland 2026) ----

indeling <- read.csv2("data-raw/86247NED_gemeenten_ggd_2026.csv", skip = 5, header = FALSE,
                      encoding = "UTF-8", strip.white = TRUE)
indeling <- setNames(indeling[, c(1, 2, 5)], c("naam", "code", "ggd"))
indeling <- indeling[grepl("^GM", indeling$code), ]
gemeenten <- indeling[indeling$ggd == "GG5406", c("code", "naam")]
gemeenten <- gemeenten[order(gemeenten$naam), ]

# Benchmarks shown next to the municipalities. CBS only publishes figures for
# GGD regions in some tables (here: health).
benchmarks <- data.frame(code = c("GG5406", "NL01"),
                         naam = c("GGD Hart voor Brabant", "Nederland"))
regios <- rbind(gemeenten, benchmarks)

# ---- Boundaries: CBS gebiedsindelingen 2025, generalised ----------------------

gpkg <- "data-raw/cbsgebiedsindelingen2025.gpkg"
grenzen <- st_read(gpkg, "gemeente_gegeneraliseerd", quiet = TRUE)
grenzen <- grenzen[grenzen$statcode %in% gemeenten$code, ]
missing <- setdiff(gemeenten$code, grenzen$statcode)
if (length(missing)) stop("No 2025 boundary for: ", paste(missing, collapse = ", "))
grenzen <- merge(gemeenten, grenzen[, "statcode"], by.x = "code", by.y = "statcode")
grenzen <- st_as_sf(grenzen)
grenzen <- grenzen[order(grenzen$naam), ]

regio <- st_read(gpkg, "ggdregio_gegeneraliseerd", quiet = TRUE)
regio <- regio[regio$statcode == "GG5406", ]
regio <- st_sf(code = "GG5406", naam = "GGD Hart voor Brabant", geom = st_geometry(regio))

path <- file.path(out, "hart_voor_brabant.gpkg")
unlink(path)
st_write(grenzen, path, "gemeenten", quiet = TRUE)
st_write(regio, path, "ggdregio", quiet = TRUE, append = TRUE)

# ---- CBS OData v4 -----------------------------------------------------------

odata <- function(table, filter) {
  url <- sprintf("https://datasets.cbs.nl/odata/v1/CBS/%s/Observations?$filter=%s",
                 table, utils::URLencode(filter, reserved = TRUE))
  rows <- list()
  while (!is.null(url)) {
    page <- jsonlite::fromJSON(url)
    rows[[length(rows) + 1]] <- page$value
    url <- page[["@odata.nextLink"]]
  }
  do.call(rbind, rows)
}
quoted <- function(x) sprintf("(%s)", paste0("'", x, "'", collapse = ","))

# One column per measure, named by `measures` (CBS code -> column name).
widen <- function(obs, measures, id_cols) {
  obs$col <- names(measures)[match(obs$Measure, measures)]
  wide <- reshape(obs[, c(id_cols, "col", "Value")], idvar = id_cols, timevar = "col",
                  direction = "wide")
  names(wide) <- sub("^Value\\.", "", names(wide))
  wide[, c(id_cols, intersect(names(measures), names(wide)))]
}

add_names <- function(df) {
  df <- merge(regios, df, by.x = "code", by.y = "RegioS")
  df$jaar <- if ("Perioden" %in% names(df)) as.integer(substr(df$Perioden, 1, 4))
  df$Perioden <- NULL
  df
}

# ---- Population: 70072ned Regionale kerncijfers Nederland ---------------------

bevolking_m <- c(
  inwoners            = "M000352_3",  # total population on 1 January
  mannen              = "3000",
  vrouwen             = "4000",
  leeftijd_0_15       = "M8413",
  leeftijd_15_25      = "M8414",
  leeftijd_25_45      = "M8415",
  leeftijd_45_65      = "M8416",
  leeftijd_65_80      = "M8417",
  leeftijd_80_plus    = "M8418",
  dichtheid_per_km2   = "M000100",
  huishoudens         = "1050010_2",
  eenpersoons_pct     = "1050015_2",
  huishoudensgrootte  = "M000114"
)
obs <- odata("70072ned", sprintf("RegioS in %s and Measure in %s and Perioden ge '2015JJ00'",
                                 quoted(regios$code), quoted(bevolking_m)))
bevolking <- add_names(widen(obs, bevolking_m, c("RegioS", "Perioden")))
bevolking <- bevolking[!is.na(bevolking$inwoners), c("code", "naam", "jaar", names(bevolking_m))]

# ---- Income: 86380NED Inkomen van huishoudens, regio (indeling 2026) ----------

inkomen_m <- c(
  huishoudens_x1000      = "1050010_1",
  mediaan_gestand        = "M000934",  # median standardised income, x 1 000 euro
  gemiddeld_gestand      = "M000222",
  mediaan_besteedbaar    = "M000933",
  deciel_1 = "1020870", deciel_2 = "1020880", deciel_3 = "1020890",
  deciel_4 = "1020900", deciel_5 = "1020910", deciel_6 = "1020920",
  deciel_7 = "1020930", deciel_8 = "1020940"
  # Deciles 9 and 10 share the measure code 1020950 in this table, so they
  # cannot be told apart; the top 20% is derived from deciles 1-8 below.
)
obs <- odata("86380NED", sprintf(paste(
  "RegioS in %s and Measure in %s and KenmerkenVanHuishoudens eq '1050010'",
  "and Populatie eq '1050010'"), quoted(regios$code), quoted(inkomen_m)))
inkomen <- add_names(widen(obs, inkomen_m, c("RegioS", "Perioden")))
# Share of households in the national lowest/highest 20% of standardised income.
inkomen$laag_inkomen_pct <- inkomen$deciel_1 + inkomen$deciel_2
inkomen$hoog_inkomen_pct <- round(100 - rowSums(inkomen[paste0("deciel_", 1:8)]), 1)
inkomen <- inkomen[!is.na(inkomen$mediaan_gestand),
                   c("code", "naam", "jaar", "huishoudens_x1000", "mediaan_gestand",
                     "gemiddeld_gestand", "mediaan_besteedbaar", "laag_inkomen_pct",
                     "hoog_inkomen_pct")]

# ---- Health: 86137NED Gezondheidsmonitor 18+, regio, 2024 ---------------------
# Long format: one row per region, age group and indicator, with the 95% interval.

meta <- function(table, entity) {
  jsonlite::fromJSON(sprintf("https://datasets.cbs.nl/odata/v1/CBS/%s/%s", table, entity))$value
}
indicators <- meta("86137NED", "MeasureCodes")[, c("Identifier", "Title", "Unit")]
obs <- odata("86137NED", sprintf("RegioS in %s", quoted(regios$code)))
obs$marge <- c(MW00000 = "waarde", MOG0095 = "ondergrens",
               MBG0095 = "bovengrens")[obs$Marges]
gezondheid <- reshape(obs[, c("RegioS", "Leeftijd", "Measure", "marge", "Value")],
                      idvar = c("RegioS", "Leeftijd", "Measure"), timevar = "marge",
                      direction = "wide")
names(gezondheid) <- sub("^Value\\.", "", names(gezondheid))
gezondheid$leeftijd <- c("10000" = "18+", "53115" = "18-64", "80200" = "65+")[gezondheid$Leeftijd]
gezondheid$indicator <- indicators$Title[match(gezondheid$Measure, indicators$Identifier)]
gezondheid$eenheid <- indicators$Unit[match(gezondheid$Measure, indicators$Identifier)]
gezondheid$cbs_code <- gezondheid$Measure
gezondheid <- add_names(gezondheid)
gezondheid$jaar <- 2024L
gezondheid <- gezondheid[!is.na(gezondheid$waarde),
                         c("code", "naam", "jaar", "leeftijd", "indicator", "eenheid",
                           "waarde", "ondergrens", "bovengrens", "cbs_code")]

# ---- Write ------------------------------------------------------------------

order_rows <- function(df, ...) {
  df <- df[do.call(order, list(match(df$code, regios$code), ...)), ]
  rownames(df) <- NULL
  df
}
write_csv <- function(df, name) {
  utils::write.csv(df, file.path(out, name), row.names = FALSE, fileEncoding = "UTF-8")
  cat(sprintf("%-28s %5d rows, %d regions\n", name, nrow(df), length(unique(df$code))))
}
write_csv(order_rows(bevolking, bevolking$jaar), "hvb_bevolking.csv")
write_csv(order_rows(inkomen, inkomen$jaar), "hvb_inkomen.csv")
write_csv(order_rows(gezondheid, gezondheid$cbs_code, gezondheid$leeftijd), "hvb_gezondheid.csv")
cat(sprintf("%-28s %5d municipalities + GGD region\n", basename(path), nrow(grenzen)))

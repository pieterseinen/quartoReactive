# Shared by every chapter: data, choices and colours.
library(quartoReactive)

read_extdata <- function(file) {
  read.csv(system.file("extdata", file, package = "quartoReactive"), encoding = "UTF-8")
}

bevolking  <- read_extdata("hvb_bevolking.csv")
inkomen    <- read_extdata("hvb_inkomen.csv")
gezondheid <- read_extdata("hvb_gezondheid.csv")

benchmarks <- c("GG5406", "NL01")
gemeenten  <- unique(gezondheid[!gezondheid$code %in% benchmarks, c("code", "naam")])
gemeenten  <- gemeenten[order(gemeenten$naam), ]
choices    <- setNames(gemeenten$code, gemeenten$naam)

# Selected municipalities take these colours in order of selection and keep
# them while selected (qr_param(colors = palette) in _setup.R). Benchmarks are
# neutral. With nothing selected all 19 lines show, reusing the eight hues.
palette <- c("#2a78d6", "#eb6834", "#1baf7a", "#eda100",
             "#e87ba4", "#008300", "#6250d6", "#e34948")
kleuren <- c(
  setNames(rep_len(palette, nrow(gemeenten)), gemeenten$naam),
  "GGD Hart voor Brabant" = "#52514e",
  "Nederland" = "#0b0b0b"
)
strepen <- setNames(ifelse(names(kleuren) %in% c("GGD Hart voor Brabant", "Nederland"),
                           "dash", "solid"), names(kleuren))

# One line per region, benchmarks dashed.
lijnen <- function(data, y, ytitle) {
  data$naam <- factor(data$naam, levels = names(kleuren))
  plotly::plot_ly(qr_data(data, "code", "gemeente"), x = ~jaar, y = y,
                  color = ~naam, colors = kleuren, linetype = ~naam, linetypes = strepen,
                  type = "scatter", mode = "lines+markers",
                  line = list(width = 2), marker = list(size = 8)) |>
    plotly::layout(xaxis = list(title = ""), yaxis = list(title = ytitle),
                   hovermode = "x unified")
}

tabel <- function(data, ...) {
  DT::datatable(qr_data(data, "code", "gemeente"), rownames = FALSE,
                options = list(dom = "t", pageLength = 25, columnDefs = list(
                  list(visible = FALSE, targets = 0))), ...)
}

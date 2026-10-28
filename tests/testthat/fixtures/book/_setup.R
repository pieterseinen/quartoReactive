# Pre-render: book-wide store, config, sidebar input and selection bar.
library(quartoReactive)
source("data.R")

qr_book_setup(
  params  = list(gemeente = qr_param(default = municipalities$code[1:2], always = "NL",
                                     colors = c("#aa0000", "#00aa00", "#0000aa"),
                                     max = 4)),
  sidebar = qr_checkbox("gemeente", choices, label = "Gemeenten"),
  top     = qr_selection_bar("gemeente", choices),
  id      = "fixture"
)

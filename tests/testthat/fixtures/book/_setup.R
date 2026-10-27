# Pre-render: book-wide store, config and sidebar input.
library(quartoReactive)
source("data.R")

qr_book_setup(
  params  = list(gemeente = qr_param(default = municipalities$code[1:2], always = "NL",
                                     colors = c("#aa0000", "#00aa00", "#0000aa"))),
  sidebar = qr_checkbox("gemeente", choices, label = "Gemeenten"),
  id      = "fixture"
)

# Pre-render: the selection store, the sidebar input and the selection bar for
# every chapter.
source("_common.R")

qr_book_setup(
  params  = list(gemeente = qr_param(default = c("GM0855", "GM0796"),
                                     always = benchmarks, colors = palette,
                                     max = length(palette))),
  sidebar = qr_select("gemeente", choices, label = "Gemeenten",
                      placeholder = "Zoek een gemeente"),
  top     = qr_selection_bar("gemeente", choices, label = "Vergelijking:",
                             empty = "Geen gemeente gekozen: alle gemeenten getoond.",
                             remove = "Verwijder")
)

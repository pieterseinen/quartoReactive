# Pre-render: the selection store and the sidebar input for every chapter.
source("_common.R")

qr_book_setup(
  params  = list(gemeente = qr_param(default = c("GM0855", "GM0796"),
                                     always = benchmarks, colors = palette)),
  sidebar = qr_checkbox("gemeente", choices, label = "Gemeenten")
)

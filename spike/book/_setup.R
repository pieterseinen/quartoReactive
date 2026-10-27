# Pre-render: write the book-wide includes (state store + sidebar selector).
source("data.R")

qrspike::qr_book_includes(
  params  = list(gemeente = list(default = municipalities$code[1:2], always = "NL")),
  sidebar = qrspike::qr_input("gemeente", choices, label = "Gemeenten", type = "checkbox")
)

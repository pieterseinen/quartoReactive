# Example data: GGD Hart voor Brabant

`hart_voor_brabant.R` builds the files in `inst/extdata` for the 19
municipalities in GGD region Hart voor Brabant (GG5406). Run it from the
package root with `Rscript data-raw/hart_voor_brabant.R` (needs `sf`,
`jsonlite` and internet access).

## Inputs

| File | Source |
|---|---|
| `86247NED_gemeenten_ggd_2026.csv` | CBS StatLine 86247NED *Gebieden in Nederland 2026*: municipality codes and their GGD region. Committed. |
| `cbsgebiedsindelingen2025.gpkg` | CBS *Gebiedsindelingen 2025* GeoPackage (via PDOK). 166 MB, so **not committed**: download it and place it here to rebuild the boundaries. |

Figures come from the CBS OData v4 API (`https://datasets.cbs.nl/odata/v1/CBS/<table>`).

## Outputs (`inst/extdata`)

| File | Contents | CBS table |
|---|---|---|
| `hart_voor_brabant.gpkg` | layer `gemeenten` (code, naam; generalised, EPSG:28992) and layer `ggdregio` (the region outline) | Gebiedsindelingen 2025 |
| `hvb_bevolking.csv` | per region and year (2015–2026, 1 January): population by sex and age group, density, households | 70072ned Regionale kerncijfers Nederland |
| `hvb_inkomen.csv` | per region and year (2011–2025, latest year preliminary): households, median/mean standardised and disposable income (x 1 000 euro), share of households in the national lowest/highest 20% | 86380NED Inkomen van huishoudens, regio (indeling 2026) |
| `hvb_gezondheid.csv` | per region, age group (18+, 18-64, 65+) and indicator, 2024: value with 95% interval, long format | 86137NED Gezondheidsmonitor 18+, regio, 2024 |

Every table has `code` and `naam`. Benchmarks: `NL01` (Nederland) everywhere,
`GG5406` (GGD Hart voor Brabant) only in the health table, because CBS does
not publish GGD regions in the other two.

## Quirks worth knowing

- Land van Cuijk and Maashorst exist from 2022, Meierijstad from 2017: earlier
  years are missing for them in `hvb_bevolking.csv`. Income figures are
  recalculated by CBS to the 2026 boundaries, so they go back to 2011.
- 2026 population has no density or household figures yet (empty columns).
- Small municipalities lack some health indicators (suppressed by CBS).
- In 86380NED, income deciles 9 and 10 share one measure code, so the top 20%
  is computed as 100 minus deciles 1–8.

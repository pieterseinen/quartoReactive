# quartoReactive

Selections that span a whole Quarto book, without a server. Readers choose,
say, which municipalities to compare; every chart and table in every chapter
follows, the choice survives moving between chapters, and the URL keeps it so
a comparison can be shared.

**See it working:** <https://pieterseinen.github.io/quartoReactive/>, an
example book (in Dutch) comparing the municipalities of GGD Hart voor Brabant,
with a user guide and code examples. Function reference:
<https://pieterseinen.github.io/quartoReactive/package/>.

```r
remotes::install_github("pieterseinen/quartoReactive")
```

```r
# _setup.R, run as the book's pre-render script
library(quartoReactive)
qr_book_setup(
  params  = list(gemeente = qr_param(default = c("GM0855", "GM0796"),
                                     always = "NL01",
                                     colors = c("#2a78d6", "#eb6834", "#1baf7a"),
                                     max = 3)),
  sidebar = qr_select("gemeente", choices, label = "Gemeenten"),  # searchable
  top     = qr_selection_bar("gemeente", choices)                 # every chapter
)
```

```r
# in a chapter
qr_select("gemeente", choices)                          # optional inline input
qr_map_select("gemeente", shapes, key = "code", name = "naam")  # click a map (sf)
plotly::plot_ly(qr_data(df, "code", "gemeente"), ...)   # any crosstalk widget
qr_iconfill(df, key = "code", value = "pct", label = "naam", param = "gemeente",
            icon = "heart")                             # icons filled to a percentage
```

and in `_quarto.yml`:

```yaml
project:
  type: book
  pre-render: _setup.R
format:
  html:
    include-in-header: _qr-header.html
    include-after-body: _qr-sidebar.html
```

For a single document, call `qr_config()` in a chunk instead of
`qr_book_setup()`.

The example book's source is in `examples/book` (`quarto render examples/book`
after installing the package); GitHub Actions publishes it on every push to
`main`. See [ARCHITECTURE.md](ARCHITECTURE.md) for how it works.

## Development

```r
devtools::test()   # unit tests; browser tests need Quarto and Chrome/Edge
```

Set `QUARTO_PATH` and `CHROMOTE_CHROME` if they are not found automatically.

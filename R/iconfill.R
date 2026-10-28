#' Icons filled to a percentage
#'
#' Draws one icon per row, filled from the bottom up to the row's value, and
#' shows only the rows whose key is selected in `param` (plus its `always`
#' keys). Icons fill up from empty when the page loads and when they appear
#' after a selection change, while their number counts up. Readers who ask
#' their system for reduced motion see the final state at once.
#'
#' @param data A data frame with one row per key.
#' @param key,value,label Column names: the key the parameter selects on, the
#'   percentage (0-100) and the caption.
#' @param param Name of the selection parameter.
#' @param icon A built-in icon (see [qr_icons()]), a path to an `.svg` file, or
#'   SVG markup. The icon's shape is filled, so solid icons work best; the fill
#'   height is measured on the shape, not on the empty space around it.
#' @param digits Decimals shown in the caption.
#' @param decimal_mark Decimal separator in the caption, e.g. `","`.
#' @param suffix Text after the number.
#' @param color Fill colour; selected keys use the parameter's `colors`
#'   instead when it has them (see [qr_param()]).
#' @param background Colour of the unfilled part of the icon.
#' @param size Icon height in pixels.
#' @param duration Length of the fill animation in milliseconds; 0 for none.
#' @param width,height Widget size. The default height grows with the icons.
#' @param elementId Optional element id.
#'
#' @return An htmlwidget.
#' @export
#' @examples
#' d <- data.frame(code = c("GM0855", "GM0828"), naam = c("Tilburg", "Oss"),
#'                 pct = c(72.1, 73.8))
#' qr_iconfill(d, key = "code", value = "pct", label = "naam", param = "gemeente",
#'             icon = "heart", digits = 1, decimal_mark = ",")
qr_iconfill <- function(data, key, value, label = key, param, icon = "house",
                        digits = 0, decimal_mark = ".", suffix = "%",
                        color = "#2a7ab0", background = "#dde3e8", size = 64,
                        duration = 900, width = "100%", height = "auto",
                        elementId = NULL) {
  .check_param(param)
  for (arg in c("key", "value", "label")) .check_column(data, get(arg), arg)
  values <- data[[value]]
  if (!is.numeric(values)) stop("`value` must name a numeric column.", call. = FALSE)

  x <- list(
    param      = param,
    icon       = .read_icon(icon),
    color      = color,
    background = background,
    size       = size,
    duration   = duration,
    digits     = digits,
    decimal    = decimal_mark,
    suffix     = suffix,
    # I() keeps one-row data as arrays in the JSON.
    keys       = I(as.character(data[[key]])),
    labels     = I(as.character(data[[label]])),
    values     = I(values)
  )
  htmlwidgets::createWidget(
    "qr_iconfill", x, width = width, height = height, package = "quartoReactive",
    elementId = elementId, dependencies = list(qr_dependency()),
    sizingPolicy = htmlwidgets::sizingPolicy(defaultHeight = "auto",
                                             knitr.figure = FALSE)
  )
}

#' Built-in icons
#'
#' Names of the icons that [qr_iconfill()] has built in, from Bootstrap Icons
#' (MIT licence).
#'
#' @return A character vector.
#' @export
#' @examples
#' qr_icons()
qr_icons <- function() {
  sub("\\.svg$", "", list.files(system.file("icons", package = "quartoReactive"),
                                pattern = "\\.svg$"))
}

# An icon as its viewBox and inner SVG markup.
.read_icon <- function(icon) {
  if (!is.character(icon) || length(icon) != 1 || is.na(icon)) {
    stop("`icon` must be an icon name, an .svg file or SVG markup.", call. = FALSE)
  }
  svg <- if (grepl("<svg", icon, fixed = TRUE)) {
    icon
  } else if (icon %in% qr_icons()) {
    paste(readLines(system.file("icons", paste0(icon, ".svg"), package = "quartoReactive"),
                    warn = FALSE), collapse = "\n")
  } else if (grepl("\\.svg$", icon, ignore.case = TRUE) && file.exists(icon)) {
    paste(readLines(icon, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  } else {
    stop("Unknown icon '", icon, "': use one of ", paste(qr_icons(), collapse = ", "),
         ", an .svg file or SVG markup.", call. = FALSE)
  }
  open <- regmatches(svg, regexpr("<svg\\b[^>]*>", svg))
  if (!length(open) || !grepl("</svg>", svg, fixed = TRUE)) {
    stop("`icon` is not valid SVG markup.", call. = FALSE)
  }
  viewbox <- sub('.*\\bviewBox\\s*=\\s*["\']([^"\']+)["\'].*', "\\1", open)
  if (identical(viewbox, open)) {
    w <- sub('.*\\bwidth\\s*=\\s*["\']([0-9.]+)[^"\']*["\'].*', "\\1", open)
    h <- sub('.*\\bheight\\s*=\\s*["\']([0-9.]+)[^"\']*["\'].*', "\\1", open)
    if (identical(w, open) || identical(h, open)) {
      stop("`icon` needs a viewBox (or width and height).", call. = FALSE)
    }
    viewbox <- paste(0, 0, w, h)
  }
  inner <- sub("(?s).*?<svg\\b[^>]*>(.*)</svg>.*", "\\1", svg, perl = TRUE)
  # Icons are author content, but scripts have no place in a mask.
  inner <- gsub("(?s)<script\\b.*?</script>", "", inner, perl = TRUE)
  list(viewBox = viewbox, content = trimws(inner))
}

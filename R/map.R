#' Select by clicking areas on a map
#'
#' Draws polygons, such as municipality boundaries, as a clickable map bound
#' to a selection parameter: click (or tap, or Tab + Enter) an area to add it
#' to the selection or remove it. Selected areas take their selection colour.
#' The map is an input like [qr_select()]: it works inline and in the book
#' sidebar, and stays in sync with every other input on the parameter.
#'
#' The map is drawn as SVG in R, so the page needs no map library or tiles.
#' Polygons in longitude/latitude are projected to Web Mercator first.
#'
#' @inheritParams qr_inputs
#' @param shapes An `sf` data frame with (multi)polygons.
#' @param key Column with the keys the parameter selects, e.g. `"code"`.
#' @param name Column with the names shown on hover and to screen readers.
#' @param color Fill of selected areas when the parameter has no `colors`.
#' @param fill,border Fill and border colour of areas that are not selected.
#' @param tolerance Optional simplification tolerance in the units of the
#'   (projected) shapes, e.g. `200` for metres. Simplifying areas one by one
#'   can leave small gaps between neighbours; prefer generalised boundaries,
#'   such as CBS's "gegeneraliseerd" layers.
#' @param width Width of the map (CSS); the height follows the shapes.
#'
#' @return An HTML tag.
#' @export
#' @examples
#' if (requireNamespace("sf", quietly = TRUE)) {
#'   path <- system.file("extdata", "hart_voor_brabant.gpkg", package = "quartoReactive")
#'   gemeenten <- sf::st_read(path, "gemeenten", quiet = TRUE)
#'   qr_map_select("gemeente", gemeenten, key = "code", name = "naam")
#' }
qr_map_select <- function(param, shapes, key, name = key, label = param,
                          color = "#2a7ab0", fill = "#e3e7eb", border = "#ffffff",
                          tolerance = NULL, width = "100%") {
  .check_param(param)
  if (!requireNamespace("sf", quietly = TRUE)) {
    stop("qr_map_select() needs the sf package.", call. = FALSE)
  }
  if (!inherits(shapes, "sf")) stop("`shapes` must be an sf data frame.", call. = FALSE)
  for (arg in c("key", "name")) .check_column(shapes, get(arg), arg)
  keys <- as.character(shapes[[key]])
  if (anyNA(keys) || anyDuplicated(keys)) {
    stop("`key` must be unique and not missing; combine areas first ",
         "(e.g. with sf::st_union per key).", call. = FALSE)
  }
  types <- unique(as.character(sf::st_geometry_type(shapes)))
  if (!all(types %in% c("POLYGON", "MULTIPOLYGON"))) {
    stop("`shapes` must hold polygons.", call. = FALSE)
  }

  geom <- sf::st_geometry(shapes)
  if (isTRUE(sf::st_is_longlat(geom))) geom <- sf::st_transform(geom, 3857)
  if (!is.null(tolerance)) geom <- sf::st_simplify(geom, preserveTopology = TRUE, dTolerance = tolerance)

  svg <- .svg_paths(geom)
  names <- as.character(shapes[[name]])
  paths <- lapply(seq_along(keys), function(i) {
    htmltools::tags$path(
      d = svg$d[i], `data-key` = keys[i], tabindex = "0", role = "button",
      `aria-pressed` = "false", `aria-label` = names[i],
      htmltools::tags$title(names[i])
    )
  })

  el <- htmltools::div(
    class = "qr-input qr-input-map", `data-qr-param` = param, `data-qr-map` = NA,
    `data-qr-color` = color,
    style = htmltools::css(`--qr-map-fill` = fill, `--qr-map-border` = border,
                           width = htmltools::validateCssUnit(width)),
    if (!is.null(label)) htmltools::div(class = "qr-input-label", label),
    htmltools::tags$svg(
      viewBox = svg$viewBox, role = "group",
      `aria-label` = if (is.character(label)) label,
      paths
    ),
    htmltools::div(class = "qr-map-hover", `aria-hidden` = "true", htmltools::HTML("&nbsp;"))
  )
  htmltools::attachDependencies(el, qr_dependency())
}

# SVG path data per feature, scaled to a viewBox 1000 units wide with y
# pointing down. Coordinates are rounded to 0.1 unit first and written as
# relative steps, so rounding errors do not add up along a ring.
.svg_paths <- function(geom, size = 1000) {
  bb <- sf::st_bbox(geom)
  scale <- size / max(bb[["xmax"]] - bb[["xmin"]], bb[["ymax"]] - bb[["ymin"]])
  height <- round((bb[["ymax"]] - bb[["ymin"]]) * scale, 1)
  width <- round((bb[["xmax"]] - bb[["xmin"]]) * scale, 1)

  xy <- sf::st_coordinates(geom)
  x <- round((xy[, "X"] - bb[["xmin"]]) * scale * 10)   # tenths of a unit
  y <- round((bb[["ymax"]] - xy[, "Y"]) * scale * 10)
  # Ring and feature ids: L1 ring, L2 polygon, L3 feature (multipolygons).
  levels <- grep("^L[0-9]$", colnames(xy), value = TRUE)
  feature <- xy[, levels[length(levels)]]
  ring <- interaction(as.data.frame(xy[, levels, drop = FALSE]), drop = TRUE, lex.order = TRUE)

  # Values stay within +-1000, so as.character() never uses scientific notation.
  num <- function(v) sub("^(-?)0\\.", "\\1.", as.character(v / 10))
  ring_d <- vapply(split(seq_along(x), ring), function(i) {
    i <- i[-length(i)]                         # rings repeat their first point
    dx <- diff(x[i]); dy <- diff(y[i])
    keep <- dx != 0 | dy != 0
    steps <- paste(num(dx[keep]), num(dy[keep]), collapse = " ")
    paste0("M", num(x[i[1]]), " ", num(y[i[1]]), "l", steps, "z")
  }, character(1))
  ring_feature <- vapply(split(feature, ring), `[`, numeric(1), 1)
  d <- vapply(seq_along(geom), function(f) paste(ring_d[ring_feature == f], collapse = ""),
              character(1))
  list(d = d, viewBox = paste(0, 0, width, height))
}

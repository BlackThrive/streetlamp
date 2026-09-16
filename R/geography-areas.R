# Area hierarchy, re-vintaging and adjacency ---------------------------------------

#' Area hierarchy for 2021 LSOAs
#'
#' One row per 2021 Lower layer Super Output Area in England and Wales with
#' its 2021 Middle layer Super Output Area, 2022 local authority district,
#' police force area and the police.uk force identifier. This is how
#' [lamp_panel()] reaches the `msoa21`, `lad` and `pfa` levels and how it
#' knows which areas belong to a force.
#'
#' Source: Office for National Statistics lookups licensed under the Open
#' Government Licence v3.0; see `inst/NOTES/data_sources.md` for the products
#' and retrieval dates.
#'
#' @return A tibble with columns `lsoa21`, `lsoa21_name`, `msoa21`,
#'   `msoa21_name`, `lad22`, `lad22_name`, `pfa`, `pfa_name` and `force_id`.
#' @family bundled data
#' @export
#' @examples
#' lk <- lamp_area_lookup()
#' table(lk$force_id[lk$pfa_name == "West Yorkshire"])
#' length(unique(lk$msoa21))
lamp_area_lookup <- function() {
  lamp_bundled("area_lookup", function() {
    tibble::as_tibble(readRDS(lamp_extdata("area_lookup.rds")))
  })
}

# Map 2021 LSOA codes to a coarser level; unknown codes become NA.
lamp_map_area <- function(lsoa21, area) {
  if (area == "lsoa21") {
    return(lsoa21)
  }
  lk <- lamp_area_lookup()
  col <- switch(area,
    msoa21 = "msoa21",
    lad = "lad22",
    pfa = "pfa",
    lamp_abort("Unknown area level {.val {area}}.", "input")
  )
  lk[[col]][match(lsoa21, lk$lsoa21)]
}

# Re-vintage LSOA codes with the bundled ONS lookup. From 2011 to 2021 every
# code maps to its best-fit 2021 LSOA. From 2021 to 2011, unchanged and split
# LSOAs map to their single parent; merged and complex ones map to the first
# parent in code order, which is recorded in the summary.
lamp_revintage_codes <- function(codes, from = c("lsoa11", "lsoa21"), to = c("lsoa21", "lsoa11")) {
  from <- rlang::arg_match(from)
  to <- rlang::arg_match(to)
  if (from == to) {
    return(list(codes = codes, summary = NULL))
  }
  lk <- lamp_lsoa_lookup()
  if (from == "lsoa11") {
    map <- lk[lk$best_fit, c("lsoa11", "lsoa21", "change")]
    idx <- match(codes, map$lsoa11)
  } else {
    map <- lk[order(lk$lsoa21, lk$lsoa11), c("lsoa21", "lsoa11", "change")]
    map <- map[!duplicated(map$lsoa21), ]
    idx <- match(codes, map$lsoa21)
  }
  mapped <- map[[to]][idx]
  change <- as.character(map$change[idx])
  distinct <- !duplicated(codes) & !is.na(codes)
  tab <- table(factor(change[distinct], levels = c("U", "S", "M", "X")))
  summary <- list(
    from = from, to = to,
    n_records = sum(!is.na(codes)),
    n_records_mapped = sum(!is.na(mapped)),
    n_areas = sum(distinct),
    n_areas_unmatched = sum(distinct & is.na(mapped)),
    areas_unchanged = as.integer(tab[["U"]]),
    areas_split = as.integer(tab[["S"]]),
    areas_merged = as.integer(tab[["M"]]),
    areas_complex = as.integer(tab[["X"]]),
    share_split_or_merged = if (sum(distinct) > 0) {
      (tab[["S"]] + tab[["M"]] + tab[["X"]]) / sum(distinct)
    } else {
      NA_real_
    }
  )
  list(codes = mapped, summary = summary)
}

#' Re-vintage LSOA codes between 2011 and 2021
#'
#' Converts a vector of LSOA codes from one vintage to the other with the
#' bundled ONS lookup ([lamp_lsoa_lookup()]) and reports how many areas were
#' unchanged, split, merged or complex. From 2011 to 2021 each code maps to
#' its best-fit 2021 LSOA. From 2021 to 2011 unchanged and split LSOAs map to
#' their single parent; a 2021 LSOA formed by a merger maps to the first of
#' its parents in code order, so `lsoa21` panels are the recommended target.
#'
#' @param codes A character vector of LSOA codes.
#' @param from,to The vintages, `"lsoa11"` or `"lsoa21"`.
#'
#' @return A list with `codes` (the mapped vector, `NA` where a code is not
#'   in the lookup) and `summary` (counts of records and distinct areas by
#'   change type and the share of areas that were split or merged).
#' @family panel
#' @export
#' @examples
#' r <- lamp_revintage(c("E01000001", "E01000002", "E01033768"), from = "lsoa11", to = "lsoa21")
#' r$codes
#' r$summary$share_split_or_merged
lamp_revintage <- function(codes, from = c("lsoa11", "lsoa21"), to = c("lsoa21", "lsoa11")) {
  if (!is.character(codes)) {
    lamp_abort("{.arg codes} must be a character vector.", "input")
  }
  lamp_revintage_codes(codes, from = from, to = to)
}

#' Spatial adjacency for a set of areas
#'
#' Builds a neighbour list and row-standardised spatial weights for area
#' polygons with `spdep`, for the spillover estimators and for Moran's I
#' diagnostics. Queen contiguity (any shared point) is the default; rook
#' contiguity needs a shared edge; `knn` links each area to its `k` nearest
#' neighbours by centroid and symmetrises the result. Areas with no
#' neighbours (islands) are allowed and counted.
#'
#' @param boundaries An `sf` polygon layer with an `area` column, for example
#'   from `lamp_boundaries()`.
#' @param method `"queen"` (default), `"rook"` or `"knn"`.
#' @param k Number of neighbours for `method = "knn"`.
#'
#' @return A list of class `lamp_adjacency` with `areas` (identifiers in
#'   order), `nb` (an `spdep` neighbour list), `listw` (row-standardised
#'   weights, `style = "W"`), `method`, `k`, `n_islands`, `boundary_vintage`
#'   (taken from the `vintage` attribute of `boundaries` when present) and
#'   `created`.
#' @family panel
#' @export
#' @examples
#' squares <- sf::st_sf(
#'   area = c("a", "b", "c"),
#'   geometry = sf::st_sfc(
#'     sf::st_polygon(list(rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 1), c(0, 0)))),
#'     sf::st_polygon(list(rbind(c(1, 0), c(2, 0), c(2, 1), c(1, 1), c(1, 0)))),
#'     sf::st_polygon(list(rbind(c(5, 5), c(6, 5), c(6, 6), c(5, 6), c(5, 5)))),
#'     crs = 27700
#'   )
#' )
#' adj <- lamp_adjacency(squares)
#' adj
#' adj$nb
lamp_adjacency <- function(boundaries, method = c("queen", "rook", "knn"), k = 6L) {
  method <- rlang::arg_match(method)
  if (!inherits(boundaries, "sf") || !"area" %in% names(boundaries)) {
    lamp_abort(
      "{.arg boundaries} must be an {.cls sf} object with an {.field area} column.",
      "input"
    )
  }
  if (!is.numeric(k) || length(k) != 1L || k < 1) {
    lamp_abort("{.arg k} must be a single positive number.", "input")
  }
  ids <- as.character(boundaries$area)
  if (anyDuplicated(ids) > 0L) {
    lamp_abort("{.arg boundaries} has duplicated {.field area} identifiers.", "input")
  }
  geom <- sf::st_geometry(boundaries)
  # spdep warns about islands and disconnected sub-graphs; both are reported
  # in the result, so the warnings are muffled here.
  quiet_spdep <- function(expr) {
    withCallingHandlers(expr, warning = function(w) {
      if (grepl("no neighbours|sub-graphs", conditionMessage(w))) {
        invokeRestart("muffleWarning")
      }
    })
  }
  nb <- quiet_spdep(switch(method,
    queen = spdep::poly2nb(geom, queen = TRUE, row.names = ids),
    rook = spdep::poly2nb(geom, queen = FALSE, row.names = ids),
    knn = {
      centroids <- suppressWarnings(sf::st_centroid(geom))
      spdep::knn2nb(
        spdep::knearneigh(centroids, k = as.integer(k)),
        row.names = ids, sym = TRUE
      )
    }
  ))
  listw <- quiet_spdep(spdep::nb2listw(nb, style = "W", zero.policy = TRUE))
  structure(
    list(
      areas = ids,
      nb = nb,
      listw = listw,
      method = method,
      k = if (method == "knn") as.integer(k) else NA_integer_,
      n_islands = sum(spdep::card(nb) == 0L),
      boundary_vintage = attr(boundaries, "vintage", exact = TRUE),
      created = Sys.time()
    ),
    class = "lamp_adjacency"
  )
}

#' @export
print.lamp_adjacency <- function(x, ...) {
  cli::cli_text(
    "{.strong streetlamp adjacency}: {length(x$areas)} area{?s}, {x$method} contiguity",
    "{if (!is.na(x$k)) paste0(' (k = ', x$k, ')') else ''}, ",
    "{sum(spdep::card(x$nb))} link{?s}, {x$n_islands} island{?s}."
  )
  invisible(x)
}

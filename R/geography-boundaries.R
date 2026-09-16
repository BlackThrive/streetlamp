# ONS boundaries ---------------------------------------------------------------------
#
# Digital boundaries from the ONS Open Geography Portal, read page by page
# from the ArcGIS FeatureServer in British National Grid (EPSG:27700) and
# cached as an sf object. The generalised, clipped (BGC, 20 m) products are
# used: they are a tenth of the size of the full-resolution boundaries and
# suit adjacency and mapping, at the cost of occasional misallocation of
# points that lie within a few metres of a boundary. Verified 2026-09-16; see
# the data sources note in the package NOTES folder.

lamp_boundary_products <- function() {
  base <- "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/"
  list(
    lsoa21 = list(
      title = "Lower layer Super Output Areas (December 2021) Boundaries EW BGC (V5)",
      item = "68515293204e43ca8ab56fa13ae8a547",
      service = paste0(
        base, "Lower_layer_Super_Output_Areas_December_2021_Boundaries_EW_BGC_V5",
        "/FeatureServer/0/query"
      ),
      code = "LSOA21CD", name = "LSOA21NM", where = "1=1", n_expected = 35672L
    ),
    lsoa11 = list(
      title = "Lower layer Super Output Areas (December 2011) Boundaries EW BGC (V3)",
      item = "02e8d336d6804fbeabe6c972e5a27b16",
      service = paste0(
        base, "LSOA_Dec_2011_Boundaries_Generalised_Clipped_BGC_EW_V3",
        "/FeatureServer/0/query"
      ),
      code = "LSOA11CD", name = "LSOA11NM", where = "1=1", n_expected = 34753L
    ),
    msoa21 = list(
      title = "Middle layer Super Output Areas (December 2021) Boundaries EW BGC (V3)",
      item = "6b282db29762450881ed5159259a6e4e",
      service = paste0(
        base, "Middle_layer_Super_Output_Areas_December_2021_Boundaries_EW_BGC_V3",
        "/FeatureServer/0/query"
      ),
      code = "MSOA21CD", name = "MSOA21NM", where = "1=1", n_expected = 7264L
    ),
    lad = list(
      title = "Local Authority Districts (December 2022) Boundaries UK BGC",
      item = "995533eee7e44848bf4e663498634849",
      service = paste0(
        base, "Local_Authority_Districts_December_2022_UK_BGC_V2",
        "/FeatureServer/0/query"
      ),
      code = "LAD22CD", name = "LAD22NM",
      where = "LAD22CD LIKE 'E%' OR LAD22CD LIKE 'W%'", n_expected = 331L
    ),
    pfa = list(
      title = "Police Force Areas (December 2023) Boundaries EW BGC",
      item = "4b6a51a4fc8a40ad89d24dd895808e89",
      service = paste0(base, "Police_Force_Areas_December_2023_EW_BGC/FeatureServer/0/query"),
      code = "PFA23CD", name = "PFA23NM", where = "1=1", n_expected = 43L
    )
  )
}

lamp_boundary_page_size <- function() 2000L

lamp_boundary_url <- function(product, offset, limit = lamp_boundary_page_size()) {
  query <- c(
    where = product$where,
    outFields = paste(product$code, product$name, sep = ","),
    returnGeometry = "true", outSR = "27700", f = "geojson",
    resultOffset = format(offset, scientific = FALSE),
    resultRecordCount = format(limit, scientific = FALSE)
  )
  paste0(
    product$service, "?",
    paste(names(query), utils::URLencode(query, reserved = TRUE), sep = "=", collapse = "&")
  )
}

lamp_read_geojson <- function(text, call = rlang::caller_env()) {
  x <- rlang::try_fetch(
    sf::st_read(text, quiet = TRUE),
    error = function(e) {
      lamp_abort(
        "The boundary server returned a page that is not valid GeoJSON.",
        "network",
        call = call,
        parent = e
      )
    }
  )
  if (is.na(sf::st_crs(x))) {
    x <- sf::st_set_crs(x, 27700)
  } else if (sf::st_crs(x) != sf::st_crs(27700)) {
    x <- sf::st_transform(x, 27700)
  }
  x
}

lamp_fetch_boundaries <- function(product, call = rlang::caller_env()) {
  offset <- 0L
  pages <- list()
  repeat {
    text <- lamp_http_get_text(lamp_boundary_url(product, offset), call = call)
    page <- lamp_read_geojson(text, call = call)
    if (nrow(page) == 0L) break
    pages[[length(pages) + 1L]] <- page
    offset <- offset + nrow(page)
    # the server flags a page as partial with exceededTransferLimit
    more <- grepl("\"exceededTransferLimit\"\\s*:\\s*true", text)
    if (!more) break
  }
  if (length(pages) == 0L) {
    lamp_abort(
      "The boundary server returned no features for {.val {product$title}}.",
      "network",
      call = call
    )
  }
  x <- do.call(rbind, pages)
  out <- sf::st_sf(
    area = as.character(x[[product$code]]),
    name = as.character(x[[product$name]]),
    geometry = sf::st_geometry(x)
  )
  if (anyDuplicated(out$area) > 0L) {
    lamp_abort(
      "Duplicated area codes were returned for {.val {product$title}}.",
      "network",
      call = call
    )
  }
  out[order(out$area), ]
}

lamp_boundaries_cache <- function(dir, type) file.path(dir, "boundaries", paste0(type, "_bgc.rds"))

#' ONS digital boundaries as an sf layer
#'
#' Fetches the generalised, clipped (BGC, 20 m) boundaries for a geography
#' from the ONS Open Geography Portal, in British National Grid (EPSG:27700),
#' and caches them. Products: 2021 LSOAs, 2011 LSOAs, 2021 MSOAs, December
#' 2022 local authority districts (England and Wales only) and December 2023
#' police force areas. The generalised boundaries suit adjacency and mapping;
#' a search made within a few metres of a boundary can be assigned to the
#' neighbouring area, so supply full-resolution boundaries yourself for
#' point-in-polygon work that needs that precision.
#'
#' Without network access a cached copy is returned, and an error of class
#' `streetlamp_error_network` is raised if there is none. A first fetch of
#' the 2021 LSOA layer reads about 50 MB in 18 pages.
#'
#' Source: Office for National Statistics licensed under the Open Government
#' Licence v3.0; contains OS data, Crown copyright and database right 2024.
#'
#' @param type One of `"lsoa21"` (default), `"lsoa11"`, `"msoa21"`, `"lad"`
#'   or `"pfa"`.
#' @param dir Cache directory; see [lamp_cache_dir()].
#' @param refresh Fetch again even if a cached copy exists.
#'
#' @return An `sf` object with columns `area` (code), `name` and `geometry`
#'   (multipolygons, EPSG:27700), sorted by `area`, with attributes `vintage`
#'   (for example `"lsoa21-bgc-v5"`), `product` (the ONS title and item
#'   identifier) and `retrieved`.
#' @family panel
#' @export
#' @examplesIf FALSE
#' # Requires network access on first use
#' pfa <- lamp_boundaries("pfa")
#' plot(sf::st_geometry(pfa))
#' adj <- lamp_adjacency(pfa)
lamp_boundaries <- function(type = c("lsoa21", "lsoa11", "msoa21", "lad", "pfa"),
                            dir = lamp_cache_dir(), refresh = FALSE) {
  type <- rlang::arg_match(type)
  check_bool(refresh)
  product <- lamp_boundary_products()[[type]]
  cache <- lamp_boundaries_cache(dir, type)
  if (refresh || !file.exists(cache)) {
    fetched <- rlang::try_fetch(
      lamp_fetch_boundaries(product),
      streetlamp_error_network = function(e) {
        if (file.exists(cache)) {
          lamp_warn(
            "Using the cached boundaries because the server could not be reached.",
            "network"
          )
          return(NULL)
        }
        rlang::cnd_signal(e)
      }
    )
    if (!is.null(fetched)) {
      if (nrow(fetched) != product$n_expected) {
        lamp_warn(
          c(
            "{.val {type}} returned {nrow(fetched)} areas.",
            "i" = "{product$n_expected} were expected when the product was verified."
          ),
          "network"
        )
      }
      attr(fetched, "vintage") <- paste0(type, "-bgc")
      attr(fetched, "product") <- list(
        title = product$title, item = product$item, service = product$service
      )
      attr(fetched, "retrieved") <- Sys.time()
      dir.create(dirname(cache), recursive = TRUE, showWarnings = FALSE)
      saveRDS(fetched, cache)
    }
  }
  readRDS(cache)
}

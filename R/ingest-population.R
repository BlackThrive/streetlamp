# Population from NOMIS -------------------------------------------------------------
#
# Census 2021 usual resident population (table TS001, NOMIS dataset
# NM_2021_1) by 2021 LSOA, fetched once and cached, then aggregated to coarser
# levels with the bundled area lookup. Verified 2026-09-16; see the data
# sources note in the package NOTES folder.

lamp_nomis_dataset <- function() "NM_2021_1"
lamp_nomis_lsoa_type <- function() "TYPE151"
lamp_nomis_page_size <- function() 25000L

lamp_nomis_url <- function(offset, limit = lamp_nomis_page_size()) {
  sprintf(
    paste0(
      "https://www.nomisweb.co.uk/api/v01/dataset/%s.data.csv",
      "?geography=%s&c2021_restype_3=0&measures=20100",
      "&select=geography_code,geography_name,obs_value,record_offset,record_count",
      "&RecordLimit=%d&RecordOffset=%d"
    ),
    lamp_nomis_dataset(), lamp_nomis_lsoa_type(), limit, offset
  )
}

lamp_parse_nomis_page <- function(text, call = rlang::caller_env()) {
  x <- utils::read.csv(text = text, colClasses = "character", check.names = FALSE)
  names(x) <- toupper(names(x))
  needed <- c("GEOGRAPHY_CODE", "GEOGRAPHY_NAME", "OBS_VALUE", "RECORD_COUNT")
  if (!all(needed %in% names(x))) {
    lamp_abort(
      c(
        "The NOMIS response did not have the expected columns.",
        "i" = "Got {.field {names(x)}}."
      ),
      "network",
      call = call
    )
  }
  list(
    rows = tibble::tibble(
      area = x$GEOGRAPHY_CODE, name = x$GEOGRAPHY_NAME,
      population = as.numeric(x$OBS_VALUE)
    ),
    total = if (nrow(x) > 0L) as.integer(x$RECORD_COUNT[1]) else 0L
  )
}

# Fetch every 2021 LSOA, paging past the anonymous 25,000-row cap.
lamp_fetch_nomis_lsoa <- function(call = rlang::caller_env()) {
  offset <- 0L
  pages <- list()
  total <- NA_integer_
  repeat {
    text <- lamp_http_get_text(lamp_nomis_url(offset), call = call)
    page <- lamp_parse_nomis_page(text, call = call)
    if (nrow(page$rows) == 0L) break
    pages[[length(pages) + 1L]] <- page$rows
    total <- page$total
    offset <- offset + nrow(page$rows)
    if (offset >= total) break
  }
  out <- dplyr::bind_rows(pages)
  if (nrow(out) != total || anyDuplicated(out$area) > 0L) {
    lamp_abort(
      "NOMIS returned {nrow(out)} rows for {total} areas; the download is incomplete.",
      "network",
      call = call
    )
  }
  out
}

lamp_population_cache <- function(dir) file.path(dir, "population", "nomis_ts001_lsoa21.rds")

#' Census 2021 usual resident population by area
#'
#' Fetches the Census 2021 usual resident population of every 2021 LSOA in
#' England and Wales from the NOMIS API (table TS001, dataset `NM_2021_1`),
#' caches it, and returns it at the requested area level. Coarser levels are
#' sums of LSOA values through [lamp_area_lookup()]; because ONS applies
#' cell-key perturbation to small-area counts, these sums differ from the
#' published MSOA and district totals by a few persons. 2011 LSOAs receive
#' the population of the 2021 LSOAs that map to them: unchanged and split
#' LSOAs pass their value to their single parent, and a 2021 LSOA formed by a
#' merger shares its value equally among its parents, so `lsoa11` values are
#' approximate.
#'
#' Without network access a cached download is returned, and an error of
#' class `streetlamp_error_network` is raised if there is none.
#'
#' @param area The area level: `"lsoa21"` (default), `"msoa21"`, `"lad"`,
#'   `"pfa"` or `"lsoa11"`.
#' @param dir Cache directory; see [lamp_cache_dir()].
#' @param refresh Fetch from NOMIS again even if a cached copy exists.
#'
#' @return A tibble with columns `area`, `name` (`NA` for aggregated levels)
#'   and `population`, with attributes `area` (the level) and `source` (a
#'   list naming the NOMIS dataset, the census, the geography type, the
#'   retrieval time and the aggregation rule) that [lamp_panel()] copies into
#'   the contract.
#' @family panel
#' @export
#' @examplesIf FALSE
#' # Requires network access on first use
#' pop <- lamp_population("lsoa21")
#' head(pop)
#' pfa <- lamp_population("pfa")
lamp_population <- function(area = c("lsoa21", "msoa21", "lad", "pfa", "lsoa11"),
                            dir = lamp_cache_dir(), refresh = FALSE) {
  area <- rlang::arg_match(area)
  check_bool(refresh)
  cache <- lamp_population_cache(dir)
  if (refresh || !file.exists(cache)) {
    lsoa <- rlang::try_fetch(
      lamp_fetch_nomis_lsoa(),
      streetlamp_error_network = function(e) {
        if (file.exists(cache)) {
          lamp_warn(
            "Using the cached NOMIS population because the API could not be reached.",
            "network"
          )
          return(NULL)
        }
        rlang::cnd_signal(e)
      }
    )
    if (!is.null(lsoa)) {
      attr(lsoa, "retrieved") <- Sys.time()
      dir.create(dirname(cache), recursive = TRUE, showWarnings = FALSE)
      saveRDS(lsoa, cache)
    }
  }
  lsoa <- readRDS(cache)
  retrieved <- attr(lsoa, "retrieved", exact = TRUE)
  lamp_population_at(lsoa, area, retrieved)
}

# Aggregate a 2021 LSOA population table to another level.
lamp_population_at <- function(lsoa, area, retrieved) {
  out <- if (area == "lsoa21") {
    tibble::tibble(area = lsoa$area, name = lsoa$name, population = lsoa$population)
  } else if (area == "lsoa11") {
    # every 2011 to 2021 pair in the lookup; a 2021 LSOA with several 2011
    # parents (merged or complex) shares its population equally among them
    lk <- lamp_lsoa_lookup()
    pairs <- lk[lk$lsoa21 %in% lsoa$area, c("lsoa11", "lsoa21")]
    n_parents <- table(pairs$lsoa21)
    pairs$population <- lsoa$population[match(pairs$lsoa21, lsoa$area)] /
      as.numeric(n_parents[pairs$lsoa21])
    agg <- pairs |>
      dplyr::group_by(.data$lsoa11) |>
      dplyr::summarise(population = sum(.data$population), .groups = "drop")
    tibble::tibble(area = agg$lsoa11, name = NA_character_, population = agg$population)
  } else {
    target <- lamp_map_area(lsoa$area, area)
    agg <- tibble::tibble(area = target, population = lsoa$population) |>
      dplyr::filter(!is.na(.data$area)) |>
      dplyr::group_by(.data$area) |>
      dplyr::summarise(population = sum(.data$population), .groups = "drop")
    tibble::tibble(area = agg$area, name = NA_character_, population = agg$population)
  }
  out <- out[order(out$area), ]
  attr(out, "area") <- area
  attr(out, "source") <- list(
    source = "NOMIS NM_2021_1 (Census 2021 TS001, usual residents)",
    dataset = lamp_nomis_dataset(),
    census = "2021",
    geography_type = lamp_nomis_lsoa_type(),
    retrieved = retrieved,
    aggregation = if (area == "lsoa21") "none" else paste("sum of 2021 LSOA values to", area)
  )
  out
}

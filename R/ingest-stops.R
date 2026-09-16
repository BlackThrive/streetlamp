# Stop counts ---------------------------------------------------------------------
#
# streetlamp reads stop-and-search files only to count stops by area and
# month, with a Section 60 flag. Only the Date, Latitude, Longitude and
# Legislation columns are read from disk; nothing else in the file is parsed.

lamp_stop_columns <- function() c("Date", "Latitude", "Longitude", "Legislation")

#' Legislation label for Section 60 searches
#'
#' The exact string that data.police.uk uses in the `Legislation` column of
#' stop-and-search files for searches under section 60 of the Criminal Justice
#' and Public Order Act 1994 (verified 2026-09-16).
#'
#' @return A string.
#' @family ingest
#' @export
#' @examples
#' lamp_s60_legislation()
lamp_s60_legislation <- function() {
  "Criminal Justice and Public Order Act 1994 (section 60)"
}

# Read only the four needed columns of a stop-and-search file.
lamp_read_stop_file <- function(path, file, call = rlang::caller_env()) {
  header <- names(utils::read.csv(path, nrows = 1, check.names = FALSE))
  missing <- setdiff(lamp_stop_columns(), header)
  if (length(missing) > 0L) {
    lamp_abort(
      "{.file {file}} lacks the column{?s} {.field {missing}}.",
      "input",
      call = call
    )
  }
  classes <- ifelse(header %in% lamp_stop_columns(), "character", "NULL")
  names(classes) <- header
  utils::read.csv(
    path,
    colClasses = classes, na.strings = "", check.names = FALSE,
    encoding = "UTF-8", stringsAsFactors = FALSE
  )
}

# Stops are dated by the file's month, not by the Date column: the publisher
# stores local time as UTC, so a few searches made after 23:00 on the first
# night of a summer-time month carry the previous month's date. Their number
# is reported as n_outside_month.
lamp_parse_stops <- function(raw, force_id, archive, file, month) {
  date <- raw[["Date"]]
  row_month <- as.Date(paste0(substr(date, 1, 7), "-01"))
  n_outside <- sum(is.na(row_month) | row_month != month)
  data <- tibble::tibble(
    force_id = force_id,
    month = month,
    longitude = as.numeric(raw[["Longitude"]]),
    latitude = as.numeric(raw[["Latitude"]]),
    is_s60 = !is.na(raw[["Legislation"]]) & raw[["Legislation"]] == lamp_s60_legislation(),
    no_legislation = is.na(raw[["Legislation"]]),
    archive = archive
  )
  data$no_location <- is.na(data$latitude) | is.na(data$longitude)
  diagnostics <- tibble::tibble(
    archive = archive, file = file, force_id = force_id, month = month,
    n_records = nrow(raw), n_s60 = sum(data$is_s60),
    n_no_location = sum(data$no_location),
    n_no_legislation = sum(data$no_legislation),
    n_outside_month = n_outside
  )
  list(data = data, diagnostics = diagnostics)
}

lamp_assign_area <- function(points, boundaries, call = rlang::caller_env()) {
  if (!inherits(boundaries, "sf") || !"area" %in% names(boundaries)) {
    lamp_abort(
      "{.arg boundaries} must be an {.cls sf} object with an {.field area} column.",
      "input",
      call = call
    )
  }
  located <- which(!points$no_location)
  area <- rep(NA_character_, nrow(points))
  if (length(located) == 0L) {
    return(area)
  }
  pts <- sf::st_as_sf(
    data.frame(
      id = located,
      longitude = points$longitude[located],
      latitude = points$latitude[located]
    ),
    coords = c("longitude", "latitude"), crs = 4326
  )
  pts <- sf::st_transform(pts, 27700)
  polys <- sf::st_transform(boundaries[, "area"], 27700)
  polys$area <- as.character(polys$area)
  hits <- sf::st_join(pts, polys, join = sf::st_within, left = TRUE)
  # a point on a shared boundary matches several polygons; keep the first
  hits <- hits[!duplicated(hits$id), ]
  area[hits$id] <- hits$area
  area
}

#' Count stops by area and month
#'
#' Reads the selected `stop-and-search` files and counts searches by area and
#' month, with a Section 60 flag. Only the `Date`, `Latitude`, `Longitude` and
#' `Legislation` columns are read; the package never parses the ethnicity,
#' object, outcome or other fields. Area assignment is by point-in-polygon in
#' British National Grid (EPSG:27700) against boundaries you supply; without
#' boundaries, counts are per force (the force that submitted the file).
#' Stops are dated by the month of the file they were published in: the
#' publisher stores local time as UTC, so a handful of searches made after
#' 23:00 on the first night of a summer-time month carry the previous month's
#' date, and the count of such rows is reported per file as
#' `n_outside_month`.
#'
#' @inheritParams lamp_read_crime
#' @param area `"force"` (default) for force-month counts, or `"lsoa21"`,
#'   `"lsoa11"` or another label describing the polygons in `boundaries`.
#' @param boundaries An `sf` polygon layer with an `area` column giving the
#'   area identifier; required unless `area = "force"`. `lamp_boundaries()`
#'   provides ONS LSOA boundaries.
#'
#' @return A tibble of class `lamp_records` with one row per area and month:
#'   `area`, `month`, `force_id` (the submitting force), `stops`,
#'   `stops_s60` and `archive`; for `area = "force"` also `stops_no_location`
#'   (searches without coordinates, which cannot be placed in an area) and
#'   `stops_no_legislation`. The contract's `stops` element records the
#'   origin (`streetlamp`), the definition (`raw count`), the area type and
#'   per-file diagnostics, and its `coverage` element marks force-months with
#'   no stop-and-search file as `missing`.
#' @family ingest
#' @export
#' @examples
#' cache <- tempfile("streetlamp-cache-")
#' zip <- system.file("extdata", "archive", "2026-07.zip", package = "streetlamp")
#' lamp_archive_register(zip, dir = cache)
#' stops <- lamp_read_stop_counts(cache, forces = c("west-yorkshire", "dyfed-powys"))
#' stops
#' lamp_contract(stops)$coverage
lamp_read_stop_counts <- function(dir = lamp_cache_dir(), versions = NULL, area = "force",
                                  boundaries = NULL, months = NULL, forces = NULL,
                                  fetch = FALSE) {
  check_string(area)
  check_bool(fetch)
  if (area != "force" && is.null(boundaries)) {
    lamp_abort(
      c(
        "{.arg boundaries} is required for area {.val {area}}.",
        "i" = "Supply an {.cls sf} polygon layer with an {.field area} column."
      ),
      "input"
    )
  }
  months <- lamp_as_months(months)
  snapshot <- lamp_resolve_snapshot(dir)
  sel <- lamp_resolve_selection(snapshot, versions, "stop-and-search", months, forces, fetch)
  members <- lamp_selection_members(snapshot, sel)
  parts <- vector("list", nrow(sel))
  diag <- vector("list", nrow(sel))
  for (i in seq_len(nrow(sel))) {
    path <- lamp_member_path(snapshot, sel$archive[i], members$member[i], fetch = fetch)
    raw <- lamp_read_stop_file(path, members$member[i])
    parsed <- lamp_parse_stops(
      raw, sel$force_id[i], sel$archive[i], members$member[i], sel$month[i]
    )
    parts[[i]] <- parsed$data
    diag[[i]] <- parsed$diagnostics
  }
  points <- dplyr::bind_rows(parts)
  diagnostics <- dplyr::bind_rows(diag)

  if (area == "force") {
    counts <- points |>
      dplyr::group_by(.data$force_id, .data$month, .data$archive) |>
      dplyr::summarise(
        stops = dplyr::n(),
        stops_s60 = sum(.data$is_s60),
        stops_no_location = sum(.data$no_location),
        stops_no_legislation = sum(.data$no_legislation),
        .groups = "drop"
      )
    counts <- tibble::tibble(area = counts$force_id, counts)
    n_unassigned <- 0L
  } else {
    points$area <- lamp_assign_area(points, boundaries)
    n_unassigned <- sum(is.na(points$area) & !points$no_location)
    counts <- points |>
      dplyr::filter(!is.na(.data$area)) |>
      dplyr::group_by(.data$area, .data$month, .data$force_id, .data$archive) |>
      dplyr::summarise(
        stops = dplyr::n(),
        stops_s60 = sum(.data$is_s60),
        .groups = "drop"
      )
  }
  counts <- counts[order(counts$area, counts$month), ]
  coverage <- lamp_coverage_grid(snapshot, sel, "stop-and-search", months, forces)
  coverage$n_records <- diagnostics$n_records[match(
    paste(coverage$force_id, lamp_month_id(coverage$month)),
    paste(diagnostics$force_id, lamp_month_id(diagnostics$month))
  )]
  contract <- new_lamp_contract(
    snapshots = snapshot$archives[snapshot$archives$archive %in% sel$archive, ],
    versions = sel,
    coverage = coverage,
    geography = list(area = area, lsoa_vintage = NULL, files = NULL),
    stops = list(
      origin = "streetlamp",
      definition = "raw count",
      area = area,
      s60_legislation = lamp_s60_legislation(),
      n_unassigned = n_unassigned,
      diagnostics = diagnostics
    )
  )
  new_lamp_records(counts, contract)
}

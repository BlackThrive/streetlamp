# Shared helpers for the test suite. Everything runs offline against the
# bundled mini archives in inst/extdata/archive.

fixture_zips <- function() {
  list.files(
    system.file("extdata", "archive", package = "streetlamp"),
    pattern = "^[0-9]{4}-[0-9]{2}\\.zip$", full.names = TRUE
  )
}

# A temporary cache directory with both bundled mini archives registered.
local_fixture_cache <- function(envir = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = envir)
  for (z in fixture_zips()) {
    suppressMessages(lamp_archive_register(z, dir = dir))
  }
  dir
}

# Serve the bundled mini archives as if they were remote: HEAD and byte-range
# requests are answered from the local zip named in the URL.
local_mock_archive_network <- function(envir = parent.frame()) {
  zip_for <- function(url) {
    archive <- sub("\\.zip$", "", basename(url))
    path <- file.path(system.file("extdata", "archive", package = "streetlamp"), paste0(archive, ".zip"))
    if (!file.exists(path)) stop("no fixture for ", url)
    path
  }
  testthat::local_mocked_bindings(
    lamp_http_head = function(url, call = NULL) {
      path <- zip_for(url)
      list(
        url = url, size = file.size(path), etag = "\"fixture\"",
        last_modified = "Thu, 03 Sep 2026 15:53:27 GMT", accept_ranges = "bytes"
      )
    },
    lamp_http_range = function(url, from, to, call = NULL) {
      path <- zip_for(url)
      con <- file(path, open = "rb")
      on.exit(close(con))
      seek(con, where = from, origin = "start")
      readBin(con, what = "raw", n = to - from + 1)
    },
    .env = envir
  )
}

fixture_index_html <- function() {
  readLines(test_path("fixtures", "archive-index.html"), warn = FALSE) |>
    paste(collapse = "\n")
}

# A twelve-column street file as read from disk, for parser tests.
synthetic_street <- function(crime_types, lsoa = "E01000001", month = "2013-01") {
  n <- length(crime_types)
  data.frame(
    "Crime ID" = ifelse(crime_types == "Anti-social behaviour", NA_character_, sprintf("id%03d", seq_len(n))),
    "Month" = month,
    "Reported by" = "Test Force",
    "Falls within" = "Test Force",
    "Longitude" = "-1.5",
    "Latitude" = "53.8",
    "Location" = "On or near Test Street",
    "LSOA code" = lsoa,
    "LSOA name" = "Test 001A",
    "Crime type" = crime_types,
    "Last outcome category" = ifelse(crime_types == "Anti-social behaviour", NA_character_, "Under investigation"),
    "Context" = NA_character_,
    check.names = FALSE, stringsAsFactors = FALSE
  )
}

synthetic_stops <- function(legislation, lat = 53.8, lon = -1.5, date = "2026-07-02T10:00:00+00:00") {
  n <- length(legislation)
  data.frame(
    "Date" = rep_len(date, n),
    "Latitude" = as.character(rep_len(lat, n)),
    "Longitude" = as.character(rep_len(lon, n)),
    "Legislation" = legislation,
    check.names = FALSE, stringsAsFactors = FALSE
  )
}

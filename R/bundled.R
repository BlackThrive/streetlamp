# Bundled reference tables ----------------------------------------------------
#
# Small curated tables shipped in inst/extdata and built by the scripts in
# data-raw/. They are read lazily, once per session, into the package
# environment `the`.

lamp_extdata <- function(file, call = rlang::caller_env()) {
  path <- system.file("extdata", file, package = "streetlamp")
  if (!nzchar(path)) {
    lamp_abort(
      "Bundled file {.file {file}} is missing from the installed package.",
      "bundled",
      call = call
    )
  }
  path
}

lamp_bundled <- function(name, reader) {
  key <- paste0("bundled_", name)
  if (is.null(the[[key]])) {
    the[[key]] <- reader()
  }
  the[[key]]
}

# Read a bundled CSV with every column as character, then convert the named
# date and logical columns. Base R keeps the bundled tables free of heavy
# imports and fast to load in examples.
lamp_read_bundled_csv <- function(file, date_cols = character(),
                                  logical_cols = character()) {
  x <- utils::read.csv(
    lamp_extdata(file),
    colClasses = "character",
    na.strings = c("", "NA"),
    encoding = "UTF-8",
    stringsAsFactors = FALSE
  )
  for (col in date_cols) {
    x[[col]] <- as.Date(x[[col]])
  }
  for (col in logical_cols) {
    x[[col]] <- as.logical(x[[col]])
  }
  tibble::as_tibble(x)
}

#' National policy shocks affecting stop and search or recorded crime
#'
#' A curated table of dated national events for use as default intervention
#' definitions in `lamp_treatment()`: the Best Use of Stop and Search Scheme,
#' the 2019 and later changes to Section 60 authorisation conditions, COVID-19
#' lockdown periods, changes to crime recording practice, and other verified
#' policy changes. Every row carries the source that establishes its dates; see
#' `inst/NOTES/data_sources.md` in the package sources for the verification
#' record.
#'
#' @return A tibble with columns `name` (identifier), `label`, `kind`
#'   (`stop_search_policy`, `crime_policy`, `covid`, `recording_practice` or
#'   `disorder`), `start` and `end` (`Date`; `end` is `NA` for point events
#'   or regimes still in force), `scope` (`national`, `england`, `wales` or
#'   `forces`), `forces` (semicolon-separated police.uk force identifiers when
#'   `scope` is `forces`, otherwise `NA`), `source_url`, `notes` and
#'   `verified` (`Date` the source was checked).
#' @family bundled data
#' @export
#' @examples
#' shocks <- lamp_shocks()
#' shocks[shocks$kind == "stop_search_policy", c("name", "start", "end")]
lamp_shocks <- function() {
  lamp_bundled("shocks", function() {
    lamp_read_bundled_csv(
      "shocks.csv",
      date_cols = c("start", "end", "verified")
    )
  })
}

#' Bank holidays in England and Wales
#'
#' Bank and public holidays in England and Wales from 2010 onwards, for
#' seasonality controls. Rows from 2012 onwards are taken verbatim from the
#' GOV.UK bank holidays feed (the current feed for 2019 onwards and archived
#' copies of the same feed for 2012 to 2018); 2010 and 2011 are transcribed
#' from the archived Directgov bank holidays page. Apostrophes are normalised
#' to ASCII.
#'
#' @return A tibble with columns `date` (`Date`), `title`, `notes` (for
#'   example `Substitute day`), `bunting` (logical, as published; `NA` for the
#'   transcribed 2010 and 2011 rows), `source` and `source_url`.
#' @family bundled data
#' @export
#' @examples
#' bh <- lamp_bank_holidays()
#' range(bh$date)
#' bh[format(bh$date, "%Y") == "2023", c("date", "title")]
lamp_bank_holidays <- function() {
  lamp_bundled("bank_holidays", function() {
    lamp_read_bundled_csv(
      "bank_holidays.csv",
      date_cols = "date",
      logical_cols = "bunting"
    )
  })
}

#' ONS LSOA code lists and the 2011 to 2021 lookup
#'
#' The Office for National Statistics lookup between 2011 and 2021 Lower layer
#' Super Output Areas (LSOAs) in England and Wales, with the ONS change
#' indicator, the 2022 local authority district, and a flag marking the single
#' 2021 LSOA that the ONS best-fit lookup assigns to each 2011 LSOA.
#' `lamp_lsoa_codes()` returns the complete code list for either vintage,
#' which is what `lamp_lsoa_vintage()` matches against.
#'
#' @details
#' `lamp_lsoa_lookup()` is the ONS exact-fit lookup (version 3): one row per
#' 2011 to 2021 pair, so a 2011 LSOA that was split appears on several rows
#' and a merged 2021 LSOA appears on several rows. `change` is the ONS change
#' indicator: `U` unchanged, `S` split, `M` merged, `X` complex. `best_fit`
#' is `TRUE` on the row chosen by the ONS best-fit lookup (version 2), which
#' assigns every 2011 LSOA to exactly one 2021 LSOA; re-vintaging counts with
#' the `best_fit` rows is deterministic but leaves the 2021 LSOAs that no
#' 2011 LSOA best-fits to without data.
#'
#' Source: Office for National Statistics licensed under the Open Government
#' Licence v3.0. Retrieved 2026-09-16; see `inst/NOTES/data_sources.md`.
#'
#' @param vintage Which code list: `"lsoa21"` (default) or `"lsoa11"`.
#'
#' @return `lamp_lsoa_lookup()` returns a tibble with columns `lsoa11`,
#'   `lsoa11_name`, `lsoa21`, `lsoa21_name`, `change` (factor), `lad22`,
#'   `lad22_name` and `best_fit`. `lamp_lsoa_codes()` returns a sorted
#'   character vector of codes.
#' @family bundled data
#' @export
#' @examples
#' length(lamp_lsoa_codes("lsoa21"))
#' length(lamp_lsoa_codes("lsoa11"))
#' table(lamp_lsoa_lookup()$change)
lamp_lsoa_lookup <- function() {
  lamp_bundled("lsoa_lookup", function() {
    tibble::as_tibble(readRDS(lamp_extdata("lsoa_lookup.rds")))
  })
}

#' @rdname lamp_lsoa_lookup
#' @export
lamp_lsoa_codes <- function(vintage = c("lsoa21", "lsoa11")) {
  vintage <- rlang::arg_match(vintage)
  lamp_bundled(paste0("codes_", vintage), function() {
    sort(unique(lamp_lsoa_lookup()[[vintage]]))
  })
}

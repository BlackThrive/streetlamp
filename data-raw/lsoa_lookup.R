# Build inst/extdata/lsoa_lookup.rds from ONS Open Geography Portal tables.
#
# Run manually with network access from the package root; never at build,
# check or test time. Downloads are cached in data-raw/downloads/ (ignored by
# git). Verified 2026-09-16; see inst/NOTES/data_sources.md.
#
# Sources (ONS Geography, ArcGIS Online org ESMARspQHYMw9BZ9; Open Government
# Licence v3.0):
#   exact_fit  LSOA (2011) to LSOA (2021) to LAD (2022) Exact Fit Lookup for
#              EW (V3), item cbfe64cc03d74af982c1afec639bafd1. Has CHGIND.
#   best_fit   LSOA (2011) to LSOA (2021) to LAD (2022) Best Fit Lookup for EW
#              (V2), item b684a0dbf786473f9563ec0616da2f8b. One row per 2011
#              LSOA. The Hub CSV download returned 404 at verification, so the
#              table is paged from the FeatureServer.
#   nc21       Lower layer Super Output Areas (December 2021) Names and Codes
#              in EW (V3), item 0f80c523f3cd4d0fab5111572f84a2fb.
#   nc11       Lower layer Super Output Areas (December 2011) Names and Codes
#              in EW, item a5b7042782fe4ee99b8477ddf7bfe585.

dl_dir <- file.path("data-raw", "downloads")
dir.create(dl_dir, showWarnings = FALSE, recursive = TRUE)

hub_csv <- function(item, dest) {
  if (file.exists(dest)) {
    return(dest)
  }
  url <- sprintf(
    paste0(
      "https://hub.arcgis.com/api/v3/datasets/%s_0/downloads/data",
      "?format=csv&spatialRefId=4326&where=1%%3D1"
    ),
    item
  )
  for (i in seq_len(10)) {
    resp <- httr2::request(url) |>
      httr2::req_user_agent("streetlamp data-raw (https://github.com/Mustapha-Wasseja/streetlamp)") |>
      httr2::req_error(is_error = function(resp) FALSE) |>
      httr2::req_perform()
    if (httr2::resp_status(resp) == 200L) {
      writeBin(httr2::resp_body_raw(resp), dest)
      return(dest)
    }
    message("Hub responded ", httr2::resp_status(resp), "; retrying in 15 s")
    Sys.sleep(15)
  }
  stop("Could not download item ", item)
}

feature_server_csv <- function(service, dest, page = 1000L) {
  if (file.exists(dest)) {
    return(dest)
  }
  base <- sprintf(
    "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/%s/FeatureServer/0/query",
    service
  )
  offset <- 0L
  pages <- list()
  repeat {
    resp <- httr2::request(base) |>
      httr2::req_url_query(
        where = "1=1", outFields = "*", returnGeometry = "false",
        orderByFields = "ObjectId", resultOffset = offset,
        resultRecordCount = page, f = "json"
      ) |>
      httr2::req_perform()
    js <- jsonlite::fromJSON(httr2::resp_body_string(resp))
    feats <- js$features$attributes
    if (is.null(feats) || nrow(feats) == 0L) break
    pages[[length(pages) + 1L]] <- feats
    offset <- offset + nrow(feats)
    if (nrow(feats) < page) break
  }
  out <- do.call(rbind, pages)
  out$ObjectId <- NULL
  readr::write_csv(out, dest, na = "")
  dest
}

exact_path <- hub_csv(
  "cbfe64cc03d74af982c1afec639bafd1",
  file.path(dl_dir, "lsoa11_lsoa21_lad22_exact_fit_v3.csv")
)
best_path <- feature_server_csv(
  "LSOA11_LSOA21_LAD22_EW_LU_v2",
  file.path(dl_dir, "lsoa11_lsoa21_lad22_best_fit_v2.csv")
)
nc21_path <- hub_csv(
  "0f80c523f3cd4d0fab5111572f84a2fb",
  file.path(dl_dir, "lsoa_2021_names_codes_v3.csv")
)
nc11_path <- hub_csv(
  "a5b7042782fe4ee99b8477ddf7bfe585",
  file.path(dl_dir, "lsoa_2011_names_codes.csv")
)

read_chr <- function(path) {
  x <- readr::read_csv(path,
    col_types = readr::cols(.default = "c"),
    progress = FALSE
  )
  names(x) <- toupper(names(x))
  x
}

exact <- read_chr(exact_path)
best <- read_chr(best_path)
nc21 <- read_chr(nc21_path)
nc11 <- read_chr(nc11_path)

lookup <- data.frame(
  lsoa11 = exact$LSOA11CD,
  lsoa11_name = exact$LSOA11NM,
  lsoa21 = exact$LSOA21CD,
  lsoa21_name = exact$LSOA21NM,
  change = factor(exact$CHGIND, levels = c("U", "S", "M", "X")),
  lad22 = exact$LAD22CD,
  lad22_name = exact$LAD22NM,
  stringsAsFactors = FALSE
)
lookup <- lookup[order(lookup$lsoa11, lookup$lsoa21), ]
rownames(lookup) <- NULL

best_pairs <- paste(best$LSOA11CD, best$LSOA21CD)
lookup$best_fit <- paste(lookup$lsoa11, lookup$lsoa21) %in% best_pairs

# Validation ---------------------------------------------------------------
stopifnot(
  !anyNA(lookup$change),
  length(unique(lookup$lsoa11)) == 34753L,
  length(unique(lookup$lsoa21)) == 35672L,
  setequal(unique(lookup$lsoa11), nc11$LSOA11CD),
  setequal(unique(lookup$lsoa21), nc21$LSOA21CD),
  nrow(best) == 34753L,
  all(grepl("^[EW]01[0-9]{6}$", lookup$lsoa11)),
  all(grepl("^[EW]01[0-9]{6}$", lookup$lsoa21))
)
bf_per_11 <- tapply(lookup$best_fit, lookup$lsoa11, sum)
missing_bf <- names(bf_per_11)[bf_per_11 == 0L]
if (length(missing_bf) > 0L) {
  # Best-fit targets that are not exact-fit pairs: report and keep as
  # additional rows flagged best_fit with change "X" is NOT done; instead we
  # record them so the decision can be reviewed.
  message(
    length(missing_bf), " LSOA11 codes have a best-fit target outside ",
    "their exact-fit rows; see data_sources.md"
  )
  print(best[best$LSOA11CD %in% missing_bf, c("LSOA11CD", "LSOA21CD")])
}
stopifnot(all(bf_per_11 <= 1L))
print(table(lookup$change))
cat("rows:", nrow(lookup), " best_fit rows:", sum(lookup$best_fit), "\n")

dir.create(file.path("inst", "extdata"), showWarnings = FALSE, recursive = TRUE)
saveRDS(lookup, file.path("inst", "extdata", "lsoa_lookup.rds"), compress = "xz")
cat(
  "written inst/extdata/lsoa_lookup.rds:",
  file.size(file.path("inst", "extdata", "lsoa_lookup.rds")), "bytes\n"
)

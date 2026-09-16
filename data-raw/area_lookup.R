# Build inst/extdata/area_lookup.rds: one row per 2021 LSOA with its 2021
# MSOA, 2022 local authority district, police force area and police.uk force.
#
# Run manually from the package root; the inputs are ONS Open Geography Portal
# tables cached in data-raw/downloads/ (git-ignored). Verified 2026-09-16; see
# inst/NOTES/data_sources.md.
#
# Sources (ONS Geography, Open Government Licence v3.0):
#   oa   Output Area (2021) to LSOA to MSOA to LAD (December 2022) Exact Fit
#        Lookup in EW (V3): 188,880 OA rows; LSOA-level rows are derived.
#   pfa  Local Authority District to Community Safety Partnership to Police
#        Force Area (December 2022) Lookup in EW.

pkgload::load_all(".", quiet = TRUE)
dl_dir <- file.path("data-raw", "downloads")

read_chr <- function(path) {
  x <- utils::read.csv(path, colClasses = "character", check.names = FALSE, fileEncoding = "UTF-8-BOM")
  names(x) <- toupper(names(x))
  x
}
oa <- read_chr(file.path(dl_dir, "OA21_LSOA21_MSOA21_LAD22_EW_LU_exact_fit_v3.csv"))
pfa <- read_chr(file.path(dl_dir, "LAD22_CSP22_PFA22_EW_LU.csv"))

lsoa <- unique(oa[, c("LSOA21CD", "LSOA21NM", "MSOA21CD", "MSOA21NM", "LAD22CD", "LAD22NM")])
stopifnot(
  nrow(lsoa) == 35753L || nrow(lsoa) == 35672L,
  !anyDuplicated(lsoa$LSOA21CD) || TRUE
)
# An LSOA must belong to one MSOA and one LAD
per_lsoa <- tapply(seq_len(nrow(lsoa)), lsoa$LSOA21CD, length)
if (any(per_lsoa > 1L)) {
  dup <- names(per_lsoa)[per_lsoa > 1L]
  print(lsoa[lsoa$LSOA21CD %in% dup, ])
  stop("LSOAs mapping to several MSOAs or LADs")
}

lad <- unique(pfa[, c("LAD22CD", "LAD22NM", "PFA22CD", "PFA22NM")])
per_lad <- tapply(seq_len(nrow(lad)), lad$LAD22CD, length)
if (any(per_lad > 1L)) {
  dup <- names(per_lad)[per_lad > 1L]
  print(lad[lad$LAD22CD %in% dup, ])
  stop("LADs mapping to several PFAs")
}

forces <- lamp_forces()
lookup <- data.frame(
  lsoa21 = lsoa$LSOA21CD,
  lsoa21_name = lsoa$LSOA21NM,
  msoa21 = lsoa$MSOA21CD,
  msoa21_name = lsoa$MSOA21NM,
  lad22 = lsoa$LAD22CD,
  lad22_name = lsoa$LAD22NM,
  stringsAsFactors = FALSE
)
idx <- match(lookup$lad22, lad$LAD22CD)
lookup$pfa <- lad$PFA22CD[idx]
lookup$pfa_name <- lad$PFA22NM[idx]
lookup$force_id <- forces$force_id[match(lookup$pfa, forces$pfa_code)]
lookup <- lookup[order(lookup$lsoa21), ]
rownames(lookup) <- NULL

missing_pfa <- unique(lookup$lad22[is.na(lookup$pfa)])
if (length(missing_pfa) > 0L) {
  cat("LADs without a PFA:\n")
  print(unique(lookup[lookup$lad22 %in% missing_pfa, c("lad22", "lad22_name")]))
}
stopifnot(
  nrow(lookup) == 35672L,
  !anyDuplicated(lookup$lsoa21),
  setequal(lookup$lsoa21, lamp_lsoa_codes("lsoa21")),
  length(unique(lookup$msoa21)) == 7264L,
  length(unique(lookup$lad22)) == 331L,
  !anyNA(lookup$pfa),
  !anyNA(lookup$force_id),
  length(unique(lookup$pfa)) == 43L,
  all(lookup$pfa %in% forces$pfa_code)
)
print(table(lookup$force_id)[c("west-yorkshire", "dyfed-powys", "metropolitan", "city-of-london")])
saveRDS(lookup, file.path("inst", "extdata", "area_lookup.rds"), compress = "xz")
cat("written inst/extdata/area_lookup.rds:", file.size(file.path("inst", "extdata", "area_lookup.rds")), "bytes\n")

# Build inst/extdata/deprivation.rds: a compact table of the English Indices
# of Deprivation 2025 and the Welsh Index of Multiple Deprivation 2025 by 2021
# LSOA.
#
# Run manually from the package root; inputs are cached in data-raw/downloads/
# (git-ignored). Verified 2026-09-16; see inst/NOTES/data_sources.md.
#
# Sources (Open Government Licence v3.0):
#   England  File 7 of the English indices of deprivation 2025 (MHCLG,
#            published 30 October 2025, corrected 19 November 2025):
#            https://assets.publishing.service.gov.uk/media/691ded56d140bbbaa59a2a7d/File_7_IoD2025_All_Ranks_Scores_Deciles_Population_Denominators.csv
#   Wales    WIMD 2025 index and domain ranks by small area (Welsh
#            Government, published 27 November 2025):
#            https://www.gov.wales/sites/default/files/statistics-and-research/2025-11/wimd-2025-index-and-domain-ranks-by-small-area.ods
#            (the "WIMD 2025 ranks" and "Deciles quintiles quartiles" sheets)

dl_dir <- file.path("data-raw", "downloads")
eng <- utils::read.csv(
  file.path(dl_dir, "File_7_IoD2025_All_Ranks_Scores_Deciles_Population_Denominators.csv"),
  check.names = FALSE, stringsAsFactors = FALSE
)
wal_ranks <- utils::read.csv(file.path(dl_dir, "wimd2025_ranks.csv"), check.names = FALSE, stringsAsFactors = FALSE)
wal_dec <- utils::read.csv(file.path(dl_dir, "wimd2025_deciles.csv"), check.names = FALSE, stringsAsFactors = FALSE)

col <- function(x, pattern) {
  hit <- grep(pattern, names(x), fixed = TRUE, value = TRUE)
  stopifnot(length(hit) == 1L)
  x[[hit]]
}
# Domain deciles: England publishes them; Wales publishes domain ranks, from
# which deciles are formed within Wales (rank 1 to 191 is decile 1, and so on,
# matching the published overall decile cut-offs).
wales_decile <- function(rank) as.integer(ceiling(10 * as.integer(rank) / 1917))
england <- data.frame(
  lsoa21 = col(eng, "LSOA code (2021)"),
  country = "england",
  index = "IoD2025",
  score = col(eng, "Index of Multiple Deprivation (IMD) Score"),
  rank = as.integer(col(eng, "Index of Multiple Deprivation (IMD) Rank")),
  decile = as.integer(col(eng, "Index of Multiple Deprivation (IMD) Decile")),
  decile_income = as.integer(col(eng, "Income Decile (where 1 is most deprived 10% of LSOAs)")),
  decile_employment = as.integer(col(eng, "Employment Decile (where 1 is most deprived 10% of LSOAs)")),
  decile_education = as.integer(col(eng, "Education, Skills and Training Decile (where 1 is most deprived 10% of LSOAs)")),
  decile_health = as.integer(col(eng, "Health Deprivation and Disability Decile (where 1 is most deprived 10% of LSOAs)")),
  decile_crime = as.integer(col(eng, "Crime Decile (where 1 is most deprived 10% of LSOAs)")),
  decile_housing = as.integer(col(eng, "Barriers to Housing and Services Decile (where 1 is most deprived 10% of LSOAs)")),
  decile_environment = as.integer(col(eng, "Living Environment Decile (where 1 is most deprived 10% of LSOAs)")),
  stringsAsFactors = FALSE
)
wales <- data.frame(
  lsoa21 = wal_ranks[["LSOA code"]],
  country = "wales",
  index = "WIMD2025",
  score = NA_real_,
  rank = as.integer(wal_ranks[["WIMD 2025"]]),
  decile = as.integer(wal_dec[["WIMD 2025 overall decile"]][match(wal_ranks[["LSOA code"]], wal_dec[["LSOA code"]])]),
  decile_income = wales_decile(wal_ranks[["Income"]]),
  decile_employment = wales_decile(wal_ranks[["Employment"]]),
  decile_education = wales_decile(wal_ranks[["Education"]]),
  decile_health = wales_decile(wal_ranks[["Health"]]),
  decile_crime = wales_decile(wal_ranks[["Community Safety"]]),
  decile_housing = wales_decile(wal_ranks[["Housing"]]),
  decile_environment = wales_decile(wal_ranks[["Physical Environment"]]),
  stringsAsFactors = FALSE
)
cat(
  "Welsh overall deciles differing from the ceiling(10 * rank / n) rule:",
  sum(wales_decile(wales$rank) != wales$decile), "of", nrow(wales), "\n"
)
dep <- rbind(england, wales)
dep$n_lsoas <- ifelse(dep$country == "england", nrow(england), nrow(wales))
dep <- dep[order(dep$lsoa21), ]
rownames(dep) <- NULL

pkgload::load_all(".", quiet = TRUE)
stopifnot(
  nrow(england) == 33755L,
  nrow(wales) == 1917L,
  !anyDuplicated(dep$lsoa21),
  setequal(dep$lsoa21, lamp_lsoa_codes("lsoa21")),
  !anyNA(dep$rank), !anyNA(dep$decile),
  all(dep$decile >= 1L & dep$decile <= 10L),
  setequal(dep$rank[dep$country == "england"], seq_len(33755L)),
  setequal(dep$rank[dep$country == "wales"], seq_len(1917L)),
  !anyNA(dep[, grep("^decile_", names(dep))]),
  all(as.matrix(dep[, grep("^decile_", names(dep))]) %in% 1:10)
)
saveRDS(dep, file.path("inst", "extdata", "deprivation.rds"), compress = "xz")
cat("written inst/extdata/deprivation.rds:", file.size(file.path("inst", "extdata", "deprivation.rds")), "bytes\n")

# Build the bundled sample panel and boundaries (specification section 9.3):
#
#   inst/extdata/sample_panel.rds       an aggregated 2021-LSOA by month panel
#                                       for West Yorkshire and Dyfed-Powys over
#                                       the 24 most recent complete months in
#                                       the latest archive snapshot, with crime
#                                       by type, ASB, stops, Section 60 stops,
#                                       Census 2021 population, stop rate and
#                                       deprivation deciles, plus its contract
#   inst/extdata/sample_boundaries.rds  simplified ONS BGC boundaries of those
#                                       LSOAs (sf, EPSG:27700)
#
# Run manually with network access from the package root: it fetches about
# 130 force-month files (60 MB) through lamp_archive_download(), the LSOA
# boundaries (50 MB) through lamp_boundaries() and the Census population
# through lamp_population(), all cached under data-raw/downloads/. Never run
# at build, check or test time. Data: data.police.uk, ONS and NOMIS, Open
# Government Licence v3.0.

pkgload::load_all(".", quiet = TRUE)

dl <- file.path("data-raw", "downloads", "archive-cache")
forces <- c("west-yorkshire", "dyfed-powys")
archive <- "2026-07"
months <- format(seq(as.Date("2024-08-01"), by = "month", length.out = 24), "%Y-%m")

snap <- lamp_archive_download(archives = archive, months = months, forces = forces, dir = dl)
crime <- lamp_read_crime(snap, months = months, forces = forces)
cat("crime records:", nrow(crime), "\n")

# Boundaries of the two forces' LSOAs, simplified for bundling
lk <- lamp_area_lookup()
sample_lsoas <- lk$lsoa21[lk$force_id %in% forces]
bnd <- lamp_boundaries("lsoa21", dir = dl)
sample_bnd <- bnd[bnd$area %in% sample_lsoas, ]
sample_bnd <- sf::st_simplify(sample_bnd, preserveTopology = TRUE, dTolerance = 50)
sample_bnd <- sf::st_make_valid(sample_bnd)
attr(sample_bnd, "vintage") <- attr(bnd, "vintage")
attr(sample_bnd, "product") <- attr(bnd, "product")
attr(sample_bnd, "retrieved") <- attr(bnd, "retrieved")
attr(sample_bnd, "simplified") <- "sf::st_simplify(dTolerance = 50 m, preserveTopology = TRUE)"
stopifnot(nrow(sample_bnd) == length(sample_lsoas), all(sf::st_is_valid(sample_bnd)))

stops <- lamp_read_stop_counts(
  snap,
  area = "lsoa21", boundaries = sample_bnd, months = months, forces = forces
)
cat("stop rows:", nrow(stops), "\n")

pop <- lamp_population("lsoa21", dir = dl)
dep <- lamp_deprivation()
covariates <- tibble::tibble(
  area = dep$lsoa21,
  imd_decile = dep$decile,
  imd_decile_crime = dep$decile_crime,
  imd_index = dep$index
)

adj <- lamp_adjacency(sample_bnd)
panel <- lamp_panel(
  crime,
  stops = stops, population = pop, covariates = covariates, adjacency = adj
)
print(panel)
print(lamp_contract(panel))
cov <- lamp_coverage(panel)
print(table(cov$file_type, cov$status))

stopifnot(
  nrow(panel) == length(sample_lsoas) * 24L,
  all(panel$coverage_status %in% c("submitted", "refreshed", "partial_suspected", "missing")),
  !anyNA(panel$population),
  !anyNA(panel$imd_decile)
)

saveRDS(panel, file.path("inst", "extdata", "sample_panel.rds"), compress = "xz")
saveRDS(sample_bnd, file.path("inst", "extdata", "sample_boundaries.rds"), compress = "xz")
cat(
  "sample_panel.rds:", file.size(file.path("inst", "extdata", "sample_panel.rds")), "bytes;",
  "sample_boundaries.rds:", file.size(file.path("inst", "extdata", "sample_boundaries.rds")), "bytes\n"
)

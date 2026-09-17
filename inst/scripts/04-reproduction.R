# Validation 4: a fixed specification that must reproduce exactly
#
# Builds a London panel from the archive and estimates a stop-crime elasticity
# by offence type under one exact specification, stored as a fixture. Re-running
# must reproduce it to the last digit; if it does not, either the package has
# changed behaviour or the archive has revised the months, and the difference
# is printed.
#
# This is the package's own specification. It is not a replication of any
# published study, and it is not evidence about the effect of stop and search
# in London: it exists so that a change in results can be traced to a cause.
#
#   Rscript inst/scripts/04-reproduction.R

suppressMessages(library(streetlamp))

out_dir <- file.path("inst", "validation")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
fixture <- file.path(out_dir, "reproduction-london.csv")
cache <- file.path("data-raw", "downloads", "reproduction-cache")

# The specification, fixed. Changing anything here makes a new fixture.
spec <- list(
  archive = "2026-07",
  forces = c("metropolitan", "city-of-london"),
  months = format(seq(as.Date("2024-08-01"), by = "month", length.out = 24), "%Y-%m"),
  area = "lad",
  lags = 0:3,
  method = "fe",
  cluster = "area",
  outcomes = c(
    "crime_total", "violence_and_sexual_offences", "robbery",
    "possession_of_weapons", "drugs", "burglary", "bicycle_theft"
  )
)
message("Specification:")
utils::str(spec)

snap <- lamp_archive_download(
  archives = spec$archive, months = spec$months, forces = spec$forces, dir = cache
)
crime <- lamp_read_crime(snap, months = spec$months, forces = spec$forces)
boundaries <- lamp_boundaries("lad", dir = cache)
stops <- lamp_read_stop_counts(
  snap,
  area = "lad", boundaries = boundaries, months = spec$months, forces = spec$forces
)
population <- lamp_population("lad", dir = cache)
panel <- lamp_panel(crime, stops = stops, population = population, area = spec$area)

message(sprintf(
  "Panel: %d areas, %d months, %d rows.",
  length(unique(panel$area)), length(unique(panel$month)), nrow(panel)
))
cov <- lamp_coverage(panel)
print(table(cov$file_type, cov$status))

rows <- list()
for (outcome in spec$outcomes) {
  fit <- lamp_elasticity(
    panel, outcome,
    lags = spec$lags, method = spec$method, cluster = spec$cluster
  )
  lr <- fit$diagnostics$long_run
  cd <- fit$diagnostics$cd_test
  rows[[length(rows) + 1L]] <- tibble::tibble(
    outcome = outcome,
    elasticity = round(lr$estimate, 6),
    std_error = round(lr$std_error, 6),
    conf_low = round(lr$conf_low, 6),
    conf_high = round(lr$conf_high, 6),
    cd_statistic = round(cd$statistic, 4),
    n_rows = fit$sample$n_rows[nrow(fit$sample)],
    n_areas = fit$sample$n_areas[nrow(fit$sample)]
  )
}
current <- dplyr::bind_rows(rows)
allocation <- lamp_allocation(panel, crime_lags = 1:3)
message("\nAllocation model, which must be read alongside every row above:")
message(allocation$diagnostics$interpretation)

if (file.exists(fixture)) {
  stored <- utils::read.csv(fixture, stringsAsFactors = FALSE)
  common <- intersect(names(stored), names(current))
  same <- isTRUE(all.equal(
    stored[order(stored$outcome), common],
    as.data.frame(current)[order(current$outcome), common],
    tolerance = 0
  ))
  if (same) {
    message("\nReproduced the stored fixture exactly.")
  } else {
    message("\nDIFFERS from the stored fixture:")
    print(merge(
      stored[, c("outcome", "elasticity")], current[, c("outcome", "elasticity")],
      by = "outcome", suffixes = c("_stored", "_now")
    ))
    message(
      "Either the package changed behaviour, or the archive revised these ",
      "months. Check the archive versions in the panel contract before ",
      "overwriting the fixture."
    )
  }
} else {
  utils::write.csv(current, fixture, row.names = FALSE)
  message("\nWrote the fixture to ", fixture)
}
print(as.data.frame(current), digits = 4)

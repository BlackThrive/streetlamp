# Audited association case study, using already cached source files only.
# Rscript inst/scripts/06-london-robustness.R
# The panel cache remains outside the repository; outputs contain no microdata.
suppressMessages(devtools::load_all(quiet = TRUE))
fixest::setFixest_nthreads(1)
Sys.setenv(STREETLAMP_OFFLINE = "true")
source(file.path("inst", "scripts", "_cache.R"))
cache <- lamp_validation_cache("reproduction")
out_dir <- file.path("inst", "validation", "research-upgrade")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
months <- format(seq(as.Date("2024-08-01"), by = "month", length.out = 24), "%Y-%m")
forces <- c("metropolitan", "city-of-london")
snap <- lamp_archive_snapshot(cache)
members <- snap$members[snap$members$archive == "2026-07" &
  format(snap$members$month, "%Y-%m") %in% months & snap$members$force_id %in% forces &
  snap$members$file_type %in% c("street", "stop-and-search"), ]
stopifnot(nrow(members) > 0L, all(members$available), all(!is.na(members$sha256)))
message("Verifying hashes of ", nrow(members), " cached force-month files; ",
        96L - nrow(members), " requested files absent from this archive")
hashes <- vapply(members$path, digest::digest, character(1), algo = "sha256", file = TRUE)
stopifnot(all(hashes == members$sha256))
manifest <- members[, c("archive", "member", "month", "force_id", "file_type", "crc32", "sha256")]
utils::write.csv(manifest, file.path(out_dir, "london-source-manifest.csv"), row.names = FALSE)
panel_path <- file.path(cache, "london-panel-2026-07-research.rds")
fingerprint <- digest::digest(manifest, algo = "sha256")
cached <- if (file.exists(panel_path)) readRDS(panel_path) else NULL
if (!is.null(cached) && identical(cached$fingerprint, fingerprint)) {
  panel <- cached$panel
} else {
  message("Building London panel from cached crime and stop files")
  crime <- lamp_read_crime(snap, months = months, forces = forces, fetch = FALSE)
  boundaries <- lamp_boundaries("lad", dir = cache)
  stops <- lamp_read_stop_counts(snap, area = "lad", boundaries = boundaries,
                                 months = months, forces = forces, fetch = FALSE)
  population <- lamp_population("lad", dir = cache)
  panel <- lamp_panel(crime, stops = stops, population = population, area = "lad")
  saveRDS(list(fingerprint = fingerprint, panel = panel), panel_path)
}
outcomes <- c("crime_total", "violence_and_sexual_offences", "robbery", "possession_of_weapons",
              "drugs", "burglary", "bicycle_theft")
audit <- lamp_design_audit(panel, outcomes = outcomes)
utils::write.csv(audit$issues, file.path(out_dir, "london-design-audit.csv"), row.names = FALSE)
utils::write.csv(as.data.frame(lamp_coverage(panel)), file.path(out_dir, "london-coverage.csv"), row.names = FALSE)
message("Running the complete outcome / lag / response-scale grid")
grid <- lamp_elasticity_robustness(panel, outcomes = outcomes)
utils::write.csv(grid, file.path(out_dir, "london-specifications.csv"), row.names = FALSE)
message("Running leave-one-borough-out checks for the primary count specification")
loo <- lamp_elasticity_robustness(panel, lags = list(distributed = 0:3), families = "poisson", leave_one_out = TRUE)
utils::write.csv(loo, file.path(out_dir, "london-leave-one-out.csv"), row.names = FALSE)

primary <- lamp_elasticity(panel, "crime_total", lags = 0:3, family = "poisson")
bike <- lamp_elasticity(panel, "bicycle_theft", lags = 0:3, family = "poisson")
allocation <- lamp_allocation(panel, crime_lags = 1:3)
# A future-exposure diagnostic is retained even if it contradicts the main
# association. It is not a causal placebo test: deployment may anticipate crime.
d <- streetlamp:::lamp_model_frame(panel, "crime_total", "stops")$data
d$.log_s <- log1p(d$stops)
lagm <- streetlamp:::lamp_lag_matrix(d, ".log_s", c(0:3, -1))
terms <- colnames(lagm)
for (j in seq_along(terms)) d[[terms[j]]] <- lagm[, j]
lead_name <- "future_log_stops"
names(d)[names(d) == ".log_s_lag-1"] <- lead_name
terms[terms == ".log_s_lag-1"] <- lead_name
d <- d[stats::complete.cases(d[, terms]), ]
lead_fit <- fixest::fepois(stats::as.formula(paste("crime_total ~", paste(terms, collapse = " + "),
                                                               "| .area + .month")),
                         data = d, cluster = ~.cluster, notes = FALSE)
lead_co <- streetlamp:::lamp_coefficients(lead_fit)
lead_co <- lead_co[lead_co$term == lead_name, ]
utils::write.csv(lead_co, file.path(out_dir, "london-future-exposure.csv"), row.names = FALSE)
lamp_report(panel, list("Primary: total recorded crime, PPML" = primary,
                         "Comparison outcome: bicycle theft, PPML" = bike,
                         "Reverse allocation channel" = allocation),
            file = file.path(out_dir, "london-report.md"), figures = FALSE, diagnostics = FALSE,
            title = "London: audited stop-crime associations, not an intervention effect", quiet = TRUE)
notes <- c("# London case-study interpretation", "",
  "This is an association study with area and month fixed effects. No independently assigned intervention is identified.",
  "The seven outcomes, three lag windows and two response families were specified together; every result and failure is retained.",
  "The primary specification is total recorded crime, PPML, lags 0 to 3, borough clustering. The two London forces are too few force clusters for routine asymptotic inference.",
  "Bicycle theft is a comparison outcome, not a proven unaffected negative control. Searching, crime recording, deployment and unobserved local changes can affect several outcomes together.",
  "Drugs and weapons possession are detection-sensitive. A rise in their recorded counts can reflect more detection.",
  "The future-search coefficient probes timing and reverse allocation; neither its significance nor non-significance establishes exogeneity.",
  "Leave-one-borough-out results assess concentration of the association. They cannot resolve confounding or displacement.",
  "The source CSVs were checked against cached SHA-256 hashes. Population is a fixed 2021 census reference, not contemporaneous exposure; it is not used as an offset in these count models.", "",
  paste("Panel:", nrow(panel), "rows;", length(unique(panel$area)), "areas;", length(unique(panel$month)), "months."),
  paste("Grid failures:", sum(grid$status == "failed"), "of", nrow(grid)),
  paste("Leave-one-out failures:", sum(loo$status == "failed"), "of", nrow(loo)), "",
  "A causal article case requires independently documented rollout and assignment, longer pre-period support, appropriate comparison areas, and evidence on recording changes and co-interventions.")
writeLines(notes, file.path(out_dir, "london-interpretation.md"))
print(grid[is.na(grid$omitted_area) & grid$family == "poisson" & grid$lag_specification == "distributed", ])
print(lead_co)
message(allocation$diagnostics$interpretation)

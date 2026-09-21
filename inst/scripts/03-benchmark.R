# Validation 3: benchmark
#
# How long it takes to build a national LSOA panel from the archive, and how
# much is downloaded to do it. Needs network access and roughly 2 GB of cache
# for the full national run.
#
#   Rscript inst/scripts/03-benchmark.R [n_months] [n_forces]
#
# Defaults to 36 months and every force, which is the national panel the
# specification asks about. Pass smaller numbers for a quick check.

suppressMessages(library(streetlamp))
source(file.path("inst", "scripts", "_cache.R"))

args <- commandArgs(trailingOnly = TRUE)
n_months <- if (length(args) > 0) as.integer(args[1]) else 36L
n_forces <- if (length(args) > 1) as.integer(args[2]) else NA_integer_

out_dir <- file.path("inst", "validation")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
cache <- lamp_validation_cache("benchmark")

timings <- list()
time_it <- function(label, expr) {
  t0 <- Sys.time()
  value <- force(expr)
  secs <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  message(sprintf("%-28s %8.1f s", label, secs))
  timings[[label]] <<- secs
  value
}

idx <- time_it("archive index", lamp_archive_index(dir = cache))
archive <- idx$archive[which.max(idx$to)]
months <- format(seq(idx$to[which.max(idx$to)], by = "-1 month", length.out = n_months), "%Y-%m")

forces <- lamp_forces()$force_id
if (!is.na(n_forces)) forces <- utils::head(forces, n_forces)

snap <- time_it(
  "download force-months",
  lamp_archive_download(archives = archive, months = months, forces = forces, dir = cache)
)
available <- snap$members[snap$members$available, ]
# uncompressed size of the member files the panel is built from; the bytes
# that crossed the wire are smaller, because archive members are deflated
mb <- sum(available$usize, na.rm = TRUE) / 1e6
n_files <- nrow(available)
cache_mb <- sum(
  file.size(list.files(cache, recursive = TRUE, full.names = TRUE)),
  na.rm = TRUE
) / 1e6

crime <- time_it("read crime", lamp_read_crime(snap, months = months, forces = forces))
boundaries <- time_it("boundaries", lamp_boundaries("lsoa21", dir = cache))
stops <- time_it(
  "read stop counts",
  lamp_read_stop_counts(snap, area = "lsoa21", boundaries = boundaries, months = months, forces = forces)
)
population <- time_it("population", lamp_population("lsoa21", dir = cache))
adjacency <- time_it("adjacency", lamp_adjacency(boundaries))
panel <- time_it(
  "build panel",
  lamp_panel(crime, stops = stops, population = population, adjacency = adjacency)
)
coverage <- time_it("coverage audit", lamp_coverage(panel))
fit <- time_it(
  "two-way fixed effects",
  lamp_twfe(panel, "crime_total", lamp_treatment(panel, "continuous", measure = "stop_rate", transform = "ihs"))
)

result <- tibble::tibble(
  step = names(timings),
  seconds = unlist(timings),
  n_months = n_months,
  n_forces = length(forces),
  n_records = nrow(crime),
  n_areas = length(unique(panel$area)),
  n_panel_rows = nrow(panel),
  n_files = n_files,
  member_mb_uncompressed = round(mb, 1),
  cache_mb_on_disk = round(cache_mb, 1),
  r_version = R.version.string,
  run_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
)
utils::write.csv(result, file.path(out_dir, "benchmark.csv"), row.names = FALSE)
print(as.data.frame(result[, c("step", "seconds")]), digits = 3)
message(sprintf(
  paste(
    "\n%d records over %d areas and %d months, from %d archive files",
    "(%.0f MB uncompressed, %.0f MB of cache on disk); %.1f s in total."
  ),
  nrow(crime), length(unique(panel$area)), n_months, n_files, mb, cache_mb,
  sum(unlist(timings))
))
message("written ", file.path(out_dir, "benchmark.csv"))

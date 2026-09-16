# Build the bundled sample data.
#
# Part 1 (M1): two mini archive snapshots, inst/extdata/archive/2026-06.zip
# and 2026-07.zip, with the real archive layout and real records for a subset
# of LSOAs in West Yorkshire and Dyfed-Powys, May to July 2026. They are
# small enough to ship and exercise everything the readers and version
# logic must handle: a force-month present in two snapshots with different
# content (West Yorkshire May 2026 outcomes lost ten rows between the June
# and July snapshots), a force that stopped submitting stop-and-search files
# (Dyfed-Powys, from December 2025), anti-social behaviour rows without a
# Crime ID, rows without coordinates, and 2021-vintage LSOA codes.
#
# Run manually with network access from the package root (fetches about
# 40 MB through lamp_archive_download()); never at build, check or test
# time. Data: data.police.uk, Open Government Licence v3.0.

pkgload::load_all(".", quiet = TRUE)

dl <- file.path("data-raw", "downloads", "archive-cache")
forces <- c("west-yorkshire", "dyfed-powys")
months <- c("2026-05", "2026-06", "2026-07")
archives <- c("2026-06", "2026-07")

snap <- lamp_archive_download(
  archives = archives, months = months, forces = forces, dir = dl
)

# LSOA subsets: whole MSOAs so that the areas stay spatially coherent.
# LSOA names are "<MSOA name><letter>", e.g. "Leeds 100E".
wy_msoas <- c(sprintf("Leeds %03d", 100:112), "Kirklees 042")
dp_msoas <- c(sprintf("Carmarthenshire %03d", 1:12), sprintf("Pembrokeshire %03d", 1:6))
keep_msoas <- c(wy_msoas, dp_msoas)
msoa_of <- function(lsoa_name) sub("[A-Z]$", "", lsoa_name)

read_raw <- function(path) {
  utils::read.csv(path,
    colClasses = "character", na.strings = "", check.names = FALSE,
    encoding = "UTF-8", stringsAsFactors = FALSE
  )
}
write_raw <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(x, path, row.names = FALSE, na = "", quote = TRUE, fileEncoding = "UTF-8")
}

# Bounding boxes of the kept LSOAs (from street files) to subset stops.
bbox <- list()
members <- snap$members[!is.na(snap$members$file_type) & snap$members$available, ]
for (i in seq_len(nrow(members))) {
  r <- members[i, ]
  if (r$file_type != "street") next
  x <- read_raw(r$path)
  x <- x[msoa_of(x[["LSOA name"]]) %in% keep_msoas, ]
  lat <- as.numeric(x$Latitude)
  lon <- as.numeric(x$Longitude)
  b <- bbox[[r$force_id]]
  bbox[[r$force_id]] <- c(
    min(c(b[1], lon), na.rm = TRUE), max(c(b[2], lon), na.rm = TRUE),
    min(c(b[3], lat), na.rm = TRUE), max(c(b[4], lat), na.rm = TRUE)
  )
}

out_dir <- file.path("inst", "extdata", "archive")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
stage <- file.path(tempdir(), "streetlamp-sample")
unlink(stage, recursive = TRUE)

totals <- list()
for (a in archives) {
  adir <- file.path(stage, a)
  dir.create(adir, recursive = TRUE, showWarnings = FALSE)
  am <- members[members$archive == a, ]
  for (i in seq_len(nrow(am))) {
    r <- am[i, ]
    x <- read_raw(r$path)
    if (r$file_type %in% c("street", "outcomes")) {
      keep <- msoa_of(x[["LSOA name"]]) %in% keep_msoas
      # keep a few rows without a location, which have no LSOA name
      no_loc <- which(is.na(x[["LSOA code"]]))
      keep[head(no_loc, 15)] <- TRUE
      x <- x[keep, ]
    } else {
      b <- bbox[[r$force_id]]
      lat <- as.numeric(x$Latitude)
      lon <- as.numeric(x$Longitude)
      keep <- !is.na(lat) & lon >= b[1] & lon <= b[2] & lat >= b[3] & lat <= b[4]
      keep[head(which(is.na(lat)), 10)] <- TRUE
      x <- x[keep, ]
    }
    write_raw(x, file.path(adir, r$member))
    totals[[paste(a, r$member)]] <- nrow(x)
  }
  zipfile <- normalizePath(file.path(out_dir, paste0(a, ".zip")), mustWork = FALSE)
  unlink(zipfile)
  # mirror mode keeps the "YYYY-MM/" folder in member names, as the real
  # archive does; directory entries are left out because the archive has none
  month_dirs <- list.dirs(adir, full.names = FALSE, recursive = FALSE)
  zip::zip(
    zipfile,
    files = month_dirs, root = adir, mode = "mirror",
    include_directories = FALSE, compression_level = 9
  )
  files <- list.files(adir, recursive = TRUE)
  cat(sprintf("%s: %d files, %.0f KB\n", basename(zipfile), length(files), file.size(zipfile) / 1024))
}
print(unlist(totals))

# Verify the fixtures with the package itself.
check <- tempfile("streetlamp-sample-check-")
for (a in archives) lamp_archive_register(file.path(out_dir, paste0(a, ".zip")), dir = check)
s <- lamp_archive_snapshot(check)
print(s)
v <- lamp_list_versions(s)
stopifnot(any(v$n_versions == 2L), any(v$differs))
d <- lamp_version_diff(s, "west-yorkshire", "2026-05", "outcomes")
print(d)
stopifnot(length(unique(d$n_rows)) > 1L)
crime <- lamp_read_crime(s)
stopifnot(all(crime$lsoa_vintage == "lsoa21"), sum(crime$is_asb) > 0, all(is.na(crime$crime_id[crime$is_asb])))
stops <- lamp_read_stop_counts(s)
print(stops)
cat("sample built\n")

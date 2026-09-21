# Archive acquisition -----------------------------------------------------------

lamp_archive_base_url <- function() "https://data.police.uk/data/archive/"

lamp_archive_zip_url <- function(archive) {
  paste0(lamp_archive_base_url(), archive, ".zip")
}

lamp_archive_dir <- function(dir) file.path(dir, "archive")

lamp_file_types <- function() c("street", "outcomes", "stop-and-search")

lamp_month_abbreviations <- c(
  Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6, Jul = 7, Aug = 8,
  Sep = 9, Oct = 10, Nov = 11, Dec = 12
)

# "Aug 2023" -> Date 2023-08-01, without depending on the locale.
lamp_parse_month_label <- function(x) {
  parts <- strsplit(trimws(x), " ", fixed = TRUE)
  vapply(parts, function(p) {
    if (length(p) != 2L || !p[1] %in% names(lamp_month_abbreviations)) {
      return(NA_real_)
    }
    as.numeric(as.Date(sprintf("%s-%02d-01", p[2], lamp_month_abbreviations[[p[1]]])))
  }, numeric(1)) |>
    as.Date(origin = "1970-01-01")
}

# Accept "2026-05", Date, or character dates and return first-of-month Dates.
lamp_as_months <- function(x, arg = rlang::caller_arg(x), call = rlang::caller_env()) {
  if (is.null(x)) {
    return(NULL)
  }
  if (inherits(x, "Date")) {
    return(as.Date(format(x, "%Y-%m-01")))
  }
  if (is.character(x)) {
    ok <- grepl("^[0-9]{4}-[0-9]{2}(-[0-9]{2})?$", x)
    if (all(ok)) {
      return(as.Date(paste0(substr(x, 1, 7), "-01")))
    }
  }
  lamp_abort(
    "{.arg {arg}} must be Dates or strings such as {.val 2026-05}.",
    "input",
    call = call
  )
}

# The month of a date, as "YYYY-MM".
#
# This is on the hot path of every estimator: the model frame keys rows by
# area and month, and the month fixed effect is a factor of it. `format()` on
# a Date builds a POSIXlt and formats every element, which was four fifths of
# the time in `lamp_twfe()` on a 24,000 row panel and would be minutes on a
# national one. A panel has a handful of distinct months and a great many
# rows, so only the distinct values are converted.
lamp_month_id <- function(month) {
  if (!inherits(month, c("Date", "POSIXt"))) {
    return(format(month, "%Y-%m"))
  }
  u <- unique(month)
  ids <- rep(NA_character_, length(u))
  ok <- !is.na(u)
  if (any(ok)) {
    lt <- as.POSIXlt(u[ok])
    ids[ok] <- sprintf("%04d-%02d", lt$year + 1900L, lt$mon + 1L)
  }
  # matched on the underlying numbers: `match()` on Dates goes through
  # character conversion, which is the cost this function exists to avoid
  ids[match(unclass(month), unclass(u))]
}

# Number of calendar months from `from` to `to` inclusive.
lamp_months_between <- function(from, to) {
  lt_from <- as.POSIXlt(from)
  lt_to <- as.POSIXlt(to)
  as.integer(12L * (lt_to$year - lt_from$year) + (lt_to$mon - lt_from$mon) + 1L)
}

# Split archive member names into month, force and file type.
lamp_parse_members <- function(member) {
  pat <- "^([0-9]{4}-[0-9]{2})/\\1-(.+)-(street|outcomes|stop-and-search)\\.csv$"
  ok <- grepl(pat, member)
  month <- rep(as.Date(NA), length(member))
  if (any(ok)) {
    month[ok] <- as.Date(paste0(sub(pat, "\\1", member[ok]), "-01"))
  }
  force_id <- ifelse(ok, sub(pat, "\\2", member), NA_character_)
  file_type <- ifelse(ok, sub(pat, "\\3", member), NA_character_)
  tibble::tibble(month = month, force_id = force_id, file_type = file_type)
}

#' Index of the data.police.uk archive
#'
#' Lists the monthly archive snapshots published at
#' <https://data.police.uk/data/archive/>: one zip per month, each holding the
#' street, outcomes and stop-and-search CSV files for every force and, since
#' the May 2017 snapshot, a rolling window of the latest 36 months (earlier
#' snapshots hold every month back to December 2010). The index is fetched
#' once and cached; pass `refresh = TRUE` to fetch it again. Without network
#' access a cached index is returned with a warning, and an error of class
#' `streetlamp_error_network` is raised if there is no cache.
#'
#' @param refresh Fetch the page again even if a cached copy exists.
#' @param dir Cache directory; see [lamp_cache_dir()].
#'
#' @return A tibble of class `lamp_archive_index` with one row per snapshot:
#'   `archive` (identifier such as `"2026-07"`), `label`, `url`, `from` and
#'   `to` (first and last data month in the zip), `n_months`, `size_gb` (as
#'   shown on the page) and `md5` (the published checksum of the zip). The
#'   attribute `fetched_at` records when the page was read.
#' @family ingest
#' @export
#' @examplesIf FALSE
#' # Requires network access
#' idx <- lamp_archive_index()
#' idx[idx$archive >= "2026-01", ]
lamp_archive_index <- function(refresh = FALSE, dir = lamp_cache_dir()) {
  check_bool(refresh)
  adir <- lamp_archive_dir(dir)
  cache <- file.path(adir, "index.rds")
  if (!refresh && file.exists(cache)) {
    return(readRDS(cache))
  }
  html <- rlang::try_fetch(
    lamp_http_get_text(lamp_archive_base_url()),
    streetlamp_error_network = function(e) {
      if (file.exists(cache)) {
        lamp_warn(
          "Using the cached archive index because the page could not be fetched.",
          "network"
        )
        return(NULL)
      }
      rlang::cnd_signal(e)
    }
  )
  if (is.null(html)) {
    return(readRDS(cache))
  }
  idx <- lamp_parse_archive_index(html)
  attr(idx, "fetched_at") <- Sys.time()
  dir.create(adir, recursive = TRUE, showWarnings = FALSE)
  saveRDS(idx, cache)
  idx
}

lamp_parse_archive_index <- function(html, call = rlang::caller_env()) {
  blocks <- strsplit(html, "<div class=\"download\">", fixed = TRUE)[[1]][-1]
  pat_link <- "<a href=\"/data/archive/([0-9]{4}-[0-9]{2})\\.zip\">([^<]*)</a>\\s*\\(([^)]*)\\)"
  keep <- grepl(pat_link, blocks)
  blocks <- blocks[keep]
  if (length(blocks) == 0L) {
    lamp_abort(
      c(
        "No archive links were found on the data.police.uk archive page.",
        "i" = "The page layout may have changed; please report this."
      ),
      "network",
      call = call
    )
  }
  m <- regmatches(blocks, regexec(pat_link, blocks))
  archive <- vapply(m, `[`, character(1), 2)
  label <- trimws(vapply(m, `[`, character(1), 3))
  size <- vapply(m, `[`, character(1), 4)
  size_gb <- vapply(size, function(s) {
    num <- as.numeric(sub("^([0-9.]+).*$", "\\1", s))
    if (grepl("MB", s, fixed = TRUE)) num / 1000 else num
  }, numeric(1), USE.NAMES = FALSE)
  range_pat <- "Contains data from ([A-Za-z]{3} [0-9]{4}) to ([A-Za-z]{3} [0-9]{4})"
  rm <- regmatches(blocks, regexec(range_pat, blocks))
  pick <- function(matches, i, n) {
    vapply(matches, function(x) if (length(x) == n) x[i] else NA_character_, character(1))
  }
  from <- lamp_parse_month_label(pick(rm, 2L, 3L))
  to <- lamp_parse_month_label(pick(rm, 3L, 3L))
  md5_pat <- "<p class=\"md5sum\">([0-9a-f]{32})</p>"
  mm <- regmatches(blocks, regexec(md5_pat, blocks))
  md5 <- pick(mm, 2L, 2L)
  n_months <- ifelse(is.na(from) | is.na(to), NA_integer_, lamp_months_between(from, to))
  out <- tibble::tibble(
    archive = archive, label = label, url = lamp_archive_zip_url(archive),
    from = from, to = to, n_months = n_months, size_gb = size_gb, md5 = md5
  )
  out <- out[order(out$archive, decreasing = TRUE), ]
  out <- out[!duplicated(out$archive), ]
  class(out) <- c("lamp_archive_index", class(out))
  out
}

# Archive metadata and member listing on disk ----------------------------------

lamp_archive_meta_path <- function(adir, archive) file.path(adir, archive, "archive.rds")
lamp_archive_members_path <- function(adir, archive) file.path(adir, archive, "members.rds")
lamp_archive_manifest_path <- function(adir, archive) file.path(adir, archive, "manifest.csv")

lamp_write_archive_listing <- function(adir, archive, source, md5 = NA_character_) {
  members <- lamp_zip_directory(source)
  meta <- list(
    archive = archive, source = source$path, kind = source$kind,
    size = source$size, etag = source$etag, last_modified = source$last_modified,
    md5 = md5, n_members = nrow(members), listed_at = Sys.time()
  )
  dir.create(file.path(adir, archive), recursive = TRUE, showWarnings = FALSE)
  saveRDS(members, lamp_archive_members_path(adir, archive))
  saveRDS(meta, lamp_archive_meta_path(adir, archive))
  list(meta = meta, members = members)
}

lamp_read_manifest <- function(adir, archive) {
  path <- lamp_archive_manifest_path(adir, archive)
  empty <- tibble::tibble(
    member = character(), crc32 = character(), usize = numeric(),
    sha256 = character(), fetched_at = character()
  )
  if (!file.exists(path)) {
    return(empty)
  }
  x <- utils::read.csv(path, colClasses = "character", stringsAsFactors = FALSE)
  x$usize <- as.numeric(x$usize)
  x <- x[!duplicated(x$member, fromLast = TRUE), ]
  tibble::as_tibble(x)
}

lamp_append_manifest <- function(adir, archive, row) {
  path <- lamp_archive_manifest_path(adir, archive)
  utils::write.table(
    row, path,
    sep = ",", row.names = FALSE, col.names = !file.exists(path),
    append = file.exists(path), qmethod = "double"
  )
}

lamp_member_local_path <- function(adir, archive, member) {
  file.path(adir, archive, member)
}

# Fetch one member from its source into the archive folder and record it.
lamp_fetch_member <- function(adir, archive, source, entry) {
  raw <- lamp_zip_extract(source, entry)
  dest <- lamp_member_local_path(adir, archive, entry$member)
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  writeBin(raw, dest)
  row <- data.frame(
    member = entry$member, crc32 = entry$crc32, usize = entry$usize,
    sha256 = digest::digest(raw, algo = "sha256", serialize = FALSE),
    fetched_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    stringsAsFactors = FALSE
  )
  lamp_append_manifest(adir, archive, row)
  invisible(dest)
}

#' Register a locally downloaded archive zip
#'
#' Makes a complete archive zip that was downloaded by other means (for
#' example in a browser) available to [lamp_archive_snapshot()] without
#' copying it: the zip is listed and every member becomes readable in place.
#'
#' @param path Path to a zip named like the archive it came from, for example
#'   `2026-07.zip`; the name gives the archive identifier.
#' @param dir Cache directory; see [lamp_cache_dir()].
#' @param md5 Optional published checksum to record with the archive.
#'
#' @return The archive identifier, invisibly.
#' @family ingest
#' @export
#' @examples
#' cache <- tempfile("streetlamp-cache-")
#' zip <- system.file("extdata", "archive", "2026-07.zip", package = "streetlamp")
#' lamp_archive_register(zip, dir = cache)
#' lamp_archive_snapshot(cache)
lamp_archive_register <- function(path, dir = lamp_cache_dir(), md5 = NA_character_) {
  check_string(path)
  archive <- sub("\\.zip$", "", basename(path))
  if (!grepl("^[0-9]{4}-[0-9]{2}$", archive)) {
    lamp_abort(
      "{.path {path}} must be named after its archive month, such as {.file 2026-07.zip}.",
      "input"
    )
  }
  adir <- lamp_archive_dir(dir)
  source <- lamp_zip_source(path)
  lamp_write_archive_listing(adir, archive, source, md5 = md5)
  lamp_inform("Registered archive {.val {archive}} from {.path {path}}.", class = "archive")
  invisible(archive)
}

#' Download force-month files from the data.police.uk archive
#'
#' Fetches the street, outcomes and stop-and-search CSV files for chosen
#' months and forces from one or more archive snapshots, without downloading
#' the whole zip: the zip's table of contents is read with an HTTP byte-range
#' request and each wanted file is then fetched by range and inflated locally.
#' Files already present in the cache with a matching checksum are skipped.
#' Each fetched file is recorded with its CRC32 from the archive, a SHA-256 of
#' its content and the time of download, which is what the panel contract
#' reports as provenance.
#'
#' @param archives Archive identifiers such as `c("2026-06", "2026-07")`, or
#'   `"latest"` (the default) for the newest snapshot in [lamp_archive_index()].
#' @param months Months to fetch as `"YYYY-MM"` strings or Dates; `NULL` for
#'   every month in the archive.
#' @param forces police.uk force identifiers such as `"west-yorkshire"`;
#'   `NULL` for every force. See [lamp_forces()].
#' @param file_types Which of `"street"`, `"outcomes"` and
#'   `"stop-and-search"` to fetch.
#' @param dir Cache directory; see [lamp_cache_dir()].
#' @param index An archive index from [lamp_archive_index()], to avoid fetching
#'   it again.
#' @param relist Read the archive's table of contents again even if it has been
#'   listed before.
#'
#' @return A `lamp_snapshot` (see [lamp_archive_snapshot()]) for `dir`,
#'   invisibly.
#' @family ingest
#' @export
#' @examplesIf FALSE
#' # Requires network access; fetches about 20 MB
#' snap <- lamp_archive_download(
#'   archives = "latest", months = c("2026-05", "2026-06", "2026-07"),
#'   forces = c("west-yorkshire", "dyfed-powys")
#' )
#' snap
lamp_archive_download <- function(archives = "latest", months = NULL, forces = NULL,
                                  file_types = c("street", "outcomes", "stop-and-search"),
                                  dir = lamp_cache_dir(), index = NULL, relist = FALSE) {
  file_types <- rlang::arg_match(file_types, values = lamp_file_types(), multiple = TRUE)
  check_bool(relist)
  months <- lamp_as_months(months)
  if (!is.null(forces) && !is.character(forces)) {
    lamp_abort("{.arg forces} must be a character vector of force identifiers.", "input")
  }
  adir <- lamp_archive_dir(dir)
  if (identical(archives, "latest")) {
    index <- index %||% lamp_archive_index(dir = dir)
    archives <- index$archive[which.max(index$to)]
  }
  if (!is.character(archives) || !all(grepl("^[0-9]{4}-[0-9]{2}$", archives))) {
    lamp_abort(
      "{.arg archives} must be identifiers such as {.val 2026-07}, or {.val latest}.",
      "input"
    )
  }
  for (archive in archives) {
    md5 <- NA_character_
    if (!is.null(index) && archive %in% index$archive) {
      md5 <- index$md5[match(archive, index$archive)]
    }
    source <- NULL
    listing_path <- lamp_archive_members_path(adir, archive)
    if (relist || !file.exists(listing_path)) {
      source <- lamp_zip_source(lamp_archive_zip_url(archive))
      listing <- lamp_write_archive_listing(adir, archive, source, md5 = md5)
      members <- listing$members
      lamp_inform(
        "Listed archive {.val {archive}}: {nrow(members)} file{?s}.",
        class = "archive"
      )
    } else {
      members <- readRDS(listing_path)
    }
    meta <- readRDS(lamp_archive_meta_path(adir, archive))
    parsed <- lamp_parse_members(members$member)
    keep <- !is.na(parsed$file_type) & parsed$file_type %in% file_types
    if (!is.null(months)) keep <- keep & parsed$month %in% months
    if (!is.null(forces)) keep <- keep & parsed$force_id %in% forces
    wanted <- members[keep, ]
    manifest <- lamp_read_manifest(adir, archive)
    have <- wanted$member %in% manifest$member &
      wanted$crc32 == manifest$crc32[match(wanted$member, manifest$member)] &
      file.exists(lamp_member_local_path(adir, archive, wanted$member))
    to_fetch <- wanted[!have, ]
    if (nrow(to_fetch) == 0L) {
      lamp_inform(
        "Archive {.val {archive}}: {nrow(wanted)} matching file{?s} already cached.",
        class = "archive"
      )
      next
    }
    if (meta$kind == "local") {
      source <- lamp_zip_source(meta$source)
    } else {
      source <- source %||% lamp_zip_source(lamp_archive_zip_url(archive))
    }
    cli::cli_progress_bar(
      sprintf("Fetching %s", archive),
      total = nrow(to_fetch),
      format = "{cli::pb_name} {cli::pb_bar} {cli::pb_current}/{cli::pb_total} {cli::pb_eta}"
    )
    for (i in seq_len(nrow(to_fetch))) {
      lamp_fetch_member(adir, archive, source, to_fetch[i, ])
      cli::cli_progress_update()
    }
    cli::cli_progress_done()
    mb <- round(sum(to_fetch$usize) / 1e6, 1)
    lamp_inform(
      "Archive {.val {archive}}: fetched {nrow(to_fetch)} file{?s} ({mb} MB).",
      class = "archive"
    )
  }
  invisible(lamp_archive_snapshot(dir))
}

#' Snapshot of the archive files held locally
#'
#' Describes what the cache directory holds: which archive snapshots have been
#' listed, and for every force-month file in them whether its content is
#' available locally, either because it was fetched by
#' [lamp_archive_download()] or because the whole zip was registered with
#' [lamp_archive_register()]. The snapshot is the starting point for
#' [lamp_list_versions()] and the readers.
#'
#' @param dir Cache directory; see [lamp_cache_dir()].
#'
#' @return A list of class `lamp_snapshot` with elements `dir`, `archives`
#'   (one row per archive: `archive`, `source`, `kind`, `size`, `etag`,
#'   `last_modified`, `md5`, `n_members`, `listed_at`) and `members` (one row
#'   per file: `archive`, `member`, `month`, `force_id`, `file_type`, `crc32`,
#'   `csize`, `usize`, `available`, `path`, `sha256`, `fetched_at`).
#' @family ingest
#' @export
#' @examples
#' cache <- tempfile("streetlamp-cache-")
#' zips <- list.files(
#'   system.file("extdata", "archive", package = "streetlamp"),
#'   pattern = "zip$", full.names = TRUE
#' )
#' for (z in zips) lamp_archive_register(z, dir = cache)
#' snap <- lamp_archive_snapshot(cache)
#' snap
#' table(snap$members$force_id, snap$members$file_type)
lamp_archive_snapshot <- function(dir = lamp_cache_dir()) {
  check_string(dir)
  adir <- lamp_archive_dir(dir)
  ids <- character()
  if (dir.exists(adir)) {
    dirs <- list.dirs(adir, full.names = FALSE, recursive = FALSE)
    listed <- grepl("^[0-9]{4}-[0-9]{2}$", dirs) & file.exists(lamp_archive_meta_path(adir, dirs))
    ids <- dirs[listed]
  }
  ids <- sort(ids)
  archives <- tibble::tibble(
    archive = character(), source = character(), kind = character(),
    size = numeric(), etag = character(), last_modified = character(),
    md5 = character(), n_members = integer(), listed_at = as.POSIXct(character())
  )
  members <- tibble::tibble(
    archive = character(), member = character(), month = as.Date(character()),
    force_id = character(), file_type = character(), crc32 = character(),
    csize = numeric(), usize = numeric(), available = logical(),
    path = character(), sha256 = character(), fetched_at = character()
  )
  for (archive in ids) {
    meta <- readRDS(lamp_archive_meta_path(adir, archive))
    if (meta$kind == "local" && !file.exists(meta$source)) {
      lamp_warn(
        "Registered zip {.path {meta$source}} for archive {.val {archive}} is no longer present.",
        "archive"
      )
    }
    archives <- rbind(archives, tibble::tibble(
      archive = archive, source = meta$source, kind = meta$kind,
      size = meta$size, etag = meta$etag %||% NA_character_,
      last_modified = meta$last_modified %||% NA_character_,
      md5 = meta$md5 %||% NA_character_, n_members = as.integer(meta$n_members),
      listed_at = meta$listed_at
    ))
    m <- readRDS(lamp_archive_members_path(adir, archive))
    parsed <- lamp_parse_members(m$member)
    manifest <- lamp_read_manifest(adir, archive)
    idx <- match(m$member, manifest$member)
    fetched <- !is.na(idx) & manifest$crc32[idx] == m$crc32 &
      file.exists(lamp_member_local_path(adir, archive, m$member))
    fetched[is.na(fetched)] <- FALSE
    local_zip_ok <- meta$kind == "local" && file.exists(meta$source)
    members <- rbind(members, tibble::tibble(
      archive = archive, member = m$member, month = parsed$month,
      force_id = parsed$force_id, file_type = parsed$file_type,
      crc32 = m$crc32, csize = m$csize, usize = m$usize,
      available = fetched | local_zip_ok,
      path = ifelse(fetched, lamp_member_local_path(adir, archive, m$member), NA_character_),
      sha256 = ifelse(fetched, manifest$sha256[idx], NA_character_),
      fetched_at = ifelse(fetched, manifest$fetched_at[idx], NA_character_)
    ))
  }
  structure(list(dir = dir, archives = archives, members = members), class = "lamp_snapshot")
}

#' @export
print.lamp_snapshot <- function(x, ...) {
  cli::cli_h3("streetlamp archive snapshot")
  cli::cli_text("Cache: {.path {x$dir}}")
  if (nrow(x$archives) == 0L) {
    cli::cli_alert_info(
      "No archives listed. Use {.fn lamp_archive_download} or {.fn lamp_archive_register}."
    )
    return(invisible(x))
  }
  m <- x$members[!is.na(x$members$file_type), ]
  cli::cli_text("{nrow(x$archives)} archive{?s}: {.val {x$archives$archive}}")
  cli::cli_text(
    "{nrow(m)} force-month file{?s} covering {length(unique(m$force_id))} force{?s}, ",
    "{lamp_month_id(min(m$month))} to {lamp_month_id(max(m$month))}; ",
    "{sum(m$available)} available locally."
  )
  for (ft in sort(unique(m$file_type))) {
    n_ft <- sum(m$file_type == ft)
    n_ok <- sum(m$file_type == ft & m$available)
    cli::cli_bullets(c(" " = "{ft}: {n_ok} of {n_ft} available"))
  }
  invisible(x)
}

# Path to a member's CSV, extracting from a registered zip or fetching from
# the remote archive when needed.
lamp_member_path <- function(snapshot, archive, member, fetch = TRUE,
                             call = rlang::caller_env()) {
  adir <- lamp_archive_dir(snapshot$dir)
  m <- snapshot$members
  row <- m[m$archive == archive & m$member == member, ]
  if (nrow(row) != 1L) {
    lamp_abort("{.file {member}} is not listed in archive {.val {archive}}.", "input", call = call)
  }
  local <- lamp_member_local_path(adir, archive, member)
  if (!is.na(row$path) && file.exists(row$path)) {
    return(row$path)
  }
  meta <- snapshot$archives[snapshot$archives$archive == archive, ]
  entry <- readRDS(lamp_archive_members_path(adir, archive))
  entry <- entry[entry$member == member, ]
  if (meta$kind == "local") {
    source <- lamp_zip_source(meta$source, call = call)
  } else if (fetch) {
    source <- lamp_zip_source(lamp_archive_zip_url(archive), call = call)
  } else {
    lamp_abort(
      c(
        "{.file {member}} from archive {.val {archive}} has not been fetched.",
        "i" = "Run {.fn lamp_archive_download} for that month and force first."
      ),
      "input",
      call = call
    )
  }
  lamp_fetch_member(adir, archive, source, entry)
  local
}

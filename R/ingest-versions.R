# Versions across archive snapshots ------------------------------------------------
#
# The same force-month file appears in every archive snapshot whose window
# covers that month, and its content can differ between snapshots: street
# files change as outcomes are updated, and a force may re-supply a whole
# month. streetlamp never merges rows across versions. It lists every version,
# selects one per force-month and file type by an explicit rule, and records
# the alternatives in the contract.

#' List the archive versions of every force-month file
#'
#' @param snapshot A `lamp_snapshot` from [lamp_archive_snapshot()].
#' @param file_types Restrict to some of `"street"`, `"outcomes"` and
#'   `"stop-and-search"`; `NULL` for all.
#'
#' @return A tibble of class `lamp_versions` with one row per force, month and
#'   file type: `n_versions`, `archives` (list-column of archive identifiers,
#'   oldest first), `crc32` (list-column, aligned with `archives`), `differs`
#'   (`TRUE` when the versions do not all share one checksum), `usize_min`,
#'   `usize_max`, and `n_available` (versions readable locally).
#' @family ingest
#' @export
#' @examples
#' cache <- tempfile("streetlamp-cache-")
#' zips <- list.files(
#'   system.file("extdata", "archive", package = "streetlamp"),
#'   pattern = "zip$", full.names = TRUE
#' )
#' for (z in zips) lamp_archive_register(z, dir = cache)
#' v <- lamp_list_versions(lamp_archive_snapshot(cache))
#' v[v$n_versions > 1, c("force_id", "month", "file_type", "n_versions", "differs")]
lamp_list_versions <- function(snapshot, file_types = NULL) {
  lamp_check_snapshot(snapshot)
  m <- snapshot$members[!is.na(snapshot$members$file_type), ]
  if (!is.null(file_types)) {
    file_types <- rlang::arg_match(file_types, values = lamp_file_types(), multiple = TRUE)
    m <- m[m$file_type %in% file_types, ]
  }
  m <- m[order(m$force_id, m$month, m$file_type, m$archive), ]
  out <- m |>
    dplyr::group_by(.data$force_id, .data$month, .data$file_type) |>
    dplyr::summarise(
      n_versions = dplyr::n(),
      differs = length(unique(.data$crc32)) > 1L,
      usize_min = min(.data$usize),
      usize_max = max(.data$usize),
      n_available = sum(.data$available),
      archives = list(.data$archive),
      crc32 = list(.data$crc32),
      .groups = "drop"
    )
  out <- out[, c(
    "force_id", "month", "file_type", "n_versions", "archives", "crc32",
    "differs", "usize_min", "usize_max", "n_available"
  )]
  class(out) <- c("lamp_versions", class(out))
  out
}

#' Select one archive version per force-month file
#'
#' @param versions Output of [lamp_list_versions()].
#' @param rule `"latest"` (default) takes the newest archive snapshot holding
#'   the file, on the grounds that later snapshots carry the most complete
#'   outcome information and any re-supplied data; `"earliest"` takes the
#'   oldest, which is the version closest to first publication.
#' @param prefer Optional archive identifiers to use whenever they hold the
#'   file, before applying `rule` to the rest.
#'
#' @return A tibble of class `lamp_selection` with one row per force, month
#'   and file type: the chosen `archive`, its `crc32` and `usize`,
#'   `n_versions`, `differs`, `alternatives` (list-column of tibbles naming
#'   the other archives with their checksums and sizes) and `rule`.
#' @family ingest
#' @export
#' @examples
#' cache <- tempfile("streetlamp-cache-")
#' zips <- list.files(
#'   system.file("extdata", "archive", package = "streetlamp"),
#'   pattern = "zip$", full.names = TRUE
#' )
#' for (z in zips) lamp_archive_register(z, dir = cache)
#' v <- lamp_list_versions(lamp_archive_snapshot(cache))
#' sel <- lamp_select_version(v, rule = "latest")
#' sel[, c("force_id", "month", "file_type", "archive", "n_versions")]
lamp_select_version <- function(versions, rule = c("latest", "earliest"), prefer = NULL) {
  rule <- rlang::arg_match(rule)
  if (!inherits(versions, "lamp_versions")) {
    lamp_abort("{.arg versions} must come from {.fn lamp_list_versions}.", "input")
  }
  if (!is.null(prefer) && !is.character(prefer)) {
    lamp_abort("{.arg prefer} must be a character vector of archive identifiers.", "input")
  }
  pick <- function(archives) {
    if (!is.null(prefer)) {
      hit <- prefer[prefer %in% archives]
      if (length(hit) > 0L) {
        return(hit[1])
      }
    }
    if (rule == "latest") max(archives) else min(archives)
  }
  chosen <- vapply(versions$archives, pick, character(1))
  idx <- mapply(function(a, c) match(c, a), versions$archives, chosen)
  out <- tibble::tibble(
    force_id = versions$force_id,
    month = versions$month,
    file_type = versions$file_type,
    archive = chosen,
    crc32 = mapply(function(x, i) x[i], versions$crc32, idx),
    usize = NA_real_,
    n_versions = versions$n_versions,
    differs = versions$differs,
    alternatives = mapply(function(a, c, i) {
      tibble::tibble(archive = a[-i], crc32 = c[-i])
    }, versions$archives, versions$crc32, idx, SIMPLIFY = FALSE),
    rule = rule
  )
  class(out) <- c("lamp_selection", class(out))
  out
}

# Fill the selected member's usize and availability from the snapshot.
lamp_selection_members <- function(snapshot, selection, call = rlang::caller_env()) {
  m <- snapshot$members
  key_m <- paste(m$archive, m$force_id, lamp_month_id(m$month), m$file_type)
  key_s <- paste(
    selection$archive, selection$force_id, lamp_month_id(selection$month),
    selection$file_type
  )
  idx <- match(key_s, key_m)
  if (anyNA(idx)) {
    lamp_abort(
      c(
        "The selection refers to files that are not in the snapshot.",
        "i" = "Rebuild it with {.fn lamp_list_versions}."
      ),
      "input",
      call = call
    )
  }
  m[idx, ]
}

lamp_check_snapshot <- function(x, arg = rlang::caller_arg(x), call = rlang::caller_env()) {
  if (!inherits(x, "lamp_snapshot")) {
    lamp_abort(
      "{.arg {arg}} must be a snapshot from {.fn lamp_archive_snapshot}.",
      "input",
      call = call
    )
  }
  invisible(x)
}

#' Compare the archive versions of one force-month file
#'
#' Reads every available version of a file and reports what differs: the
#' number of rows, and for street and outcomes files the crime identifiers
#' present in one version but not another. Street files routinely differ
#' between snapshots only in their `Last outcome category` column, which is
#' why row and identifier counts, not checksums, decide whether a force
#' re-supplied a month.
#'
#' @param snapshot A `lamp_snapshot` from [lamp_archive_snapshot()].
#' @param force A police.uk force identifier.
#' @param month A month as `"YYYY-MM"` or a Date.
#' @param file_type One of `"street"`, `"outcomes"`, `"stop-and-search"`.
#' @param fetch Fetch versions that are listed but not held locally (needs
#'   network access).
#'
#' @return A tibble with one row per version: `archive`, `n_rows`, `n_ids`
#'   (distinct crime identifiers; `NA` for stop-and-search files),
#'   `ids_not_in_others` (identifiers absent from every other version) and
#'   `crc32`. The attribute `outcome_changes` gives, for street files, the
#'   number of shared crimes whose last outcome category differs between the
#'   oldest and newest versions.
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
#' lamp_version_diff(snap, "west-yorkshire", "2026-05", "outcomes")
lamp_version_diff <- function(snapshot, force, month,
                              file_type = c("street", "outcomes", "stop-and-search"),
                              fetch = FALSE) {
  lamp_check_snapshot(snapshot)
  check_string(force)
  file_type <- rlang::arg_match(file_type)
  check_bool(fetch)
  month <- lamp_as_months(month)
  m <- snapshot$members
  hit <- !is.na(m$force_id) & m$force_id == force & m$month == month & m$file_type == file_type
  rows <- m[hit, ]
  if (nrow(rows) == 0L) {
    lamp_abort(
      "No {file_type} file for {.val {force}} in {lamp_month_id(month)} is listed in the snapshot.",
      "input"
    )
  }
  rows <- rows[order(rows$archive), ]
  ids <- vector("list", nrow(rows))
  n_rows <- integer(nrow(rows))
  outcomes <- vector("list", nrow(rows))
  for (i in seq_len(nrow(rows))) {
    path <- lamp_member_path(snapshot, rows$archive[i], rows$member[i], fetch = fetch)
    x <- utils::read.csv(path, colClasses = "character", na.strings = "", check.names = FALSE)
    n_rows[i] <- nrow(x)
    if (file_type != "stop-and-search") {
      ids[[i]] <- x[["Crime ID"]][!is.na(x[["Crime ID"]])]
      if (file_type == "street") {
        outcomes[[i]] <- x[!is.na(x[["Crime ID"]]), c("Crime ID", "Last outcome category")]
      }
    }
  }
  n_ids <- vapply(ids, function(v) if (is.null(v)) NA_integer_ else length(unique(v)), integer(1))
  only <- vapply(seq_along(ids), function(i) {
    if (is.null(ids[[i]])) {
      return(NA_integer_)
    }
    others <- unique(unlist(ids[-i]))
    length(setdiff(unique(ids[[i]]), others))
  }, integer(1))
  out <- tibble::tibble(
    archive = rows$archive, n_rows = n_rows, n_ids = n_ids,
    ids_not_in_others = only, crc32 = rows$crc32
  )
  if (file_type == "street" && nrow(rows) > 1L) {
    a <- outcomes[[1]]
    b <- outcomes[[nrow(rows)]]
    j <- merge(a, b, by = "Crime ID")
    attr(out, "outcome_changes") <- sum(j[[2]] != j[[3]], na.rm = TRUE)
  }
  out
}

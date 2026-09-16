# Readers for street and outcomes files -------------------------------------------

lamp_street_columns <- function() {
  c(
    "Crime ID", "Month", "Reported by", "Falls within", "Longitude", "Latitude",
    "Location", "LSOA code", "LSOA name", "Crime type", "Last outcome category",
    "Context"
  )
}

lamp_outcomes_columns <- function() {
  c(
    "Crime ID", "Month", "Reported by", "Falls within", "Longitude", "Latitude",
    "Location", "LSOA code", "LSOA name", "Outcome type"
  )
}

lamp_check_columns <- function(x, expected, file, call = rlang::caller_env()) {
  missing <- setdiff(expected, names(x))
  if (length(missing) > 0L) {
    lamp_abort(
      c(
        "{.file {file}} lacks the column{?s} {.field {missing}}.",
        "i" = "The data.police.uk file layout may have changed; see inst/NOTES/data_sources.md."
      ),
      "input",
      call = call
    )
  }
  invisible(x)
}

lamp_read_member_csv <- function(path) {
  utils::read.csv(
    path,
    colClasses = "character", na.strings = "", check.names = FALSE,
    encoding = "UTF-8", stringsAsFactors = FALSE
  )
}

# Turn `dir` (a cache directory or a snapshot) into a snapshot.
lamp_resolve_snapshot <- function(dir, call = rlang::caller_env()) {
  if (inherits(dir, "lamp_snapshot")) {
    return(dir)
  }
  check_string(dir, arg = "dir", call = call)
  snap <- lamp_archive_snapshot(dir)
  if (nrow(snap$archives) == 0L) {
    lamp_abort(
      c(
        "No archives are listed under {.path {dir}}.",
        "i" = "Run {.fn lamp_archive_download} or {.fn lamp_archive_register} first."
      ),
      "input",
      call = call
    )
  }
  snap
}

# Restrict a selection (default: latest rule) to one file type and filters,
# and decide what may be read. Without month or force filters only files held
# locally are read, so a reader can never start a large download by accident;
# with filters, files that are listed but not held raise an error unless
# `fetch = TRUE`.
lamp_resolve_selection <- function(snapshot, versions, file_type, months, forces, fetch,
                                   call = rlang::caller_env()) {
  if (is.null(versions)) {
    versions <- lamp_select_version(lamp_list_versions(snapshot, file_types = file_type))
  } else if (!inherits(versions, "lamp_selection")) {
    lamp_abort("{.arg versions} must come from {.fn lamp_select_version}.", "input", call = call)
  }
  sel <- versions[versions$file_type == file_type, ]
  if (!is.null(months)) sel <- sel[sel$month %in% months, ]
  if (!is.null(forces)) {
    if (!is.character(forces)) {
      lamp_abort(
        "{.arg forces} must be a character vector of force identifiers.",
        "input",
        call = call
      )
    }
    sel <- sel[sel$force_id %in% forces, ]
  }
  if (nrow(sel) == 0L) {
    lamp_abort(
      "No {file_type} files match the requested months and forces in this snapshot.",
      "input",
      call = call
    )
  }
  available <- lamp_selection_members(snapshot, sel, call = call)$available
  if (all(available) || fetch) {
    return(sel)
  }
  n_sel <- nrow(sel)
  n_avail <- sum(available)
  n_missing <- sum(!available)
  if (n_avail == 0L) {
    lamp_abort(
      c(
        "None of the {n_sel} selected {file_type} {cli::qty(n_sel)}file{?s} is held locally.",
        "i" = "Run {.fn lamp_archive_download} first, or set {.code fetch = TRUE}."
      ),
      "input",
      call = call
    )
  }
  lamp_inform(
    c(
      "Reading the {n_avail} {file_type} {cli::qty(n_avail)}file{?s} held locally.",
      "i" = "{n_missing} selected {cli::qty(n_missing)}file{?s} {?is/are} not fetched.",
      "i" = "Run {.fn lamp_archive_download} first, or set {.code fetch = TRUE}, to read them too."
    ),
    class = "archive"
  )
  sel[available, ]
}

# Force-month coverage grid for one file type over the requested (or read)
# forces and months: `submitted` when a file was read, `not_read` when a file
# is listed in the snapshot but was not read, and `missing` when no archive
# holds a file. Force did not submit is never a zero.
lamp_coverage_grid <- function(snapshot, sel, file_type, months, forces) {
  m <- snapshot$members
  m <- m[!is.na(m$file_type) & m$file_type == file_type, ]
  all_months <- months %||% seq(min(sel$month), max(sel$month), by = "month")
  all_forces <- forces %||% sort(unique(sel$force_id))
  grid <- expand.grid(force_id = all_forces, month = all_months, stringsAsFactors = FALSE)
  grid <- grid[order(grid$force_id, grid$month), ]
  key_g <- paste(grid$force_id, lamp_month_id(grid$month))
  key_m <- paste(m$force_id, lamp_month_id(m$month))
  idx <- match(key_g, paste(sel$force_id, lamp_month_id(sel$month)))
  listed <- key_g %in% key_m
  status <- ifelse(!is.na(idx), "submitted", ifelse(listed, "not_read", "missing"))
  n_versions <- vapply(key_g, function(k) sum(key_m == k), integer(1), USE.NAMES = FALSE)
  tibble::tibble(
    force_id = grid$force_id,
    month = grid$month,
    file_type = file_type,
    status = status,
    archive = ifelse(is.na(idx), NA_character_, sel$archive[idx]),
    n_records = NA_integer_,
    n_versions = n_versions,
    versions_differ = ifelse(is.na(idx), NA, sel$differs[idx])
  )
}

# Read every selected file with `parser` and assemble records plus per-file
# diagnostics.
lamp_read_selected <- function(snapshot, sel, parser, fetch, call = rlang::caller_env()) {
  members <- lamp_selection_members(snapshot, sel, call = call)
  parts <- vector("list", nrow(sel))
  n_records <- integer(nrow(sel))
  diag <- vector("list", nrow(sel))
  for (i in seq_len(nrow(sel))) {
    path <- lamp_member_path(
      snapshot, sel$archive[i], members$member[i],
      fetch = fetch, call = call
    )
    raw <- lamp_read_member_csv(path)
    parsed <- parser(raw,
      force_id = sel$force_id[i], archive = sel$archive[i],
      file = members$member[i], month = sel$month[i]
    )
    parts[[i]] <- parsed$data
    diag[[i]] <- parsed$diagnostics
    n_records[i] <- nrow(raw)
  }
  list(
    data = dplyr::bind_rows(parts),
    n_records = n_records,
    diagnostics = dplyr::bind_rows(diag)
  )
}

lamp_month_column <- function(x, file, month, call = rlang::caller_env()) {
  m <- as.Date(paste0(x, "-01"))
  if (anyNA(m) || any(m != month)) {
    lamp_warn(
      "{.file {file}} holds rows dated outside {lamp_month_id(month)}; the row dates are kept.",
      "input"
    )
  }
  m
}

# Crime types ------------------------------------------------------------------

lamp_category_set <- function(labels) {
  labels <- unique(labels[!is.na(labels)])
  legacy <- c("Violent crime", "Public disorder and weapons")
  phase2 <- c("Criminal damage and arson", "Drugs", "Other theft", "Shoplifting")
  if (any(labels %in% legacy)) {
    if (any(labels %in% phase2)) "eleven" else "six"
  } else {
    "fourteen"
  }
}

lamp_harmonise_crime_type <- function(x, file) {
  ct <- lamp_crime_types()
  legacy <- lamp_legacy_crime_types()
  kept <- legacy$legacy_label[is.na(legacy$crime_type)]
  levels_all <- c(ct$crime_type, kept)
  mapped <- x
  renamed <- legacy[!is.na(legacy$crime_type) & legacy$legacy_label != legacy$crime_type, ]
  hit <- match(mapped, renamed$legacy_label)
  mapped[!is.na(hit)] <- renamed$crime_type[hit[!is.na(hit)]]
  unknown <- setdiff(unique(mapped[!is.na(mapped)]), levels_all)
  if (length(unknown) > 0L) {
    lamp_warn(
      c(
        "{.file {file}} uses unrecognised crime type label{?s} {.val {unknown}}; set to {.val NA}.",
        "i" = "The raw label is kept in {.field crime_type_raw}."
      ),
      "input"
    )
  }
  f <- factor(mapped, levels = levels_all)
  list(crime_type = f, category_set = lamp_category_set(x))
}

lamp_parse_street <- function(raw, force_id, archive, file, month) {
  lamp_check_columns(raw, lamp_street_columns(), file)
  ct <- lamp_harmonise_crime_type(raw[["Crime type"]], file)
  vint <- lamp_vintage_decide(lamp_vintage_counts(raw[["LSOA code"]]), month)
  data <- tibble::tibble(
    crime_id = raw[["Crime ID"]],
    month = lamp_month_column(raw[["Month"]], file, month),
    reported_by = raw[["Reported by"]],
    falls_within = raw[["Falls within"]],
    force_id = force_id,
    longitude = as.numeric(raw[["Longitude"]]),
    latitude = as.numeric(raw[["Latitude"]]),
    location = raw[["Location"]],
    lsoa_code = raw[["LSOA code"]],
    lsoa_name = raw[["LSOA name"]],
    lsoa_vintage = vint$vintage,
    crime_type = ct$crime_type,
    crime_type_raw = raw[["Crime type"]],
    is_asb = !is.na(ct$crime_type) & ct$crime_type == "Anti-social behaviour",
    last_outcome_category = raw[["Last outcome category"]],
    context = raw[["Context"]],
    archive = archive,
    file = file
  )
  diagnostics <- tibble::tibble(
    archive = archive, file = file, force_id = force_id, month = month,
    n_records = nrow(raw), n_asb = sum(data$is_asb),
    n_asb_with_id = sum(data$is_asb & !is.na(data$crime_id)),
    n_missing_id = sum(!data$is_asb & is.na(data$crime_id)),
    n_missing_location = sum(is.na(data$latitude) | is.na(data$longitude)),
    n_missing_lsoa = sum(is.na(data$lsoa_code)),
    category_set = ct$category_set,
    lsoa_vintage = vint$vintage, vintage_basis = vint$basis,
    n_codes = vint$n_codes, n_only_2011 = vint$n_only_2011,
    n_only_2021 = vint$n_only_2021, n_unknown_codes = vint$n_unknown
  )
  list(data = data, diagnostics = diagnostics)
}

lamp_parse_outcomes <- function(raw, force_id, archive, file, month) {
  lamp_check_columns(raw, lamp_outcomes_columns(), file)
  ot <- lamp_outcome_types()
  labels <- raw[["Outcome type"]]
  alias <- match(labels, ot$api_name)
  labels[!is.na(alias)] <- ot$outcome_type[alias[!is.na(alias)]]
  unknown <- setdiff(unique(labels[!is.na(labels)]), ot$outcome_type)
  if (length(unknown) > 0L) {
    lamp_warn(
      c(
        "{.file {file}} uses unrecognised outcome label{?s} {.val {unknown}}; set to {.val NA}.",
        "i" = "The raw label is kept in {.field outcome_type_raw}."
      ),
      "input"
    )
  }
  outcome_type <- factor(labels, levels = ot$outcome_type)
  vint <- lamp_vintage_decide(lamp_vintage_counts(raw[["LSOA code"]]), month)
  data <- tibble::tibble(
    crime_id = raw[["Crime ID"]],
    month = lamp_month_column(raw[["Month"]], file, month),
    reported_by = raw[["Reported by"]],
    falls_within = raw[["Falls within"]],
    force_id = force_id,
    longitude = as.numeric(raw[["Longitude"]]),
    latitude = as.numeric(raw[["Latitude"]]),
    location = raw[["Location"]],
    lsoa_code = raw[["LSOA code"]],
    lsoa_name = raw[["LSOA name"]],
    lsoa_vintage = vint$vintage,
    outcome_type = outcome_type,
    outcome_type_raw = labels,
    outcome_group = ot$group[match(outcome_type, ot$outcome_type)],
    archive = archive,
    file = file
  )
  diagnostics <- tibble::tibble(
    archive = archive, file = file, force_id = force_id, month = month,
    n_records = nrow(raw), n_missing_id = sum(is.na(data$crime_id)),
    n_duplicate_id = sum(duplicated(data$crime_id[!is.na(data$crime_id)])),
    n_missing_location = sum(is.na(data$latitude) | is.na(data$longitude)),
    n_missing_lsoa = sum(is.na(data$lsoa_code)),
    lsoa_vintage = vint$vintage, vintage_basis = vint$basis,
    n_codes = vint$n_codes, n_only_2011 = vint$n_only_2011,
    n_only_2021 = vint$n_only_2021, n_unknown_codes = vint$n_unknown
  )
  list(data = data, diagnostics = diagnostics)
}

lamp_records_contract <- function(snapshot, sel, coverage, diagnostics, file_type, extra = list()) {
  coverage$n_records <- diagnostics$n_records[match(
    paste(coverage$force_id, lamp_month_id(coverage$month)),
    paste(diagnostics$force_id, lamp_month_id(diagnostics$month))
  )]
  used <- snapshot$archives[snapshot$archives$archive %in% sel$archive, ]
  geo_cols <- intersect(
    c(
      "archive", "file", "force_id", "month", "lsoa_vintage", "vintage_basis",
      "n_codes", "n_only_2011", "n_only_2021", "n_unknown_codes"
    ),
    names(diagnostics)
  )
  contract <- new_lamp_contract(
    snapshots = used,
    versions = sel,
    coverage = coverage,
    geography = list(
      area = NULL,
      lsoa_vintage = sort(unique(diagnostics$lsoa_vintage)),
      files = diagnostics[, geo_cols]
    )
  )
  for (nm in names(extra)) contract[[nm]] <- extra[[nm]]
  contract
}

#' Read street-level crime records from the archive
#'
#' Reads the selected `street` files into one table with a fixed snake_case
#' schema, harmonises crime type labels across the three category sets that
#' data.police.uk has used since December 2010, flags anti-social behaviour,
#' detects the LSOA vintage of every file, and attaches a panel contract.
#'
#' @details
#' Crime types are returned as a factor whose levels are the fourteen current
#' categories plus `Public disorder and weapons`, the legacy category that was
#' split in May 2013 and cannot be mapped forward. `Violent crime`, the
#' pre-2013 name of `Violence and sexual offences`, is renamed. The raw label
#' is kept in `crime_type_raw`, and the contract's `crime_scope$category_sets`
#' records which set each file uses (`six` for December 2010 to August 2011,
#' `eleven` to April 2013, `fourteen` since May 2013).
#'
#' Anti-social behaviour rows have no Crime ID and no outcome; they are kept
#' with `is_asb = TRUE` so that `lamp_panel()` can hold them in a separate
#' series. Rows without coordinates or LSOA code are kept as `NA`.
#'
#' @param dir A cache directory (see [lamp_cache_dir()]) or a `lamp_snapshot`
#'   from [lamp_archive_snapshot()].
#' @param versions A `lamp_selection` from [lamp_select_version()]; by default
#'   the newest archive version of each file is used.
#' @param months,forces Optional filters, as in [lamp_archive_download()].
#' @param fetch Fetch selected files that are listed in the snapshot but not
#'   held locally (needs network access). With the default `FALSE` only the
#'   files held locally are read, with a message saying how many were skipped,
#'   so a reader never starts a large download on its own.
#'
#' @return A tibble of class `lamp_records` with columns `crime_id`, `month`
#'   (Date, first of month), `reported_by`, `falls_within`, `force_id` (from
#'   the file name), `longitude`, `latitude`, `location`, `lsoa_code`,
#'   `lsoa_name`, `lsoa_vintage`, `crime_type` (factor), `crime_type_raw`,
#'   `is_asb`, `last_outcome_category`, `context`, `archive` and `file`, and
#'   a contract retrievable with [lamp_contract()] whose `coverage` element
#'   marks force-months with no file as `missing`.
#' @family ingest
#' @export
#' @examples
#' cache <- tempfile("streetlamp-cache-")
#' zip <- system.file("extdata", "archive", "2026-07.zip", package = "streetlamp")
#' lamp_archive_register(zip, dir = cache)
#' crime <- lamp_read_crime(cache, forces = "dyfed-powys")
#' crime
#' table(crime$crime_type)
#' lamp_contract(crime)$coverage
lamp_read_crime <- function(dir = lamp_cache_dir(), versions = NULL, months = NULL,
                            forces = NULL, fetch = FALSE) {
  check_bool(fetch)
  months <- lamp_as_months(months)
  snapshot <- lamp_resolve_snapshot(dir)
  sel <- lamp_resolve_selection(snapshot, versions, "street", months, forces, fetch)
  read <- lamp_read_selected(snapshot, sel, lamp_parse_street, fetch)
  coverage <- lamp_coverage_grid(snapshot, sel, "street", months, forces)
  contract <- lamp_records_contract(
    snapshot, sel, coverage, read$diagnostics, "street",
    extra = list(crime_scope = list(
      category_sets = read$diagnostics[, c("archive", "file", "force_id", "month", "category_set")],
      crime_types = levels(read$data$crime_type),
      diagnostics = read$diagnostics
    ))
  )
  new_lamp_records(read$data, contract)
}

#' Read outcome records from the archive
#'
#' Reads the selected `outcomes` files into one table with a fixed schema,
#' classifies outcomes with [lamp_outcome_types()], detects the LSOA vintage
#' of every file, and attaches a panel contract. An outcomes file for a month
#' lists the outcomes recorded in that month, whose crimes may date from
#' earlier months, and a crime can have several outcomes.
#'
#' @inheritParams lamp_read_crime
#'
#' @return A tibble of class `lamp_records` with columns `crime_id`, `month`,
#'   `reported_by`, `falls_within`, `force_id`, `longitude`, `latitude`,
#'   `location`, `lsoa_code`, `lsoa_name`, `lsoa_vintage`, `outcome_type`
#'   (factor), `outcome_type_raw`, `outcome_group` (factor with the six
#'   groups of [lamp_outcome_types()]), `archive` and `file`, plus a contract.
#' @family ingest
#' @export
#' @examples
#' cache <- tempfile("streetlamp-cache-")
#' zip <- system.file("extdata", "archive", "2026-07.zip", package = "streetlamp")
#' lamp_archive_register(zip, dir = cache)
#' outcomes <- lamp_read_outcomes(cache, forces = "dyfed-powys", months = "2026-07")
#' table(outcomes$outcome_group)
lamp_read_outcomes <- function(dir = lamp_cache_dir(), versions = NULL, months = NULL,
                               forces = NULL, fetch = FALSE) {
  check_bool(fetch)
  months <- lamp_as_months(months)
  snapshot <- lamp_resolve_snapshot(dir)
  sel <- lamp_resolve_selection(snapshot, versions, "outcomes", months, forces, fetch)
  read <- lamp_read_selected(snapshot, sel, lamp_parse_outcomes, fetch)
  coverage <- lamp_coverage_grid(snapshot, sel, "outcomes", months, forces)
  contract <- lamp_records_contract(
    snapshot, sel, coverage, read$diagnostics, "outcomes",
    extra = list(crime_scope = list(
      outcome_groups = lamp_outcome_groups(),
      diagnostics = read$diagnostics
    ))
  )
  new_lamp_records(read$data, contract)
}

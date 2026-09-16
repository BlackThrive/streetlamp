# Coverage audit ------------------------------------------------------------------
#
# Coverage is a force x month x file-type grid with one status each:
#   submitted          a file was read for this force-month
#   missing            no archive snapshot holds a file
#   not_read           a file is listed but was not read (not fetched)
#   refreshed          the publisher's changelog says the force re-supplied it
#   partial_suspected  the record count is far below the force's recent level
# and a `mismatch` flag for months where a stop-and-search file exists without
# a street file or the reverse, which breaks the treatment-outcome link.

lamp_partial_threshold <- function() 0.2

# Flag force-months whose record count is below 20 percent of the force's
# median over the previous twelve submitted months (at least three needed).
lamp_flag_partial <- function(cov) {
  cov <- cov[order(cov$file_type, cov$force_id, cov$month), ]
  cov$partial_suspected <- FALSE
  groups <- split(seq_len(nrow(cov)), paste(cov$file_type, cov$force_id))
  for (idx in groups) {
    n <- cov$n_records[idx]
    m <- cov$month[idx]
    ok <- cov$status[idx] %in% c("submitted", "refreshed")
    for (i in seq_along(idx)) {
      if (!ok[i] || is.na(n[i])) next
      prior <- which(ok & !is.na(n) & m < m[i] & m >= m[i] - 366)
      prior <- prior[m[prior] >= seq(m[i], by = "-12 months", length.out = 2)[2]]
      if (length(prior) < 3L) next
      med <- stats::median(n[prior])
      if (med > 0 && n[i] < lamp_partial_threshold() * med) {
        cov$partial_suspected[idx[i]] <- TRUE
      }
    }
  }
  cov$status[cov$partial_suspected & cov$status == "submitted"] <- "partial_suspected"
  cov$partial_suspected <- NULL
  cov
}

# Apply changelog refresh notes: a submitted force-month covered by a refresh
# entry becomes `refreshed` and carries the note.
lamp_apply_changelog <- function(cov, changelog) {
  cov$note <- NA_character_
  if (is.null(changelog) || nrow(changelog) == 0L) {
    return(cov)
  }
  for (i in seq_len(nrow(changelog))) {
    e <- changelog[i, ]
    if (is.na(e$force_id) || is.na(e$action)) next
    types <- if (e$file_type == "all") {
      lamp_file_types()
    } else {
      strsplit(e$file_type, ";", fixed = TRUE)[[1]]
    }
    hit <- cov$force_id == e$force_id & cov$file_type %in% types
    if (!is.na(e$from)) hit <- hit & cov$month >= e$from
    if (!is.na(e$to)) hit <- hit & cov$month <= e$to
    if (!any(hit)) next
    if (e$action == "refresh") {
      cov$status[hit & cov$status == "submitted"] <- "refreshed"
    }
    cov$note[hit] <- ifelse(is.na(cov$note[hit]), e$text, paste(cov$note[hit], e$text, sep = " | "))
  }
  cov
}

# Combine per-file-type coverage grids into one audit table.
lamp_coverage_table <- function(street, outcomes = NULL, stops = NULL, changelog = NULL) {
  parts <- list(street, outcomes, stops)
  parts <- parts[!vapply(parts, is.null, logical(1))]
  cov <- dplyr::bind_rows(parts)
  cov <- cov[!duplicated(paste(cov$force_id, lamp_month_id(cov$month), cov$file_type)), ]
  cov <- lamp_flag_partial(cov)
  cov <- lamp_apply_changelog(cov, changelog)
  present <- function(ft) {
    sub <- cov[cov$file_type == ft, ]
    key <- lamp_key(sub$force_id, sub$month)
    usable <- sub$status %in% c("submitted", "refreshed", "partial_suspected", "not_read")
    stats::setNames(usable, key)
  }
  key <- lamp_key(cov$force_id, cov$month)
  has_street <- present("street")
  has_stops <- present("stop-and-search")
  # mismatch is assessable only when both file types are in the audit
  cov$mismatch <- NA
  if (length(has_street) > 0L && length(has_stops) > 0L) {
    s <- has_street[key]
    p <- has_stops[key]
    s[is.na(s)] <- FALSE
    p[is.na(p)] <- FALSE
    cov$mismatch <- as.logical(s != p)
  }
  cov <- cov[order(cov$file_type, cov$force_id, cov$month), ]
  cov <- cov[, c(
    "force_id", "month", "file_type", "status", "n_records", "archive",
    "n_versions", "versions_differ", "note", "mismatch"
  )]
  class(cov) <- c("lamp_coverage", class(cov))
  cov
}

#' Coverage audit: which force-months exist, and can be compared
#'
#' `lamp_coverage()` returns the force by month by file-type grid behind a
#' panel or a records table, with one status per cell (`submitted`,
#' `missing`, `not_read`, `refreshed`, `partial_suspected`), the record count,
#' the archive version used, any changelog note, and a `mismatch` flag for
#' months where a stop-and-search file exists without a street file or the
#' reverse. Its `plot()` method draws the grid as a heat map.
#'
#' `lamp_coverage_compare()` summarises comparability per force between two
#' periods: the share of months with usable files, and whether every month
#' in both periods was submitted without refreshes, partial submissions or
#' mismatches.
#'
#' @param x A `lamp_panel` from [lamp_panel()] or records from
#'   [lamp_read_crime()], [lamp_read_outcomes()] or
#'   [lamp_read_stop_counts()].
#' @param changelog Optional [lamp_changelog()] table; entries saying a force
#'   re-supplied months mark those months `refreshed`.
#'
#' @return `lamp_coverage()` returns a tibble of class `lamp_coverage` with
#'   columns `force_id`, `month`, `file_type`, `status`, `n_records`,
#'   `archive`, `n_versions`, `versions_differ`, `note` and `mismatch`.
#' @family panel
#' @export
#' @examples
#' panel <- lamp_sample_panel()
#' cov <- lamp_coverage(panel)
#' cov
#' table(cov$file_type, cov$status)
#' # Dyfed-Powys stopped submitting stop-and-search files in December 2025
#' cov[cov$mismatch %in% TRUE, c("force_id", "month", "file_type", "status")]
lamp_coverage <- function(x, changelog = NULL) {
  contract <- lamp_contract(x)
  cov <- contract$coverage
  if (is.null(cov) || nrow(cov) == 0L) {
    lamp_abort("{.arg x} carries no coverage information.", "contract")
  }
  if (inherits(cov, "lamp_coverage") && is.null(changelog)) {
    return(cov)
  }
  types <- split(cov, cov$file_type)
  lamp_coverage_table(
    street = types[["street"]], outcomes = types[["outcomes"]],
    stops = types[["stop-and-search"]], changelog = changelog
  )
}

#' @rdname lamp_coverage
#' @param coverage A `lamp_coverage` table.
#' @param period_a,period_b Two periods, each a length-two vector of months
#'   (`"YYYY-MM"` or Dates) giving the first and last month inclusive.
#' @param file_type Which file type to compare (default `"street"`).
#'
#' @return `lamp_coverage_compare()` returns a tibble with one row per force:
#'   `n_months_a`, `n_usable_a`, `n_months_b`, `n_usable_b` (months with
#'   status `submitted` or `refreshed`), `n_partial_a`, `n_partial_b`,
#'   `n_refreshed_a`, `n_refreshed_b`, `n_mismatch_a`, `n_mismatch_b` and
#'   `comparable` (`TRUE` when every month in both periods is `submitted`,
#'   with no mismatch).
#' @export
#' @examples
#' lamp_coverage_compare(cov, c("2024-08", "2025-07"), c("2025-08", "2026-07"),
#'   file_type = "stop-and-search"
#' )
lamp_coverage_compare <- function(coverage, period_a, period_b, file_type = "street") {
  if (!inherits(coverage, "lamp_coverage")) {
    lamp_abort("{.arg coverage} must come from {.fn lamp_coverage}.", "input")
  }
  check_string(file_type)
  a <- lamp_as_months(period_a)
  b <- lamp_as_months(period_b)
  if (length(a) != 2L || length(b) != 2L || a[1] > a[2] || b[1] > b[2]) {
    lamp_abort(
      "{.arg period_a} and {.arg period_b} must each give a first and last month.",
      "input"
    )
  }
  cov <- coverage[coverage$file_type == file_type, ]
  if (nrow(cov) == 0L) {
    lamp_abort("No {.val {file_type}} coverage in {.arg coverage}.", "input")
  }
  summarise_period <- function(sub, p) {
    inp <- sub[sub$month >= p[1] & sub$month <= p[2], ]
    n_months <- lamp_months_between(p[1], p[2])
    clean <- nrow(inp) == n_months && all(inp$status == "submitted")
    clean <- clean && !any(inp$mismatch %in% TRUE)
    list(
      n_months = n_months,
      n_usable = sum(inp$status %in% c("submitted", "refreshed")),
      n_partial = sum(inp$status == "partial_suspected"),
      n_refreshed = sum(inp$status == "refreshed"),
      n_mismatch = sum(inp$mismatch %in% TRUE),
      clean = clean
    )
  }
  rows <- lapply(split(cov, cov$force_id), function(sub) {
    sa <- summarise_period(sub, a)
    sb <- summarise_period(sub, b)
    tibble::tibble(
      force_id = sub$force_id[1],
      n_months_a = sa$n_months, n_usable_a = sa$n_usable,
      n_months_b = sb$n_months, n_usable_b = sb$n_usable,
      n_partial_a = sa$n_partial, n_partial_b = sb$n_partial,
      n_refreshed_a = sa$n_refreshed, n_refreshed_b = sb$n_refreshed,
      n_mismatch_a = sa$n_mismatch, n_mismatch_b = sb$n_mismatch,
      comparable = sa$clean && sb$clean
    )
  })
  dplyr::bind_rows(rows)
}

#' @export
print.lamp_coverage <- function(x, ...) {
  n_force <- length(unique(x$force_id))
  n_type <- length(unique(x$file_type))
  n_mis <- sum(x$mismatch %in% TRUE)
  cli::cli_text(
    "{.strong streetlamp coverage}: {n_force} force{?s}, {n_type} file type{?s}, ",
    "{n_mis} mismatched force-month{?s}."
  )
  NextMethod()
}

#' @export
plot.lamp_coverage <- function(x, y = NULL, ...) {
  levels_status <- c("submitted", "refreshed", "partial_suspected", "not_read", "missing")
  d <- tibble::as_tibble(x)
  d$status <- factor(d$status, levels = levels_status)
  ggplot2::ggplot(d, ggplot2::aes(x = .data$month, y = .data$force_id, fill = .data$status)) +
    ggplot2::geom_tile(colour = "white", linewidth = 0.2) +
    ggplot2::facet_wrap(ggplot2::vars(.data$file_type), ncol = 1) +
    ggplot2::scale_fill_manual(
      values = c(
        submitted = "#2a6f97", refreshed = "#61a5c2", partial_suspected = "#e9c46a",
        not_read = "#cccccc", missing = "#e76f51"
      ),
      drop = FALSE
    ) +
    ggplot2::labs(x = NULL, y = NULL, fill = "status") +
    ggplot2::theme_minimal()
}

# Changelog ---------------------------------------------------------------------

lamp_changelog_url <- function() "https://data.police.uk/changelog/"

#' The data.police.uk changelog as a table of refresh and gap notes
#'
#' Fetches and parses the publisher's changelog, which records when a force
#' re-supplied months ("data refresh") or failed to supply a month ("not
#' provided"). [lamp_coverage()] and [lamp_panel()] use it to mark
#' force-months as `refreshed` and to annotate gaps. The page is fetched once
#' and cached; pass `refresh = TRUE` to fetch it again.
#'
#' @inheritParams lamp_archive_index
#'
#' @return A tibble with columns `entry_month` (the changelog heading, a
#'   Date), `force_name`, `force_id`, `file_type` (`street`, `outcomes`,
#'   `stop-and-search`, a semicolon-separated combination, or `all`),
#'   `action` (`refresh` or `not_provided`), `from`, `to` (Dates, `NA` when
#'   the entry covers all months) and `text` (the entry as published).
#'   Entries that do not follow the refresh or gap patterns are kept with
#'   `action = NA`.
#' @family panel
#' @export
#' @examplesIf FALSE
#' # Requires network access
#' cl <- lamp_changelog()
#' cl[cl$force_id == "west-yorkshire", ]
lamp_changelog <- function(refresh = FALSE, dir = lamp_cache_dir()) {
  check_bool(refresh)
  adir <- lamp_archive_dir(dir)
  cache <- file.path(adir, "changelog.rds")
  if (!refresh && file.exists(cache)) {
    return(readRDS(cache))
  }
  html <- rlang::try_fetch(
    lamp_http_get_text(lamp_changelog_url()),
    streetlamp_error_network = function(e) {
      if (file.exists(cache)) {
        lamp_warn("Using the cached changelog because the page could not be fetched.", "network")
        return(NULL)
      }
      rlang::cnd_signal(e)
    }
  )
  if (is.null(html)) {
    return(readRDS(cache))
  }
  out <- lamp_parse_changelog(html)
  attr(out, "fetched_at") <- Sys.time()
  dir.create(adir, recursive = TRUE, showWarnings = FALSE)
  saveRDS(out, cache)
  out
}

lamp_month_names <- c(
  january = 1, february = 2, march = 3, april = 4, may = 5, june = 6, july = 7,
  august = 8, september = 9, october = 10, november = 11, december = 12,
  jan = 1, feb = 2, mar = 3, apr = 4, jun = 6, jul = 7, aug = 8, sep = 9,
  sept = 9, oct = 10, nov = 11, dec = 12
)

# "March 2012", "Sept 2012" -> Date
lamp_parse_month_words <- function(x) {
  x <- tolower(trimws(x))
  parts <- strsplit(x, "\\s+")
  vapply(parts, function(p) {
    if (length(p) != 2L || !p[1] %in% names(lamp_month_names) || !grepl("^[0-9]{4}$", p[2])) {
      return(NA_real_)
    }
    as.numeric(as.Date(sprintf("%s-%02d-01", p[2], lamp_month_names[[p[1]]])))
  }, numeric(1)) |>
    as.Date(origin = "1970-01-01")
}

lamp_parse_changelog <- function(html) {
  text <- gsub("<[^>]+>", "\n", html)
  lines <- trimws(strsplit(text, "\n", fixed = TRUE)[[1]])
  lines <- lines[nzchar(lines)]
  month_words <- c(
    "January", "February", "March", "April", "May", "June", "July", "August",
    "September", "October", "November", "December"
  )
  heading_re <- paste0("^(", paste(month_words, collapse = "|"), ") [0-9]{4}$")
  heading <- grepl(heading_re, lines)
  entry_month <- as.Date(NA)
  current <- as.Date(NA)
  rows <- list()
  month_re <- "[A-Za-z]{3,9} [0-9]{4}"
  for (i in seq_along(lines)) {
    if (heading[i]) {
      current <- lamp_parse_month_words(lines[i])
      next
    }
    line <- lines[i]
    if (!grepl("^[A-Za-z' &-]+: ", line)) next
    force_name <- sub(":.*$", "", line)
    force_id <- lamp_force_id_from_name(force_name)
    body <- sub("^[^:]+: ", "", line)
    lower <- tolower(body)
    file_type <- if (grepl("^crime and outcome", lower)) {
      "street;outcomes"
    } else if (grepl("^crime", lower)) {
      "street"
    } else if (grepl("^outcome", lower)) {
      "outcomes"
    } else if (grepl("^stop and search", lower)) {
      "stop-and-search"
    } else {
      NA_character_
    }
    # "not provided" entries also promise a future refresh, so test them first
    action <- if (grepl("not provided", lower)) {
      "not_provided"
    } else if (grepl("data refresh", lower)) {
      "refresh"
    } else {
      NA_character_
    }
    if (is.na(action)) {
      rows[[length(rows) + 1L]] <- tibble::tibble(
        entry_month = current, force_name = force_name, force_id = force_id,
        file_type = file_type, action = NA_character_, from = as.Date(NA),
        to = as.Date(NA), text = line
      )
      next
    }
    all_months <- grepl("all months", lower)
    ranges <- regmatches(body, gregexpr(paste0(month_re, " to ", month_re), body))[[1]]
    single_re <- paste0("(for|from) ", month_re, "(?! to)")
    singles <- regmatches(body, gregexpr(single_re, body, perl = TRUE))[[1]]
    spans <- list()
    for (r in ranges) {
      m <- regmatches(r, gregexpr(month_re, r))[[1]]
      spans[[length(spans) + 1L]] <- lamp_parse_month_words(m)
    }
    for (s in singles) {
      m <- regmatches(s, gregexpr(month_re, s))[[1]]
      d <- lamp_parse_month_words(m[1])
      spans[[length(spans) + 1L]] <- c(d, d)
    }
    if (all_months || length(spans) == 0L) {
      spans <- list(as.Date(c(NA, NA)))
    }
    for (sp in spans) {
      rows[[length(rows) + 1L]] <- tibble::tibble(
        entry_month = current, force_name = force_name, force_id = force_id,
        file_type = if (is.na(file_type)) "all" else file_type, action = action,
        from = sp[1], to = sp[2], text = line
      )
    }
  }
  out <- dplyr::bind_rows(rows)
  if (nrow(out) == 0L) {
    lamp_abort(
      c(
        "No entries were found on the data.police.uk changelog page.",
        "i" = "The page layout may have changed; please report this."
      ),
      "network"
    )
  }
  out
}

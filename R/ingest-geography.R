# LSOA vintage detection ------------------------------------------------------------
#
# data.police.uk switched the LSOA field from 2011 to 2021 boundaries in June
# 2023, but archive snapshots keep every month at the vintage it was first
# published with, so one archive can hold both. About 3 percent of codes exist
# in only one vintage, which is enough to decide the vintage of any file with a
# few hundred distinct codes; tiny files fall back to the publication month.

lamp_vintage_sets <- function() {
  if (is.null(the$vintage_sets)) {
    c11 <- lamp_lsoa_codes("lsoa11")
    c21 <- lamp_lsoa_codes("lsoa21")
    the$vintage_sets <- list(
      only11 = setdiff(c11, c21),
      only21 = setdiff(c21, c11),
      all = union(c11, c21)
    )
  }
  the$vintage_sets
}

lamp_vintage_counts <- function(codes) {
  sets <- lamp_vintage_sets()
  codes <- unique(codes[!is.na(codes)])
  n_only11 <- sum(codes %in% sets$only11)
  n_only21 <- sum(codes %in% sets$only21)
  n_unknown <- sum(!codes %in% sets$all)
  list(
    n_codes = length(codes), n_only_2011 = n_only11, n_only_2021 = n_only21,
    n_both = length(codes) - n_only11 - n_only21 - n_unknown, n_unknown = n_unknown
  )
}

lamp_vintage_switch_month <- function() as.Date("2023-06-01")

lamp_vintage_decide <- function(counts, month = NULL) {
  vintage <- if (counts$n_only_2011 > 0L && counts$n_only_2021 == 0L) {
    "lsoa11"
  } else if (counts$n_only_2021 > 0L && counts$n_only_2011 == 0L) {
    "lsoa21"
  } else if (counts$n_only_2011 > 0L && counts$n_only_2021 > 0L) {
    "mixed"
  } else {
    "ambiguous"
  }
  basis <- "codes"
  if (vintage == "ambiguous" && !is.null(month) && !is.na(month)) {
    vintage <- if (month >= lamp_vintage_switch_month()) "lsoa21" else "lsoa11"
    basis <- "month"
  }
  c(counts, list(vintage = vintage, basis = basis))
}

#' Detect whether LSOA codes are 2011 or 2021 vintage
#'
#' Matches codes against the bundled ONS code lists ([lamp_lsoa_codes()]).
#' Codes that exist in only one vintage decide the answer; when a file has
#' none of those (possible for very small forces), the publication month
#' decides, because data.police.uk moved to 2021 codes with the June 2023 data.
#'
#' @param x A character vector of LSOA codes, or a records table from
#'   [lamp_read_crime()] or [lamp_read_outcomes()] (which is assessed one file
#'   at a time).
#' @param month Optional month (Date or `"YYYY-MM"`) used only when the codes
#'   are ambiguous and `x` is a character vector.
#'
#' @return A tibble with one row per file (or one row for a vector) and
#'   columns `vintage` (`"lsoa11"`, `"lsoa21"`, `"mixed"` or `"ambiguous"`),
#'   `basis` (`"codes"` or `"month"`), `n_codes`, `n_only_2011`,
#'   `n_only_2021`, `n_both` and `n_unknown`, preceded by `archive`, `file`,
#'   `force_id` and `month` for records.
#' @family ingest
#' @export
#' @examples
#' lamp_lsoa_vintage(c("E01000001", "E01000002", "E01035000"))
#' lamp_lsoa_vintage(c("E01000001", "E01000002"), month = "2024-01")
lamp_lsoa_vintage <- function(x, month = NULL) {
  if (is.data.frame(x)) {
    if (!"lsoa_code" %in% names(x)) {
      lamp_abort("{.arg x} must have an {.field lsoa_code} column.", "input")
    }
    if (all(c("archive", "file") %in% names(x))) {
      groups <- split(seq_len(nrow(x)), paste(x$archive, x$file, sep = "\r"))
    } else {
      groups <- list(all = seq_len(nrow(x)))
    }
    rows <- lapply(groups, function(idx) {
      part <- x[idx, ]
      mo <- if ("month" %in% names(part)) min(part$month, na.rm = TRUE) else NULL
      d <- lamp_vintage_decide(lamp_vintage_counts(part$lsoa_code), mo)
      tibble::tibble(
        archive = if ("archive" %in% names(part)) part$archive[1] else NA_character_,
        file = if ("file" %in% names(part)) part$file[1] else NA_character_,
        force_id = if ("force_id" %in% names(part)) part$force_id[1] else NA_character_,
        month = if (is.null(mo)) as.Date(NA) else mo,
        vintage = d$vintage, basis = d$basis, n_codes = d$n_codes,
        n_only_2011 = d$n_only_2011, n_only_2021 = d$n_only_2021,
        n_both = d$n_both, n_unknown = d$n_unknown
      )
    })
    out <- dplyr::bind_rows(rows)
    return(out[order(out$force_id, out$month, out$archive), ])
  }
  if (!is.character(x)) {
    lamp_abort("{.arg x} must be a character vector of LSOA codes or a records table.", "input")
  }
  month <- if (is.null(month)) NULL else lamp_as_months(month)
  d <- lamp_vintage_decide(lamp_vintage_counts(x), month)
  tibble::tibble(
    vintage = d$vintage, basis = d$basis, n_codes = d$n_codes,
    n_only_2011 = d$n_only_2011, n_only_2021 = d$n_only_2021,
    n_both = d$n_both, n_unknown = d$n_unknown
  )
}

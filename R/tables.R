# Presentation tables. `tidy()` returns the numbers; `lamp_table()` returns
# the same numbers formatted for a reader, with terms in words, intervals in
# brackets and p values rounded the way a journal would print them. The print
# methods and the report builder both draw on it.

#' A presentation-ready table from a streetlamp object
#'
#' Formats an estimate, a diagnostic or a coverage audit as a tibble of
#' character columns with readable headers, rounded figures, confidence
#' intervals in brackets and p values as `<0.001` where they are that small.
#' The result is meant to be passed to `knitr::kable()` or a similar table
#' renderer; the unrounded numbers remain available from [tidy()] and from
#' the object itself.
#'
#' @param x An estimate from any of the package's estimators, a
#'   [lamp_pretrends()] result, a [lamp_synth()] fit, or a [lamp_coverage()]
#'   audit.
#' @param digits Significant figures for estimates and intervals.
#' @param ... Unused.
#'
#' @return A tibble of character columns. For estimates: the term, the
#'   estimate, its standard error, the 95 percent confidence interval and the
#'   p value. Event studies and staggered fits show months relative to the
#'   event in place of the term. For a pre-trend diagnostic: the power table.
#'   For a synthetic control: donor weights. For a coverage audit: counts of
#'   force-months by file type and status.
#' @family presentation
#' @export
#' @examples
#' sim <- lamp_simulate(n_areas = 24, n_months = 24, design = "event", effect = -0.2, seed = 2)
#' truth <- attr(sim, "truth")
#' tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
#' lamp_table(lamp_twfe(sim, "crime_total", tr))
#' lamp_table(lamp_coverage(sim))
lamp_table <- function(x, ...) {
  UseMethod("lamp_table")
}

#' @rdname lamp_table
#' @export
lamp_table.lamp_estimate <- function(x, digits = 3, ...) {
  d <- x$coefficients
  lamp_coefficient_table(d, first = lamp_pretty_term(d$term), header = "Term", digits = digits)
}

#' @rdname lamp_table
#' @export
lamp_table.lamp_event_study <- function(x, digits = 3, ...) {
  d <- x$coefficients
  first <- lamp_relative_time_label(d$rel_time, x$meta$reference)
  lamp_coefficient_table(d, first = first, header = "Months since event", digits = digits)
}

#' @rdname lamp_table
#' @export
lamp_table.lamp_did_staggered <- function(x, digits = 3, ...) {
  d <- x$coefficients
  if (nrow(d) == 0L) {
    return(lamp_coefficient_table(d, first = character(), header = "Months since adoption"))
  }
  ref <- d$rel_time[is.na(d$std_error) | d$std_error == 0]
  first <- lamp_relative_time_label(d$rel_time, if (length(ref)) ref[1] else NA)
  lamp_coefficient_table(d, first = first, header = "Months since adoption", digits = digits)
}

#' @rdname lamp_table
#' @export
lamp_table.lamp_pretrends <- function(x, digits = 3, ...) {
  p <- x$power
  if (is.null(p)) {
    return(tibble::tibble(Power = character(), `Detectable slope` = character()))
  }
  tibble::tibble(
    Power = lamp_fmt_num(p$power, digits),
    `Detectable slope per month` = lamp_fmt_num(p$slope, digits),
    `Bias it would leave in the mean post-period effect` = lamp_fmt_num(p$bias_mean_post, digits)
  )
}

#' @rdname lamp_table
#' @export
lamp_table.lamp_synth <- function(x, digits = 3, ...) {
  w <- x$weights
  w <- w[order(-w)]
  w <- w[w > 0]
  tibble::tibble(
    Donor = names(w),
    Weight = lamp_fmt_num(unname(w), digits)
  )
}

#' @rdname lamp_table
#' @export
lamp_table.lamp_coverage <- function(x, ...) {
  d <- tibble::as_tibble(x)
  status <- factor(d$status, levels = lamp_status_levels())
  tab <- table(d$file_type, status)
  present <- colSums(tab) > 0
  out <- tibble::tibble(`File type` = lamp_file_type_label(rownames(tab)))
  for (s in colnames(tab)[present]) {
    out[[lamp_status_label(s)]] <- lamp_label_number(as.integer(tab[, s]))
  }
  out
}

# Shared body for every coefficient table.
lamp_coefficient_table <- function(d, first, header, digits = 3) {
  out <- tibble::tibble(x = first)
  names(out) <- header
  out$Estimate <- lamp_fmt_num(d$estimate, digits)
  out$`Std. error` <- lamp_fmt_num(d$std_error, digits)
  out$`95% CI` <- lamp_fmt_interval(d$conf_low, d$conf_high, digits)
  out$p <- lamp_fmt_p(d$p_value)
  out
}

lamp_relative_time_label <- function(rel_time, reference) {
  out <- as.character(rel_time)
  if (!is.na(reference)) out[rel_time == reference] <- paste(reference, "(reference)")
  out
}

# Number formatting -------------------------------------------------------------------

# A true minus sign and a box-drawing rule where the session can show them;
# plain ASCII otherwise, so a Latin-1 console never prints question marks.
lamp_utf8 <- function() {
  isTRUE(l10n_info()[["UTF-8"]])
}

lamp_fmt_num <- function(x, digits = 3) {
  out <- formatC(signif(x, digits), digits = digits, format = "g", flag = "#")
  out <- sub("\\.$", "", out)
  out <- sub("(\\.[0-9]*?)0+$", "\\1", out)
  out <- sub("\\.$", "", out)
  out <- trimws(out)
  if (lamp_utf8()) out <- gsub("^-", "\u2212", out)
  out[is.na(x)] <- ""
  out
}

lamp_fmt_interval <- function(lo, hi, digits = 3) {
  out <- sprintf("[%s, %s]", lamp_fmt_num(lo, digits), lamp_fmt_num(hi, digits))
  out[is.na(lo) | is.na(hi)] <- ""
  out
}

lamp_fmt_p <- function(p) {
  out <- ifelse(p < 0.001, "<0.001", formatC(p, digits = 3, format = "f"))
  out[is.na(p)] <- ""
  out
}

# "p = 0.078" or "p < 0.001", for prose and subtitles.
lamp_fmt_p_phrase <- function(p) {
  out <- lamp_fmt_p(p)
  ifelse(startsWith(out, "<"), paste("p <", substring(out, 2)), paste("p =", out))
}

# Console rendering: a plain aligned table with the first column flush left
# and the figures flush right, written to standard output like the data
# frame it replaces.
lamp_print_table <- function(tbl, indent = "  ") {
  df <- as.data.frame(tbl, stringsAsFactors = FALSE)
  if (nrow(df) == 0L) {
    cat(indent, "(no rows)\n", sep = "")
    return(invisible(tbl))
  }
  cols <- lapply(seq_along(df), function(i) {
    v <- c(names(df)[i], as.character(df[[i]]))
    v[is.na(v)] <- ""
    w <- max(nchar(v, type = "width"))
    pad <- w - nchar(v, type = "width")
    if (i == 1L) paste0(v, strrep(" ", pad)) else paste0(strrep(" ", pad), v)
  })
  lines <- do.call(paste, c(cols, sep = "  "))
  dash <- if (lamp_utf8()) "\u2500" else "-"
  rule <- paste(vapply(cols, function(v) strrep(dash, nchar(v[1], type = "width")), ""),
    collapse = "  "
  )
  cat(paste0(indent, c(lines[1], rule, lines[-1])), sep = "\n")
  invisible(tbl)
}

# Markdown rendering for the report.
lamp_md_table <- function(tbl) {
  df <- as.data.frame(tbl, stringsAsFactors = FALSE)
  cells <- lapply(df, function(col) {
    col <- as.character(col)
    col[is.na(col)] <- ""
    gsub("|", "\\|", col, fixed = TRUE)
  })
  header <- paste("|", paste(names(df), collapse = " | "), "|")
  align <- c("---", rep("---:", max(length(df) - 1L, 0L)))
  rule <- paste("|", paste(align, collapse = " | "), "|")
  rows <- vapply(seq_len(nrow(df)), function(i) {
    paste("|", paste(vapply(cells, function(col) col[i], character(1)), collapse = " | "), "|")
  }, character(1))
  c(header, rule, rows)
}

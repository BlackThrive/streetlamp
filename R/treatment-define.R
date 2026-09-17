# Treatment definitions ---------------------------------------------------------------

new_lamp_treatment <- function(type, column, data, details = list(),
                               n_treated_areas = NA_integer_, n_control_areas = NA_integer_) {
  structure(
    list(
      type = type,
      column = column,
      data = data,
      details = details,
      n_treated_areas = n_treated_areas,
      n_control_areas = n_control_areas,
      created = Sys.time()
    ),
    class = "lamp_treatment"
  )
}

#' @export
print.lamp_treatment <- function(x, ...) {
  cli::cli_h3("streetlamp treatment")
  cli::cli_text("Type: {.val {x$type}}; column {.field {x$column}}")
  if (!is.na(x$n_treated_areas)) {
    cli::cli_text("Areas: {x$n_treated_areas} treated, {x$n_control_areas} control")
  }
  d <- x$details
  if (!is.null(d$measure)) {
    cli::cli_text("Measure: {d$measure}, transform {d$transform}")
  }
  if (!is.null(d$event_name)) {
    cli::cli_text(
      "Event: {d$event_name} on {d$event_date}, ",
      "window {d$window[1]} to {d$window[2]} months"
    )
  }
  if (!is.null(d$n_cohorts)) {
    cli::cli_text("Cohorts: {d$n_cohorts}, adoption {d$first_adoption} to {d$last_adoption}")
  }
  if (!is.null(d$never_treated)) {
    cli::cli_text("Never-treated areas: {d$never_treated}")
  }
  invisible(x)
}

lamp_check_panel <- function(x, arg = rlang::caller_arg(x), call = rlang::caller_env()) {
  if (!inherits(x, "lamp_panel")) {
    lamp_abort("{.arg {arg}} must be a panel from {.fn lamp_panel}.", "input", call = call)
  }
  if (!all(c("area", "month") %in% names(x))) {
    lamp_abort(
      "{.arg {arg}} lacks the {.field area} or {.field month} column.",
      "input",
      call = call
    )
  }
  lamp_contract(x)
}

lamp_treatment_measures <- function() c("stops", "stop_rate", "stops_per_100_crimes")
lamp_treatment_transforms <- function() c("identity", "log", "ihs")

lamp_apply_transform <- function(x, transform) {
  switch(transform,
    identity = x,
    log = log1p(x),
    ihs = asinh(x)
  )
}

# Stops per 100 crimes recorded in the previous twelve months, an intensity
# measure that is not mechanically driven by population.
lamp_stops_per_100_crimes <- function(panel) {
  d <- panel[order(panel$area, panel$month), c("area", "month", "stops", "crime_total")]
  d$prior <- NA_real_
  idx <- split(seq_len(nrow(d)), d$area)
  for (rows in idx) {
    crime <- d$crime_total[rows]
    roll <- rep(NA_real_, length(rows))
    for (i in seq_along(rows)) {
      back <- seq(max(1L, i - 12L), i - 1L)
      if (i > 1L && any(!is.na(crime[back]))) {
        roll[i] <- sum(crime[back], na.rm = TRUE)
      }
    }
    d$prior[rows] <- roll
  }
  out <- 100 * d$stops / d$prior
  out[is.finite(out) == FALSE] <- NA_real_
  out[match(paste(panel$area, panel$month), paste(d$area, d$month))]
}

#' Define the treatment
#'
#' Turns a panel into a treatment definition that the estimators can use: a
#' continuous stop intensity, a binary intervention in named areas and months,
#' staggered adoption dates by area, or a dated event applied to every area.
#' The result records how the treatment was built, is stored in the contract
#' of every estimate made with it, and is printed by the estimators alongside
#' their identifying assumption.
#'
#' @details
#' Types:
#' * `continuous`: `measure` is `"stops"`, `"stop_rate"` (per 1,000
#'   residents, the default) or `"stops_per_100_crimes"` (searches per 100
#'   crimes recorded in the area's previous twelve months, which removes the
#'   mechanical dependence on population). `transform` is `"identity"`,
#'   `"log"` (log of one plus the measure) or `"ihs"` (inverse hyperbolic
#'   sine, which handles zeros).
#' * `binary`: `areas` are treated during `window`, a pair of months, and
#'   untreated outside it; every other area is a control.
#' * `staggered`: `adoption` is a table of `area` and `adoption_month`. Areas
#'   absent from it are never treated. `rel_time` (months since adoption) and
#'   `cohort` are added.
#' * `event`: a dated shock applied to every area in scope, from
#'   [lamp_shocks()] by `event` name or from `date`, with an event `window`
#'   in months around it. `rel_time` is months since the event.
#'
#' A continuous treatment is a dose, not an experiment: the allocation of
#' searches to areas responds to crime, so estimates from it describe an
#' association unless the variation is argued to be exogenous. See
#' `lamp_allocation()`.
#'
#' @param panel A `lamp_panel` from [lamp_panel()].
#' @param type `"continuous"`, `"binary"`, `"staggered"` or `"event"`.
#' @param measure,transform For `continuous`: which intensity and which
#'   transformation.
#' @param areas For `binary`: the treated areas.
#' @param window For `binary`: the first and last treated month. For `event`:
#'   the event window in months, default `c(-12, 12)`.
#' @param adoption For `staggered`: a table with columns `area` and
#'   `adoption_month`.
#' @param event For `event`: a name in [lamp_shocks()], or `NULL` when `date`
#'   is given.
#' @param date For `event`: the event month, overriding the shocks table.
#' @param scope For `event`: areas the event applies to; `NULL` for all.
#'
#' @return A `lamp_treatment` object: a list with `type`, `column` (the
#'   treatment variable's name), `data` (area, month, the treatment column
#'   and, where applicable, `rel_time` and `cohort`), `details`,
#'   `n_treated_areas`, `n_control_areas` and `created`.
#' @family treatment
#' @export
#' @examples
#' sim <- lamp_simulate(n_areas = 16, n_months = 18, design = "event", seed = 1)
#'
#' # a dated event, twelve months either side
#' lamp_treatment(sim, "event", date = "2018-10", window = c(-6, 6))
#'
#' # stop intensity as a continuous dose
#' lamp_treatment(sim, "continuous", measure = "stop_rate", transform = "ihs")
#'
#' # a surge in named areas
#' lamp_treatment(sim, "binary", areas = unique(sim$area)[1:4], window = c("2018-06", "2018-12"))
lamp_treatment <- function(panel, type = c("continuous", "binary", "staggered", "event"),
                           measure = c("stop_rate", "stops", "stops_per_100_crimes"),
                           transform = c("identity", "log", "ihs"),
                           areas = NULL, window = NULL, adoption = NULL,
                           event = NULL, date = NULL, scope = NULL) {
  type <- rlang::arg_match(type)
  lamp_check_panel(panel)
  base <- panel[, c("area", "month")]
  base$rel_time <- NA_integer_
  base$cohort <- as.Date(NA)

  if (type == "continuous") {
    measure <- rlang::arg_match(measure)
    transform <- rlang::arg_match(transform)
    raw <- switch(measure,
      stops = panel$stops,
      stop_rate = panel$stop_rate,
      stops_per_100_crimes = lamp_stops_per_100_crimes(panel)
    )
    if (is.null(raw)) {
      lamp_abort("The panel has no {.field {measure}} column.", "input")
    }
    base$treat <- lamp_apply_transform(as.numeric(raw), transform)
    details <- list(
      measure = measure, transform = transform,
      n_missing = sum(is.na(base$treat)),
      mean = mean(base$treat, na.rm = TRUE)
    )
    n_treated <- sum(tapply(base$treat, base$area, function(x) any(x > 0, na.rm = TRUE)))
    return(new_lamp_treatment(
      "continuous", "treat", base, details,
      n_treated_areas = n_treated,
      n_control_areas = length(unique(base$area)) - n_treated
    ))
  }

  if (type == "binary") {
    if (is.null(areas) || !is.character(areas)) {
      lamp_abort("{.arg areas} must name the treated areas.", "input")
    }
    if (is.null(window) || length(window) != 2L) {
      lamp_abort("{.arg window} must give the first and last treated month.", "input")
    }
    w <- lamp_as_months(window)
    unknown <- setdiff(areas, panel$area)
    if (length(unknown) > 0L) {
      lamp_abort("{length(unknown)} area{?s} in {.arg areas} {?is/are} not in the panel.", "input")
    }
    base$treat <- as.numeric(base$area %in% areas & base$month >= w[1] & base$month <= w[2])
    since <- lamp_months_between(w[1], base$month) - 1L
    base$rel_time <- ifelse(base$area %in% areas, since, NA_integer_)
    base$cohort <- as.Date(ifelse(base$area %in% areas, w[1], NA))
    details <- list(
      window = w, n_treated_months = sum(base$treat > 0),
      never_treated = length(setdiff(unique(panel$area), areas))
    )
    return(new_lamp_treatment(
      "binary", "treat", base, details,
      n_treated_areas = length(intersect(areas, panel$area)),
      n_control_areas = length(setdiff(unique(panel$area), areas))
    ))
  }

  if (type == "staggered") {
    if (!is.data.frame(adoption) || !all(c("area", "adoption_month") %in% names(adoption))) {
      lamp_abort(
        "{.arg adoption} must have columns {.field area} and {.field adoption_month}.",
        "input"
      )
    }
    ad <- tibble::tibble(
      area = as.character(adoption$area),
      adoption_month = lamp_as_months(adoption$adoption_month)
    )
    ad <- ad[!is.na(ad$adoption_month) & ad$area %in% panel$area, ]
    if (nrow(ad) == 0L) {
      lamp_abort("No area in {.arg adoption} is in the panel.", "input")
    }
    idx <- match(base$area, ad$area)
    start <- ad$adoption_month[idx]
    base$treat <- as.numeric(!is.na(start) & base$month >= start)
    base$rel_time <- ifelse(is.na(start), NA_integer_, lamp_months_between(start, base$month) - 1L)
    base$cohort <- start
    details <- list(
      n_cohorts = length(unique(ad$adoption_month)),
      first_adoption = min(ad$adoption_month),
      last_adoption = max(ad$adoption_month),
      never_treated = length(setdiff(unique(panel$area), ad$area)),
      adoption = ad
    )
    return(new_lamp_treatment(
      "staggered", "treat", base, details,
      n_treated_areas = nrow(ad),
      n_control_areas = length(setdiff(unique(panel$area), ad$area))
    ))
  }

  # event
  window <- window %||% c(-12, 12)
  if (length(window) != 2L || window[1] > window[2]) {
    lamp_abort("{.arg window} must give the first and last relative month.", "input")
  }
  if (is.null(date)) {
    if (is.null(event)) {
      lamp_abort("Give {.arg event} (a name in {.fn lamp_shocks}) or {.arg date}.", "input")
    }
    shocks <- lamp_shocks()
    hit <- shocks[shocks$name == event, ]
    if (nrow(hit) != 1L) {
      lamp_abort("{.val {event}} is not a single row of {.fn lamp_shocks}.", "input")
    }
    date <- hit$start
    event_name <- hit$label
  } else {
    event_name <- event %||% "user-supplied event"
  }
  d <- lamp_as_months(date)
  in_scope <- if (is.null(scope)) rep(TRUE, nrow(base)) else base$area %in% scope
  rel <- lamp_months_between(d, base$month) - 1L
  base$treat <- as.numeric(in_scope & base$month >= d)
  base$rel_time <- ifelse(in_scope, rel, NA_integer_)
  base$cohort <- as.Date(ifelse(in_scope, d, NA))
  details <- list(
    event_name = event_name, event_date = d, window = as.integer(window),
    n_scope_areas = length(unique(base$area[in_scope])),
    months_before = sum(rel < 0 & in_scope), months_after = sum(rel >= 0 & in_scope)
  )
  new_lamp_treatment(
    "event", "treat", base, details,
    n_treated_areas = length(unique(base$area[in_scope])),
    n_control_areas = length(unique(base$area[!in_scope]))
  )
}

#' Detect surges in stop and search activity
#'
#' Flags area-months in which searches rise far above the area's recent level,
#' and returns them as a candidate staggered-adoption table. Two methods are
#' offered: a threshold of `k` standard deviations above the area's trailing
#' twelve-month mean, and a structural break test from `strucchange`.
#'
#' @section Endogeneity:
#' A surge detected from the stop series is not an experiment. Police deploy
#' searches where crime has risen, so an area's first surge month is
#' correlated with its recent crime history and with anything else that
#' prompted the deployment. Treating a detected surge as exogenous will
#' mistake the response for the cause. Use this to explore where activity
#' changed and to pick candidate cases for a design with an external source
#' of variation, not as the primary design; and read
#' `lamp_allocation()` alongside any estimate that uses it.
#'
#' @param panel A `lamp_panel` with a `stops` column.
#' @param method `"threshold"` (default) or `"breakpoints"`.
#' @param k Threshold in standard deviations above the trailing mean.
#' @param min_months Months of history required before an area can be
#'   flagged.
#' @param min_stops Minimum searches in the month, so that tiny areas do not
#'   surge from one search to three.
#'
#' @return A tibble of class `lamp_surges` with one row per area:
#'   `area`, `adoption_month` (the first flagged month, `NA` if none),
#'   `n_flagged`, `trailing_mean`, `trailing_sd`, `peak_stops` and
#'   `peak_ratio` (peak over trailing mean). Pass it to
#'   [lamp_treatment()] as `adoption` for a staggered design. The attribute
#'   `flags` holds every flagged area-month.
#' @family treatment
#' @export
#' @examples
#' sim <- lamp_simulate(n_areas = 16, n_months = 30, design = "event", seed = 3)
#' surges <- lamp_detect_surges(sim, min_stops = 5)
#' head(surges)
lamp_detect_surges <- function(panel, method = c("threshold", "breakpoints"), k = 2,
                               min_months = 12L, min_stops = 3L) {
  method <- rlang::arg_match(method)
  lamp_check_panel(panel)
  if (!"stops" %in% names(panel)) {
    lamp_abort("The panel has no {.field stops} column.", "input")
  }
  if (method == "breakpoints" && !requireNamespace("strucchange", quietly = TRUE)) {
    lamp_abort(
      c(
        "Method {.val breakpoints} needs the {.pkg strucchange} package.",
        "i" = "Install it, or use {.code method = \"threshold\"}."
      ),
      "input"
    )
  }
  d <- panel[order(panel$area, panel$month), c("area", "month", "stops")]
  rows <- split(seq_len(nrow(d)), d$area)
  flags <- vector("list", length(rows))
  summary_rows <- vector("list", length(rows))
  for (i in seq_along(rows)) {
    idx <- rows[[i]]
    s <- as.numeric(d$stops[idx])
    m <- d$month[idx]
    trailing_mean <- rep(NA_real_, length(idx))
    trailing_sd <- rep(NA_real_, length(idx))
    for (j in seq_along(idx)) {
      back <- seq(max(1L, j - 12L), j - 1L)
      hist <- s[back]
      hist <- hist[!is.na(hist)]
      if (length(hist) >= min_months) {
        trailing_mean[j] <- mean(hist)
        trailing_sd[j] <- stats::sd(hist)
      }
    }
    flagged <- !is.na(s) & !is.na(trailing_mean) & !is.na(trailing_sd) &
      trailing_sd > 0 & s >= min_stops & s > trailing_mean + k * trailing_sd
    if (method == "breakpoints" && sum(!is.na(s)) >= 2 * min_months) {
      bp <- try(strucchange::breakpoints(s ~ 1, h = min_months), silent = TRUE)
      if (!inherits(bp, "try-error") && !all(is.na(bp$breakpoints))) {
        bk <- bp$breakpoints[!is.na(bp$breakpoints)]
        rise <- bk[vapply(bk, function(b) {
          mean(s[seq(b + 1L, length(s))], na.rm = TRUE) > mean(s[seq_len(b)], na.rm = TRUE)
        }, logical(1))]
        flagged <- flagged | seq_along(s) %in% (rise + 1L)
      }
    }
    flags[[i]] <- tibble::tibble(
      area = d$area[idx][flagged], month = m[flagged], stops = s[flagged],
      trailing_mean = trailing_mean[flagged], trailing_sd = trailing_sd[flagged]
    )
    summary_rows[[i]] <- tibble::tibble(
      area = d$area[idx][1],
      adoption_month = if (any(flagged)) min(m[flagged]) else as.Date(NA),
      n_flagged = sum(flagged),
      trailing_mean = mean(trailing_mean, na.rm = TRUE),
      trailing_sd = mean(trailing_sd, na.rm = TRUE),
      peak_stops = if (all(is.na(s))) NA_real_ else max(s, na.rm = TRUE),
      peak_ratio = if (all(is.na(trailing_mean))) {
        NA_real_
      } else {
        max(s, na.rm = TRUE) / mean(trailing_mean, na.rm = TRUE)
      }
    )
  }
  out <- dplyr::bind_rows(summary_rows)
  attr(out, "flags") <- dplyr::bind_rows(flags)
  attr(out, "method") <- method
  attr(out, "k") <- k
  class(out) <- c("lamp_surges", class(out))
  out
}

#' @export
print.lamp_surges <- function(x, ...) {
  n <- sum(!is.na(x$adoption_month))
  cli::cli_text(
    "{.strong streetlamp surges}: {n} of {nrow(x)} area{?s} flagged ",
    "({attr(x, 'method')}, k = {attr(x, 'k')})."
  )
  cli::cli_alert_warning(
    "Surges detected from the stop series are endogenous; see {.fn lamp_detect_surges}."
  )
  NextMethod()
}

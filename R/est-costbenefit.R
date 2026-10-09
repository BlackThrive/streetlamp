# Crimes prevented per thousand searches ------------------------------------------------

#' Convert an estimate into crimes prevented per thousand searches
#'
#' Takes an elasticity or a treatment effect and expresses it as the number of
#' crimes prevented per thousand searches at the sample mean, which is the
#' form in which the question is usually asked. The conversion is arithmetic,
#' not evidence: it inherits every assumption of the estimate it is given, and
#' adds more of its own. The assumption chain is returned with the number and
#' printed with it.
#'
#' @details
#' For an elasticity `e`, a proportional change in searches `dS/S` changes
#' crime by `e * dS/S`, so at mean monthly crime `C` and mean searches `S` the
#' crimes prevented by an extra `per_stops` searches are
#' `-e * C * per_stops / S`. The elasticity estimators use `log(1 + stops)`,
#' so their derivative has denominator `S + 1`. The count-mean model uses
#' `C` in the numerator; the legacy log-one-plus outcome approximation uses
#' `C + 1`. For a treatment effect in log points `b`, the
#' effect on crime is `C * (exp(b) - 1)`, and it is divided by the searches
#' the intervention actually added, which you must supply as `stops_added`
#' because a binary treatment does not say how much searching it involved.
#'
#' @section What this number does not include:
#' It counts recorded crime only, so crimes not reported to the police are
#' invisible to it, and any change in recording practice is counted as a
#' change in crime. It assumes the effect is linear in searches over the
#' range considered, and that the average effect applies at the margin, which
#' is the opposite of what diminishing returns implies. It says nothing about
#' the costs of searching, which fall on the people searched.
#'
#' @param estimate A `lamp_estimate` from [lamp_elasticity()],
#'   [lamp_twfe()], [lamp_did_staggered()] or [lamp_event_study()].
#' @param panel The panel the estimate was built from, for the sample means.
#' @param per_stops Searches to express the result per, default 1000.
#' @param stops_added For a treatment effect: the searches the intervention
#'   added per area-month. Required unless the estimate is an elasticity.
#' @param outcome_column The crime column to take the mean of; defaults to the
#'   estimate's outcome.
#' @param n_boot Retained for compatibility. Intervals now transform the
#'   coefficient interval directly and require no simulation.
#' @param seed Retained for compatibility; the conversion is deterministic.
#'
#' @return A list of class `lamp_crimes_prevented` with `crimes_prevented`,
#'   `conf_low`, `conf_high`, the inputs used, and `assumptions`, a character
#'   vector naming every step from the estimate to the number.
#' @family estimators
#' @export
#' @examples
#' sim <- lamp_simulate(n_areas = 30, n_months = 30, design = "continuous", seed = 1)
#' el <- lamp_elasticity(sim, "crime_total", lags = 0:1)
#' lamp_crimes_prevented(el, sim)
lamp_crimes_prevented <- function(estimate, panel, per_stops = 1000, stops_added = NULL,
                                  outcome_column = NULL, n_boot = 2000, seed = NULL) {
  if (!inherits(estimate, "lamp_estimate")) {
    lamp_abort("{.arg estimate} must come from a streetlamp estimator.", "input")
  }
  lamp_check_panel(panel)
  if (!is.numeric(per_stops) || length(per_stops) != 1L ||
        !is.finite(per_stops) || per_stops <= 0) {
    lamp_abort("{.arg per_stops} must be a positive number.", "input")
  }
  outcome <- outcome_column %||% estimate$meta$outcome
  if (!outcome %in% names(panel)) {
    lamp_abort("{.field {outcome}} is not a panel column.", "input")
  }
  stops_col <- estimate$meta$stops %||% "stops"
  if (!stops_col %in% names(panel)) {
    lamp_abort("{.field {stops_col}} is not a panel column.", "input")
  }
  usable <- panel
  if (!is.null(estimate$data)) {
    fit_key <- paste(estimate$data$area, lamp_month_id(estimate$data$month))
    usable <- usable[paste(usable$area, lamp_month_id(usable$month)) %in% fit_key, ]
  }
  if ("coverage_status" %in% names(usable)) {
    usable <- usable[usable$coverage_status %in% lamp_filled_statuses(), ]
  }
  mean_crime <- mean(usable[[outcome]], na.rm = TRUE)
  mean_stops <- mean(usable[[stops_col]], na.rm = TRUE)
  if (!is.finite(mean_crime) || !is.finite(mean_stops) || mean_stops <= 0) {
    lamp_abort("The panel has no usable mean crime or mean searches.", "input")
  }

  is_elasticity <- inherits(estimate, "lamp_elasticity")
  summary <- lamp_effect_summary(estimate)
  b <- summary$estimate
  se <- summary$std_error
  if (is_elasticity) {
    crime_scale <- if (estimate$meta$family == "poisson") mean_crime else mean_crime + 1
    convert <- function(x) -x * crime_scale * per_stops / (mean_stops + 1)
    lag_label <- paste(estimate$diagnostics$lags, collapse = ", ")
    assumptions <- c(
      sprintf("The log-one-plus stops slope is %s, summed over lags %s.", signif(b, 3), lag_label),
      "The denominator is mean stops plus one; legacy OLS also uses mean crime plus one.",
      "The effect is proportional, so it scales with the mean level of crime.",
      sprintf(
        "At the sample mean of %s crimes and %s searches per area-month.",
        signif(mean_crime, 3), signif(mean_stops, 3)
      ),
      estimate$assumption,
      "Recorded crime only: unreported crime and recording changes are not separated.",
      "The average effect is applied at the margin, which ignores diminishing returns."
    )
  } else {
    if (!is.numeric(stops_added) || length(stops_added) != 1L ||
          !is.finite(stops_added) || stops_added <= 0) {
      lamp_abort(
        c(
          "A treatment effect needs {.arg stops_added}: the searches it added per area-month.",
          "i" = "Without it there is nothing to express the effect per."
        ),
        "input"
      )
    }
    if (estimate$meta$family == "ols_ihs") {
      lamp_abort("An IHS effect needs baseline-specific predictions for this conversion.", "input")
    }
    count_scale <- identical(estimate$meta$family, "identity")
    scale <- if (identical(estimate$meta$family, "ols_log")) mean_crime + 1 else mean_crime
    convert <- if (count_scale) {
      function(x) -x * per_stops / stops_added
    } else {
      function(x) -scale * expm1(x) * per_stops / stops_added
    }
    assumptions <- c(
      sprintf("The treatment effect is %s on the %s scale.", signif(b, 3), estimate$meta$family),
      if (identical(estimate$meta$family, "ols_log")) {
        "Retransformation at mean crime plus one is an approximation, not an expected-count effect."
      },
      sprintf("The intervention added %s searches per area-month.", signif(stops_added, 3)),
      sprintf("At the sample mean of %s crimes per area-month.", signif(mean_crime, 3)),
      estimate$assumption,
      "Recorded crime only: unreported crime and recording changes are not separated.",
      "The average effect is applied at the margin, which ignores diminishing returns."
    )
  }

  point <- convert(b)
  ci <- sort(convert(c(summary$conf_low, summary$conf_high)))

  structure(
    list(
      crimes_prevented = point,
      conf_low = ci[1], conf_high = ci[2],
      per_stops = per_stops,
      estimate_used = b, std_error_used = se,
      mean_crime = mean_crime, mean_stops = mean_stops,
      stops_added = stops_added,
      outcome = outcome,
      source = estimate$estimator,
      assumptions = assumptions
    ),
    class = "lamp_crimes_prevented"
  )
}

#' @export
print.lamp_crimes_prevented <- function(x, ...) {
  cli::cli_h3("Crimes prevented per {x$per_stops} searches")
  cli::cli_text(
    "{signif(x$crimes_prevented, 3)} ",
    "[{signif(x$conf_low, 3)}, {signif(x$conf_high, 3)}] on {.field {x$outcome}}"
  )
  if (x$crimes_prevented < 0) {
    cli::cli_text("A negative number means the estimate implies more recorded crime, not less.")
  }
  cli::cli_h3("Assumption chain")
  cli::cli_ol(x$assumptions)
  invisible(x)
}

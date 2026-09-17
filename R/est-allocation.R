# How police follow crime ----------------------------------------------------------------

#' How stop and search activity follows recorded crime
#'
#' Regresses searches on the crime recorded in previous months, with area and
#' month fixed effects. This is not an effect of crime on searching in any
#' causal sense; it is a description of how activity is allocated, and it is
#' here because without it the other estimators cannot be read honestly.
#'
#' @section Why this matters for every other estimate:
#' If police search more where crime has just risen, then searching is a
#' response to crime as well as a possible cause of it. A regression of crime
#' on searches then mixes the two directions: the deterrent effect pushes the
#' coefficient down, the allocation response pushes it up, and the estimate is
#' the net of them. A positive coefficient here is the size of the channel
#' that has to be argued away before a stop-crime elasticity or a
#' difference-in-differences estimate can be called causal. A coefficient near
#' zero is the case in which the other estimates are easier to defend.
#'
#' @param panel A `lamp_panel`.
#' @param stops The activity column, default `"stops"`.
#' @param crime The crime column, default `"crime_total"`.
#' @param crime_lags Lags of crime to include, default 1 to 3.
#' @param cluster `"area"` (default) or `"force"`.
#' @param family `"poisson"` (default) or `"ols_log"`.
#'
#' @return A `lamp_estimate` of class `lamp_allocation`, with one coefficient
#'   per lag and `diagnostics$total` for their sum. The identifying assumption
#'   field states plainly that the result is descriptive.
#' @family estimators
#' @export
#' @examples
#' sim <- lamp_simulate(n_areas = 24, n_months = 30, design = "continuous", seed = 1)
#' lamp_allocation(sim, crime_lags = 1:2)
lamp_allocation <- function(panel, stops = "stops", crime = "crime_total", crime_lags = 1:3,
                            cluster = c("area", "force"),
                            family = c("poisson", "ols_log")) {
  cluster <- rlang::arg_match(cluster)
  family <- rlang::arg_match(family)
  lamp_check_panel(panel)
  check_string(stops)
  check_string(crime)
  for (nm in c(stops, crime)) {
    if (!nm %in% names(panel)) {
      lamp_abort("{.field {nm}} is not a panel column.", "input")
    }
  }
  if (!is.numeric(crime_lags) || any(crime_lags < 1) || any(crime_lags != round(crime_lags))) {
    lamp_abort("{.arg crime_lags} must be whole numbers of months, one or more.", "input")
  }
  crime_lags <- as.integer(sort(unique(crime_lags)))

  mf <- lamp_model_frame(panel, stops, crime, NULL, cluster)
  d <- mf$data
  d$.log_crime <- log1p(d[[crime]])
  lagm <- lamp_lag_matrix(d, ".log_crime", crime_lags)
  lag_terms <- colnames(lagm)
  for (k in seq_along(lag_terms)) d[[lag_terms[k]]] <- lagm[, k]
  keep <- stats::complete.cases(d[, lag_terms, drop = FALSE])
  d <- d[keep, ]
  mf$sample <- dplyr::bind_rows(
    mf$sample,
    tibble::tibble(
      step = "after dropping rows without the full lag history",
      n_rows = nrow(d), n_areas = length(unique(d$area))
    )
  )
  if (nrow(d) == 0L) {
    lamp_abort("No rows remain once the crime lags are formed.", "input")
  }

  response <- if (family == "poisson") stops else sprintf("log1p(%s)", stops)
  rhs <- paste(lag_terms, collapse = " + ")
  fml <- stats::as.formula(paste(response, "~", rhs, "| .area + .month"))
  fit <- lamp_fit(fml, d, family, cluster)
  co <- lamp_coefficients(fit)

  v <- stats::vcov(fit)
  have <- intersect(lag_terms, rownames(v))
  w <- rep(1, length(have))
  total_est <- sum(stats::coef(fit)[have])
  total_se <- sqrt(as.numeric(t(w) %*% v[have, have, drop = FALSE] %*% w))
  z <- stats::qnorm(0.975)
  total <- list(
    estimate = total_est, std_error = total_se,
    conf_low = total_est - z * total_se, conf_high = total_est + z * total_se
  )
  interpretation <- if (total$conf_low > 0) {
    paste0(
      "Searching follows recorded crime: a one percent rise in recent crime ",
      "goes with a ", signif(100 * total_est, 3), " percent rise in searches. ",
      "Any estimate of the effect of searching on crime has to contend with ",
      "this reverse channel."
    )
  } else if (total$conf_high < 0) {
    paste(
      "Searching falls where recent crime has risen, which is the opposite of",
      "the usual allocation pattern and worth checking before relying on it."
    )
  } else {
    paste(
      "No clear allocation response: searching does not track recent crime in",
      "this panel, which makes the other estimates easier to read as effects."
    )
  }

  diagnostics <- list(
    n_dropped_coverage = mf$n_dropped_coverage,
    total = total, crime_lags = crime_lags,
    interpretation = interpretation,
    dispersion = lamp_dispersion(fit, family)
  )
  contract <- mf$contract
  new_lamp_estimate(
    "lamp_allocation", co,
    assumption = paste(
      "None: this is descriptive. It measures how searching has tracked",
      "recorded crime, not an effect of crime on searching."
    ),
    sample = mf$sample, diagnostics = diagnostics,
    meta = list(
      outcome = stops, family = family, cluster = cluster,
      treatment_type = "lagged crime", crime = crime
    ),
    model = fit, contract = contract, data = d
  )
}

#' @export
print.lamp_allocation <- function(x, ...) {
  print.lamp_estimate(x, ...)
  tot <- x$diagnostics$total
  cli::cli_text(
    "Sum over lags: {signif(tot$estimate, 3)} ",
    "[{signif(tot$conf_low, 3)}, {signif(tot$conf_high, 3)}]"
  )
  cli::cli_text(x$diagnostics$interpretation)
  invisible(x)
}

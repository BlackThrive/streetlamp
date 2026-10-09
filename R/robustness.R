#' Evaluate an explicit elasticity specification grid
#'
#' Runs every requested outcome, lag window and family, retaining failures
#' and optional leave-one-area-out estimates. Register the primary outcome
#' and specification before examining the grid. These are dependent,
#' exploratory checks; selecting a favourable row does not establish a cause.
#' The OLS and Poisson rows target different quantities and should not be
#' interpreted as estimates of one common elasticity.
#' @param panel A `lamp_panel`.
#' @param outcomes Outcome column names.
#' @param lags A named list of non-negative integer lag vectors.
#' @param families Character vector containing `"poisson"`, `"ols_log"`, or both.
#' @param cluster `"area"` or `"force"`.
#' @param leave_one_out Also fit each specification after omitting each area.
#'   This can be expensive on large panels.
#' @return A tibble with every requested specification, omitted area, status,
#'   error message, lag-sum estimate and interval, and observed sample sizes.
#' @family diagnostics
#' @export
#' @examples
#' sim <- lamp_simulate(design = "continuous", n_areas = 12, seed = 1)
#' lamp_elasticity_robustness(sim, lags = list(current = 0, short = 0:1))
lamp_elasticity_robustness <- function(panel, outcomes = "crime_total",
                                       lags = list(current = 0L, short = 0:1, distributed = 0:3),
                                       families = c("poisson", "ols_log"),
                                       cluster = c("area", "force"), leave_one_out = FALSE) {
  lamp_check_panel(panel)
  cluster <- rlang::arg_match(cluster)
  check_bool(leave_one_out)
  if (!is.character(outcomes) || !length(outcomes) || anyNA(outcomes) || anyDuplicated(outcomes) ||
        !all(outcomes %in% names(panel))) {
    lamp_abort("Name distinct available outcomes.", "input")
  }
  if (!is.list(lags) || !length(lags) || is.null(names(lags)) ||
        anyNA(names(lags)) || any(!nzchar(names(lags))) || anyDuplicated(names(lags))) {
    lamp_abort("{.arg lags} must be a distinctly named list of lag vectors.", "input")
  }
  valid_lag <- function(x) {
    is.numeric(x) && length(x) > 0L && all(is.finite(x)) &&
      all(x >= 0 & x == round(x) & x <= .Machine$integer.max)
  }
  if (!all(vapply(lags, valid_lag, logical(1)))) lamp_abort("Invalid lag vectors.", "input")
  if (!is.character(families) || !length(families) || anyNA(families) || anyDuplicated(families) ||
        !all(families %in% c("poisson", "ols_log"))) {
    lamp_abort("Choose distinct supported families.", "input")
  }
  omitted <- c(NA_character_, if (leave_one_out) sort(unique(panel$area)))
  rows <- list()
  for (outcome in outcomes) {
    for (lag_name in names(lags)) {
      for (family in families) {
        for (area in omitted) {
          d <- if (is.na(area)) panel else panel[panel$area != area, ]
          fit <- tryCatch(lamp_elasticity(d, outcome,
                            lags = lags[[lag_name]], family = family,
                            cluster = cluster
                          ), error = function(e) e)
          failed <- inherits(fit, "error")
          s <- if (failed) NULL else lamp_effect_summary(fit)
          rows[[length(rows) + 1L]] <- tibble::tibble(
            outcome = outcome, lag_specification = lag_name,
            lags = paste(sort(unique(lags[[lag_name]])), collapse = ","), family = family,
            omitted_area = area, status = if (failed) "failed" else "ok",
            message = if (failed) conditionMessage(fit) else NA_character_,
            estimate = if (failed) NA_real_ else s$estimate,
            std_error = if (failed) NA_real_ else s$std_error,
            conf_low = if (failed) NA_real_ else s$conf_low,
            conf_high = if (failed) NA_real_ else s$conf_high,
            n_rows = if (failed) NA_integer_ else stats::nobs(fit$model),
            n_areas = if (failed) NA_integer_ else fit$diagnostics$n_areas_used,
            n_clusters = if (failed) NA_integer_ else fit$diagnostics$n_clusters
          )
        }
      }
    }
  }
  dplyr::bind_rows(rows)
}

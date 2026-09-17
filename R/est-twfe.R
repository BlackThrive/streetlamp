# Two-way fixed effects ---------------------------------------------------------------

#' Two-way fixed effects estimate of the effect of stops on crime
#'
#' Fits the outcome on the treatment with area and month fixed effects, so
#' that the effect is identified from changes within an area over time,
#' net of anything common to all areas in a month. Standard errors are
#' clustered at the level given in `cluster`.
#'
#' @section Identifying assumption:
#' Treated and control areas would have followed parallel paths in the
#' outcome had the treatment not changed, once area and month fixed effects
#' are removed. With a continuous treatment this also requires that the
#' intensity of searching is unrelated to what else was changing in the area,
#' which police allocation makes doubtful: see `lamp_allocation()`.
#'
#' @section When this estimator is the wrong one:
#' With staggered adoption, two-way fixed effects compares later-treated
#' areas against already-treated ones, and the estimate can lie outside the
#' range of every area's true effect. Use `lamp_did_staggered()` instead;
#' this function warns when the treatment has more than one adoption date.
#'
#' @param panel A `lamp_panel` from [lamp_panel()].
#' @param outcome The outcome column, for example `"crime_total"` or a crime
#'   type key from [lamp_crime_types()].
#' @param treatment A [lamp_treatment()] object, or the name of a panel
#'   column.
#' @param controls Optional panel columns to include as covariates.
#' @param cluster `"area"` (default) or `"force"`.
#' @param family `"poisson"` (default, a Poisson pseudo-likelihood suited to
#'   counts), `"negbin"`, `"ols_log"` or `"ols_ihs"`.
#' @param force_month Add force-by-month fixed effects, which absorb anything
#'   that moved a whole force in a month (a recording change, a force-wide
#'   operation) at the cost of identifying only from within-force variation.
#'
#' @return A `lamp_estimate` of class `lamp_twfe`: coefficients with
#'   clustered standard errors and 95 percent intervals, the identifying
#'   assumption, the exclusion table and a `diagnostics` list holding the
#'   dispersion statistic and, when the panel carries adjacency, Moran's I of
#'   the residuals.
#' @family estimators
#' @export
#' @examples
#' sim <- lamp_simulate(n_areas = 24, n_months = 24, design = "event", effect = -0.2, seed = 2)
#' truth <- attr(sim, "truth")
#' tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
#' fit <- lamp_twfe(sim, "crime_total", tr)
#' fit
#' tidy(fit)
lamp_twfe <- function(panel, outcome = "crime_total", treatment, controls = NULL,
                      cluster = c("area", "force"),
                      family = c("poisson", "negbin", "ols_log", "ols_ihs"),
                      force_month = FALSE) {
  cluster <- rlang::arg_match(cluster)
  family <- rlang::arg_match(family)
  check_bool(force_month)
  mf <- lamp_model_frame(panel, outcome, treatment, controls, cluster)
  d <- mf$data

  if (mf$treatment$type == "staggered" || lamp_n_cohorts(d) > 1L) {
    lamp_warn(
      c(
        "The treatment has more than one adoption date.",
        "i" = "It is biased under staggered adoption; see {.fn lamp_did_staggered}."
      ),
      "estimator"
    )
  }
  fe <- if (force_month) "| .area + .month + force_id^.month" else "| .area + .month"
  rhs <- paste(c(".treat", controls), collapse = " + ")
  fml <- stats::as.formula(paste(lamp_response(outcome, family), "~", rhs, fe))
  fit <- lamp_fit(fml, d, family, cluster)

  coefs <- lamp_coefficients(fit)
  coefs$term[coefs$term == ".treat"] <- mf$treatment$column
  diagnostics <- list(
    n_dropped_coverage = mf$n_dropped_coverage,
    dispersion = lamp_dispersion(fit, family),
    moran = lamp_residual_moran(fit, d, mf$contract),
    n_obs = stats::nobs(fit),
    force_month = force_month
  )
  contract <- mf$contract
  contract$treatment <- mf$treatment
  new_lamp_estimate(
    "lamp_twfe", coefs,
    assumption = paste(
      "Parallel trends: treated and control areas would have moved together",
      "in the outcome, net of area and month fixed effects."
    ),
    sample = mf$sample, diagnostics = diagnostics,
    meta = list(
      outcome = outcome, family = family, cluster = cluster,
      treatment_type = mf$treatment$type, controls = controls
    ),
    model = fit, contract = contract, data = d
  )
}

lamp_n_cohorts <- function(d) {
  if (!".cohort" %in% names(d)) {
    return(1L)
  }
  length(unique(stats::na.omit(d$.cohort)))
}

# Stop-crime elasticity with cross-sectional dependence ----------------------------------
#
# Areas do not move independently: a national policy change, a season, or a
# shared shock moves them together. Ignoring that common factor makes the
# standard errors too small and can bias the slope if the factor is
# correlated with stop activity. The common correlated effects estimator of
# Pesaran (2006) handles it by adding the cross-sectional averages of the
# dependent and independent variables as regressors, which proxy for the
# unobserved factors. Both variants are implemented here rather than taken
# from another package.

lamp_elasticity_methods <- function() c("fe", "cce_mg", "cce_pooled")

# Distributed lags of a variable within each area.
lamp_lag_matrix <- function(d, var, lags) {
  out <- matrix(NA_real_, nrow = nrow(d), ncol = length(lags))
  colnames(out) <- paste0(var, "_lag", lags)
  # Match calendar months, not neighbouring rows: an absent February must
  # never turn January into March's one-month lag.
  months <- unique(d$month)
  month_index <- as.integer(format(months, "%Y")) * 12L + as.integer(format(months, "%m"))
  m <- month_index[match(unclass(d$month), unclass(months))]
  key <- paste(d$area, m, sep = "\r")
  for (k in seq_along(lags)) {
    idx <- match(paste(d$area, m - lags[k], sep = "\r"), key)
    out[, k] <- d[[var]][idx]
  }
  out
}

# Cross-sectional averages by month, the proxies for the common factors.
lamp_cross_section_averages <- function(d, vars) {
  out <- matrix(NA_real_, nrow = nrow(d), ncol = length(vars))
  colnames(out) <- paste0("cs_", vars)
  # grouped on the month key rather than the Date column: `tapply()` on a
  # Date formats every element, once per variable
  key <- lamp_month_id(d$month)
  for (k in seq_along(vars)) {
    m <- tapply(d[[vars[k]]], key, mean, na.rm = TRUE)
    out[, k] <- as.numeric(m[key])
  }
  out
}

# The CD test asks whether a common factor is left in the residuals, so it is
# computed on a regression with area effects only. Month dummies would remove
# the common factor by construction and force the statistic negative, which
# would say nothing about the data.
lamp_cd_test_for <- function(d, lag_terms, cluster) {
  fml <- stats::as.formula(paste(".log_y ~", paste(lag_terms, collapse = " + "), "| .area"))
  fit <- rlang::try_fetch(
    fixest::feols(fml, data = d, cluster = ~.cluster, notes = FALSE),
    error = function(e) NULL
  )
  if (is.null(fit)) {
    return(NULL)
  }
  lamp_cd_test(stats::resid(fit), d$area, d$month)
}

# Pesaran's CD test: the average pairwise correlation of residuals across
# areas, scaled so that it is standard normal under cross-sectional
# independence. A large value says the areas share a factor.
#
# The statistic sums over every pair of areas, so the work grows with the
# square of the number of areas. On a national LSOA panel that is more than
# six hundred million pairs, which no correlation matrix can hold, so above
# `max_areas` the test is computed on a reproducible random sample of areas
# and says so. Pesaran's statistic is standard normal as the number of areas
# grows, so a large sample answers the same question.
lamp_cd_test <- function(resid, area, month, max_areas = 2000L, seed = 20260101L) {
  if (inherits(month, c("Date", "POSIXt"))) {
    month <- lamp_month_id(month)
  }
  wide <- tapply(resid, list(area, month), mean)
  n_areas <- nrow(wide)
  if (is.null(n_areas) || n_areas < 2L) {
    return(NULL)
  }
  sampled <- n_areas > max_areas
  if (sampled) {
    wide <- wide[sort(withr::with_seed(seed, sample.int(n_areas, max_areas))), , drop = FALSE]
  }
  n <- nrow(wide)

  # months in rows, areas in columns, so that `cor()` gives every pairwise
  # correlation in one call and the crossproduct of the observed indicator
  # gives the number of months each pair shares
  x <- t(wide)
  t_obs <- crossprod(!is.na(x) + 0)
  rho <- suppressWarnings(stats::cor(x, use = "pairwise.complete.obs"))
  # a pair needs three shared months, and a pair with no variation has no
  # correlation: both were excluded when this was computed pair by pair
  use <- upper.tri(rho) & t_obs >= 3L & !is.na(rho)
  if (!any(use)) {
    return(NULL)
  }
  cd <- sqrt(2 / (n * (n - 1))) * sum(sqrt(t_obs[use]) * rho[use])
  note <- paste(
    "A large statistic means areas move together; ignoring that makes",
    "standard errors too small."
  )
  if (sampled) {
    note <- paste(
      note, sprintf(
        "Computed on %d of %d areas, sampled at random with a fixed seed.",
        n, n_areas
      )
    )
  }
  list(
    statistic = cd,
    p_value = 2 * stats::pnorm(-abs(cd)),
    mean_rho = mean(rho[use]),
    n_areas = n_areas,
    n_areas_used = n,
    sampled = sampled,
    note = note
  )
}

#' Elasticity of crime with respect to stop and search
#'
#' Estimates how recorded crime responds to the intensity of searching, as a
#' distributed lag of log-one-plus stops with area and month fixed
#' effects. Three methods are offered, differing in how they handle the fact
#' that areas move together.
#'
#' @section What an elasticity here is and is not:
#' With `family = "poisson"`, a coefficient describes the log conditional
#' mean of the count per unit of `log(1 + stops)`. Its elasticity with respect
#' to stops at intensity S is `coefficient * S / (1 + S)`. With
#' `family = "ols_log"`, it describes `log(1 + observed crime)` instead;
#' this is a different estimand, particularly when counts are small. Neither
#' is automatically the effect of a decision to search
#' more. Police send officers where crime is rising, so the association runs
#' in both directions; `lamp_allocation()` measures that reverse channel and
#' should be reported alongside. Read the elasticity as a description of the
#' joint movement unless the variation in searching has an argued external
#' source.
#'
#' @section Methods:
#' * `fe`: area and month fixed effects only.
#' * `cce_mg`: the common correlated effects mean group estimator. The
#'   cross-sectional averages of the outcome and the regressors are added to
#'   each area's own time-series regression, and the area coefficients are
#'   averaged; the standard error is the spread of those coefficients, which
#'   makes no assumption that areas share a slope.
#' * `cce_pooled`: one pooled regression with the same averages added, which
#'   is more precise if the slope really is common.
#'
#' Pesaran's CD test is an auxiliary descriptive diagnostic in every case.
#' It uses OLS residuals of log-one-plus counts with area effects only,
#' including when the primary estimator is Poisson, because month dummies
#' would remove the common factor by construction and make the statistic
#' negative whatever the data looked like. A large statistic flags shared
#' movements; it does not by itself prove that clustered intervals are invalid.
#'
#' @inheritParams lamp_twfe
#' @param stops The stop intensity column, default `"stops"`.
#' @param lags Lags of log stops to include, default 0 to 3.
#' @param method `"fe"`, `"cce_mg"` or `"cce_pooled"`.
#' @param min_months Months an area needs before it enters a mean-group
#'   regression.
#' @param family `NULL` selects `"poisson"` for `fe` and `"ols_log"` for
#'   the CCE methods. Poisson pseudo-likelihood models the conditional count
#'   mean, including zeros, with clustered inference. CCE currently supports
#'   only `"ols_log"`. Specify `"ols_log"` to reproduce the former FE scale.
#'
#' @return A `lamp_estimate` of class `lamp_elasticity`. Coefficients are the
#'   lag-by-lag elasticities; `diagnostics$long_run` is their sum with a
#'   standard error, `diagnostics$cd_test` is Pesaran's test, and
#'   `diagnostics$area_coefficients` holds the per-area slopes for the mean
#'   group estimator. The CD test sums over every pair of areas, so above two
#'   thousand areas it is computed on a random sample of them, drawn with a
#'   fixed seed: `cd_test$sampled` says whether that happened and
#'   `cd_test$n_areas_used` how many areas went in.
#' @family estimators
#' @references
#' Pesaran, M. H. (2006). Estimation and inference in large heterogeneous
#' panels with a multifactor error structure. Econometrica 74(4), 967-1012.
#'
#' Chudik, A. and Pesaran, M. H. (2015). Common correlated effects estimation
#' of heterogeneous dynamic panel data models with weakly exogenous
#' regressors. Journal of Econometrics 188(2), 393-420.
#' @export
#' @examples
#' sim <- lamp_simulate(n_areas = 30, n_months = 36, design = "continuous", seed = 1)
#' fit <- lamp_elasticity(sim, "crime_total", lags = 0:1)
#' fit
#' fit$diagnostics$cd_test$statistic
lamp_elasticity <- function(panel, outcome = "crime_total", stops = "stops", lags = 0:3,
                            method = c("fe", "cce_mg", "cce_pooled"),
                            cluster = c("area", "force"), min_months = 12L,
                            family = NULL) {
  method <- rlang::arg_match(method)
  cluster <- rlang::arg_match(cluster)
  if (is.null(family)) family <- if (method == "fe") "poisson" else "ols_log"
  family <- rlang::arg_match(family, c("poisson", "ols_log"))
  if (method == "cce_mg" && cluster == "force") {
    lamp_abort(
      "CCE mean-group inference uses area slopes; force clustering is not implemented.", "input"
    )
  }
  if (method != "fe" && family != "ols_log") {
    lamp_abort("CCE methods currently require {.code family = \"ols_log\"}.", "input")
  }
  lamp_check_panel(panel)
  check_string(outcome)
  check_string(stops)
  for (nm in c(outcome, stops)) {
    if (!nm %in% names(panel)) {
      lamp_abort("{.field {nm}} is not a panel column.", "input")
    }
  }
  if (!is.numeric(lags) || !length(lags) || any(!is.finite(lags)) ||
        any(lags < 0) || any(lags != round(lags)) || any(lags > .Machine$integer.max)) {
    lamp_abort("{.arg lags} must be whole numbers of months, zero or more.", "input")
  }
  lags <- as.integer(sort(unique(lags)))
  if (!is.numeric(min_months) || length(min_months) != 1L || !is.finite(min_months) ||
        min_months < 1 || min_months != round(min_months)) {
    lamp_abort("{.arg min_months} must be a positive whole number.", "input")
  }

  mf <- lamp_model_frame(panel, outcome, stops, NULL, cluster)
  d <- mf$data
  for (nm in c(outcome, stops)) {
    if (!is.numeric(d[[nm]]) || any(!is.finite(d[[nm]])) || any(d[[nm]] < 0)) {
      lamp_abort("{.field {nm}} must contain finite, non-negative numeric values.", "input")
    }
  }
  d$.y <- d[[outcome]]
  d$.log_y <- log1p(d[[outcome]])
  d$.log_s <- log1p(d[[stops]])
  lagm <- lamp_lag_matrix(d, ".log_s", lags)
  lag_terms <- colnames(lagm)
  for (k in seq_along(lag_terms)) d[[lag_terms[k]]] <- lagm[, k]
  csm <- lamp_cross_section_averages(d, c(".log_y", ".log_s"))
  cs_terms <- colnames(csm)
  for (k in seq_along(cs_terms)) d[[cs_terms[k]]] <- csm[, k]

  keep <- stats::complete.cases(d[, c(".log_y", lag_terms, cs_terms), drop = FALSE])
  d <- d[keep, ]
  mf$sample <- dplyr::bind_rows(
    mf$sample,
    tibble::tibble(
      step = "after dropping rows without the full lag history",
      n_rows = nrow(d), n_areas = length(unique(d$area))
    )
  )
  if (nrow(d) == 0L) {
    lamp_abort("No rows remain once the lags are formed.", "input")
  }

  res <- switch(method,
    fe = lamp_elasticity_fe(d, lag_terms, cluster, family),
    cce_pooled = lamp_elasticity_cce_pooled(d, lag_terms, cs_terms, cluster),
    cce_mg = lamp_elasticity_cce_mg(d, lag_terms, cs_terms, min_months)
  )
  cd <- lamp_cd_test_for(d, lag_terms, cluster)
  used_data <- if (is.null(res$model)) {
    d[d$area %in% res$area_coefficients$area, ]
  } else {
    d[fixest::obs(res$model), ]
  }
  mf$sample <- dplyr::bind_rows(mf$sample, tibble::tibble(
    step = "observations retained by the estimator", n_rows = nrow(used_data),
    n_areas = length(unique(used_data$area))
  ))
  res$n_areas_used <- length(unique(used_data$area))

  long_run <- list(
    estimate = sum(res$coefficients$estimate),
    std_error = res$long_run_se
  )
  df <- if (is.null(res$model)) {
    res$n_areas_used - 1L
  } else {
    lamp_inference_df(res$model)
  }
  z <- stats::qt(0.975, df)
  long_run$conf_low <- long_run$estimate - z * long_run$std_error
  long_run$conf_high <- long_run$estimate + z * long_run$std_error

  diagnostics <- list(
    n_dropped_coverage = mf$n_dropped_coverage,
    cd_test = cd,
    long_run = long_run,
    covariance = res$covariance,
    df = df,
    estimand = if (family == "poisson") {
      "log conditional count mean per log(1 + stops)"
    } else {
      "log(1 + observed outcome) per log(1 + stops)"
    },
    n_clusters = length(unique(used_data$.cluster)),
    inference_note = paste(
      "Clustered inference needs enough independent clusters.",
      "Shared local shocks may require a different design."
    ),
    method = method,
    lags = lags,
    area_coefficients = res$area_coefficients,
    n_areas_used = res$n_areas_used
  )
  contract <- mf$contract
  new_lamp_estimate(
    "lamp_elasticity", res$coefficients,
    assumption = paste0(
      "The association between searching and recorded crime, net of area and ",
      "month effects",
      if (method != "fe") " and of common factors proxied by cross-sectional averages",
      ". Causal only if the variation in searching has a source outside the ",
      "crime process; see lamp_allocation()."
    ),
    sample = mf$sample, diagnostics = diagnostics,
    meta = list(
      outcome = outcome, family = family, cluster = cluster,
      treatment_type = "continuous", stops = stops, method = method
    ),
    model = res$model, contract = contract, data = used_data
  )
}

lamp_elasticity_fe <- function(d, lag_terms, cluster, family) {
  rhs <- paste(lag_terms, collapse = " + ")
  response <- if (family == "poisson") ".y" else ".log_y"
  fml <- stats::as.formula(paste(response, "~", rhs, "| .area + .month"))
  fit <- lamp_fit(fml, d, family, cluster)
  co <- lamp_coefficients(fit)
  v <- stats::vcov(fit)
  if (!all(lag_terms %in% rownames(v))) {
    lamp_abort("Some requested lags are unidentified after fixed effects; use fewer lags.", "input")
  }
  w <- rep(1, length(lag_terms))
  se <- sqrt(as.numeric(t(w) %*% v[lag_terms, lag_terms, drop = FALSE] %*% w))
  list(
    coefficients = co, model = fit, residuals = stats::resid(fit),
    long_run_se = se, covariance = v[lag_terms, lag_terms, drop = FALSE], area_coefficients = NULL,
    n_areas_used = length(unique(d$area))
  )
}

lamp_elasticity_cce_pooled <- function(d, lag_terms, cs_terms, cluster) {
  # Area fixed effects only: the cross-sectional averages stand in for the
  # common time factors, so month dummies as well would be collinear with
  # them and would silently absorb the very variation the method uses.
  rhs <- paste(c(lag_terms, cs_terms), collapse = " + ")
  fml <- stats::as.formula(paste(".log_y ~", rhs, "| .area"))
  fit <- lamp_fit(fml, d, "ols_log", cluster)
  co <- lamp_coefficients(fit)
  co <- co[co$term %in% lag_terms, ]
  v <- stats::vcov(fit)
  have <- intersect(lag_terms, rownames(v))
  if (length(have) != length(lag_terms)) {
    lamp_abort("Some requested lags are unidentified in the CCE model; use fewer lags.", "input")
  }
  w <- rep(1, length(have))
  se <- sqrt(as.numeric(t(w) %*% v[have, have, drop = FALSE] %*% w))
  list(
    coefficients = co, model = fit, residuals = stats::resid(fit),
    long_run_se = se, covariance = v[have, have, drop = FALSE], area_coefficients = NULL,
    n_areas_used = length(unique(d$area))
  )
}

lamp_elasticity_cce_mg <- function(d, lag_terms, cs_terms, min_months) {
  areas <- unique(d$area)
  coefs <- list()
  resid <- rep(NA_real_, nrow(d))
  for (a in areas) {
    rows <- which(d$area == a)
    if (length(rows) < max(min_months, length(lag_terms) + length(cs_terms) + 2L)) next
    dd <- d[rows, c(".log_y", lag_terms, cs_terms)]
    area_fml <- stats::as.formula(
      paste(".log_y ~", paste(c(lag_terms, cs_terms), collapse = " + "))
    )
    fit <- rlang::try_fetch(stats::lm(area_fml, data = dd), error = function(e) NULL)
    if (is.null(fit)) next
    cf <- stats::coef(fit)[lag_terms]
    if (anyNA(cf)) next
    coefs[[a]] <- cf
    resid[rows] <- stats::resid(fit)
  }
  if (length(coefs) < 2L) {
    lamp_abort(
      c(
        "Too few areas have enough months for the mean group estimator.",
        "i" = "Lower {.arg min_months}, use fewer lags, or use {.code method = \"cce_pooled\"}."
      ),
      "input"
    )
  }
  mat <- do.call(rbind, coefs)
  n <- nrow(mat)
  est <- colMeans(mat)
  # the mean group standard error is the spread of the area coefficients
  se <- apply(mat, 2, function(x) stats::sd(x) / sqrt(n))
  z <- stats::qt(0.975, n - 1L)
  co <- tibble::tibble(
    term = lag_terms, estimate = unname(est), std_error = unname(se),
    statistic = unname(est / se), p_value = 2 * stats::pt(-abs(unname(est / se)), n - 1L),
    conf_low = unname(est - z * se), conf_high = unname(est + z * se)
  )
  total <- rowSums(mat)
  list(
    coefficients = co, model = NULL, residuals = resid,
    long_run_se = stats::sd(total) / sqrt(n),
    covariance = stats::cov(mat) / n,
    area_coefficients = tibble::as_tibble(mat, rownames = "area"),
    n_areas_used = n
  )
}

#' @export
print.lamp_elasticity <- function(x, ...) {
  print.lamp_estimate(x, ...)
  lr <- x$diagnostics$long_run
  cli::cli_text(
    "Sum over lags: {signif(lr$estimate, 3)} ",
    "[{signif(lr$conf_low, 3)}, {signif(lr$conf_high, 3)}]"
  )
  cd <- x$diagnostics$cd_test
  if (!is.null(cd)) {
    cli::cli_text(
      "Pesaran CD: {signif(cd$statistic, 3)} (p = {signif(cd$p_value, 3)}), ",
      "mean pairwise correlation {signif(cd$mean_rho, 2)}"
    )
    if (isTRUE(cd$sampled)) {
      cli::cli_text(
        "  on {cd$n_areas_used} of {cd$n_areas} areas, sampled at random with a fixed seed"
      )
    }
  }
  invisible(x)
}

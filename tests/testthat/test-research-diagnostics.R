test_that("calendar lags leave gaps, including across years and unsorted rows", {
  d <- data.frame(
    area = c("A", "A", "B", "A"),
    month = as.Date(c("2020-03-01", "2019-12-01", "2020-01-01", "2020-01-01")),
    x = c(3, 12, 99, 1)
  )
  m <- streetlamp:::lamp_lag_matrix(d, "x", c(1, 2, 100))
  expect_true(is.na(m[1, 1]))
  expect_equal(unname(m[1, 2]), 1)
  expect_equal(unname(m[4, 1]), 12)
  expect_true(all(is.na(m[, 3])))
  expect_true(is.na(m[3, 1]))
})

test_that("PPML matches the independent backend and uses its reference distribution", {
  sim <- lamp_simulate(n_areas = 30, n_months = 24, design = "continuous", seed = 83)
  fit <- lamp_elasticity(sim, "affected_crime", lags = 0)
  d <- as.data.frame(sim)
  d$x <- log1p(d$stops)
  ref <- fixest::fepois(affected_crime ~ x | area + month, data = d, cluster = ~area, notes = FALSE)
  expect_equal(fit$meta$family, "poisson")
  expect_equal(fit$coefficients$estimate, unname(stats::coef(ref)), tolerance = 1e-9)
  expect_equal(fit$coefficients$conf_low, unname(stats::confint(ref)[1, 1]), tolerance = 1e-9)
  expect_equal(fit$diagnostics$long_run$conf_low, fit$coefficients$conf_low)
  expect_match(fit$diagnostics$estimand, "conditional count mean")
  expect_equal(lamp_elasticity(sim, lags = 0, family = "ols_log")$meta$family, "ols_log")
  expect_error(lamp_elasticity(sim, lags = numeric()), class = "streetlamp_error_input")
  expect_error(lamp_elasticity(sim, lags = NA_real_), class = "streetlamp_error_input")
  expect_error(lamp_elasticity(sim, method = "cce_mg", family = "poisson"), class = "streetlamp_error_input")
})

test_that("heterogeneous and dynamic simulation truth uses the requested effect scale", {
  sim <- lamp_simulate(
    n_areas = 24, n_months = 24, adoption = c(8, 12, 16),
    cohort_effects = c("8" = -6, "12" = 3, "16" = 9), dynamic_effect = c(0, 0.5, 1),
    effect_scale = "additive", base_rate = 50, seed = 41
  )
  truth <- lamp_simulation_truth(sim)
  expect_equal(truth$effect[which(truth$cohort == 8 & truth$rel_time == 0)], rep(0, 6))
  expect_equal(truth$effect[which(truth$cohort == 8 & truth$rel_time == 1)], rep(-3, 6), tolerance = 1e-10)
  expect_equal(truth$effect[which(truth$cohort == 16 & truth$rel_time == 3)], rep(9, 6), tolerance = 1e-10)
  expect_true(all(abs(truth$effect[truth$treated == 0]) < 1e-10))
  expect_true(is.na(attr(sim, "truth")$effect_crime_total))
  # The untreated change is common across areas, even with different area effects.
  changes <- vapply(split(truth, truth$area), function(d) diff(d$mean_untreated)[1], numeric(1))
  expect_lt(diff(range(changes)), 1e-10)
  log_truth <- lamp_simulation_truth(sim, scale = "log_mean")
  expect_equal(log_truth$effect, log(log_truth$mean_treated / log_truth$mean_untreated))
  expect_error(lamp_simulate(cohort_effects = c("8" = -1)), class = "streetlamp_error_input")
  expect_error(lamp_simulate(dispersion = 0), class = "streetlamp_error_input")
  stress <- lamp_simulate(dispersion = 2, missing = 0.2, missing_mechanism = "high_outcome", seed = 2)
  expect_true(anyNA(stress$affected_crime))
  expect_false(anyNA(lamp_simulation_truth(stress)$mean_untreated))
})

test_that("effect averaging includes off-diagonal covariance and sensitivity is conditional", {
  sim <- lamp_simulate(n_areas = 36, n_months = 24, design = "event", seed = 51)
  tr <- lamp_contract(sim)$treatment
  fit <- lamp_event_study(sim, "affected_crime", tr, window = c(-4, 4))
  post <- fit$coefficients[fit$coefficients$rel_time >= 0, ]
  v <- stats::vcov(fit$model)[post$term, post$term]
  s <- lamp_effect_summary(fit)
  expect_equal(s$std_error, sqrt(sum(v)) / nrow(post), tolerance = 1e-10)
  sensitivity <- lamp_trend_sensitivity(fit, c(-0.02, 0, 0.02))
  expect_equal(sensitivity$estimate[2], s$estimate)
  expect_equal(sensitivity$bias, c(-0.02, 0, 0.02) * mean(post$rel_time + 1))
  expect_equal(sensitivity$conf_high - sensitivity$conf_low, rep(s$conf_high - s$conf_low, 3))
  expect_error(lamp_effect_summary(fit, terms = "no-such-term"), class = "streetlamp_error_input")
  expect_error(lamp_trend_sensitivity(fit, 0, reference = -2), class = "streetlamp_error_input")
  cp <- lamp_crimes_prevented(fit, sim, stops_added = 8)
  expect_equal(cp$std_error_used, s$std_error)
})

test_that("design auditing exposes weak support and grids retain all specifications", {
  sim <- lamp_simulate(n_areas = 12, n_months = 12, design = "event", missing = 0.2, seed = 70)
  audit <- lamp_design_audit(sim, lamp_contract(sim)$treatment, min_pre = 10)
  expect_true(any(audit$issues$status == "concern"))
  expect_true(any(audit$issues$status == "requires_argument"))
  expect_equal(nrow(audit$area_support), 12)
  expect_gt(audit$summary$n_unavailable, 0)
  grid <- lamp_elasticity_robustness(sim, lags = list(current = 0, impossible = 100))
  expect_equal(nrow(grid), 4L)
  expect_equal(sum(grid$status == "failed"), 2L)
  continuous <- lamp_simulate(n_areas = 8, n_months = 12, design = "continuous", seed = 4)
  loo <- lamp_elasticity_robustness(continuous,
    lags = list(current = 0),
    families = "poisson", leave_one_out = TRUE
  )
  expect_equal(nrow(loo), 9L)
  expect_equal(sum(is.na(loo$omitted_area)), 1L)
})

test_that("both staggered overall ATT weights recover noiseless heterogeneous count effects", {
  sim <- lamp_simulate(
    n_areas = 48, n_months = 24, adoption = c(8, 12, 16),
    cohort_effects = c("8" = -10, "12" = -4, "16" = 5), dynamic_effect = c(0, 0.5, 1),
    effect_scale = "additive", base_rate = 50, seed = 73
  )
  truth <- lamp_simulation_truth(sim)
  sim$affected_crime <- truth$mean_treated
  adoption <- attr(sim, "truth")$adoption
  tr <- lamp_treatment(sim, "staggered", adoption = adoption[!is.na(adoption$adoption_month), ])
  target <- mean(truth$effect[truth$treated == 1])
  for (backend in c("callaway_santanna", "sun_abraham")) {
    fit <- suppressMessages(suppressWarnings(lamp_did_staggered(sim, "affected_crime", tr,
      estimator = backend, family = "identity"
    )))
    expect_equal(lamp_effect_summary(fit)$estimate, target, tolerance = 1e-8)
  }
})

test_that("separated zero-count areas are visible in the sample audit", {
  sim <- lamp_simulate(n_areas = 12, n_months = 24, design = "continuous", seed = 12)
  sim$crime_total[sim$area == sim$area[1]] <- 0L
  fit <- lamp_elasticity(sim, lags = 0)
  expect_equal(fit$sample$n_rows[nrow(fit$sample)], stats::nobs(fit$model))
  expect_equal(fit$diagnostics$n_areas_used, 11L)
  expect_equal(fit$diagnostics$n_clusters, 11L)
})

test_that("force-clustered Callaway-Sant'Anna inference enables the required bootstrap", {
  sim <- lamp_simulate(
    n_areas = 48, n_months = 12, effect_scale = "additive",
    effect = -3, base_rate = 100, seed = 52
  )
  sim$force_id <- paste0("force", (as.integer(factor(sim$area)) - 1L) %/% 6L)
  tr <- lamp_contract(sim)$treatment
  fit <- withr::with_seed(15, suppressMessages(lamp_did_staggered(sim, "affected_crime", tr,
    family = "identity", cluster = "force"
  )))
  expect_true(fit$model$DIDparams$bstrap)
  expect_true("force_id" %in% fit$model$DIDparams$clustervars)
  expect_error(lamp_did_staggered(sim, "affected_crime", tr, estimator = "imputation", cluster = "force"),
    class = "streetlamp_error_input"
  )
})

test_that("lamp_twfe() matches fixest called directly", {
  sim <- lamp_simulate(n_areas = 20, n_months = 20, design = "event", effect = -0.2, seed = 1)
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  fit <- lamp_twfe(sim, "crime_total", tr)

  d <- tibble::as_tibble(sim)
  d$.treat <- tr$data$treat[match(
    paste(d$area, d$month), paste(tr$data$area, tr$data$month)
  )]
  d <- d[d$coverage_status %in% c("submitted", "refreshed", "partial_suspected"), ]
  d <- d[!is.na(d$crime_total) & !is.na(d$.treat), ]
  d$.area <- factor(d$area)
  d$.month <- factor(format(d$month, "%Y-%m"))
  d$.cluster <- d$.area
  ref <- fixest::fepois(crime_total ~ .treat | .area + .month, data = d, cluster = ~.cluster, notes = FALSE)

  expect_equal(fit$coefficients$estimate[1], unname(stats::coef(ref)[[".treat"]]))
  expect_equal(fit$coefficients$std_error[1], unname(fixest::se(ref)[[".treat"]]))
  expect_equal(fit$diagnostics$n_obs, stats::nobs(ref))
  z <- stats::qnorm(0.975)
  expect_equal(
    fit$coefficients$conf_low[1],
    fit$coefficients$estimate[1] - z * fit$coefficients$std_error[1]
  )
})

test_that("the event design is recovered on the affected types and on the total", {
  sim <- lamp_simulate(
    n_areas = 60, n_months = 24, design = "event", effect = -0.25,
    base_rate = 20, seed = 2
  )
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)

  # crime_total moves by less than `effect`, because bicycle theft is
  # unaffected; the simulator records the implied number
  expect_gt(truth$effect_crime_total, truth$effect)
  fit <- lamp_twfe(sim, "crime_total", tr)
  expect_lt(abs(fit$coefficients$estimate[1] - truth$effect_crime_total), 0.08)

  # an affected type on its own moves by `effect`
  violence <- lamp_twfe(sim, "violence_and_sexual_offences", tr)
  expect_lt(abs(violence$coefficients$estimate[1] - truth$effect), 0.12)

  # the placebo outcome is unaffected
  bike <- lamp_twfe(sim, "bicycle_theft", tr)
  expect_gt(bike$coefficients$p_value[1], 0.05)
})

test_that("intervals cover the truth at roughly the nominal rate", {
  skip_on_cran()
  covered <- vapply(seq_len(25), function(i) {
    sim <- lamp_simulate(
      n_areas = 40, n_months = 20, design = "event", effect = -0.2,
      base_rate = 20, seed = 100 + i
    )
    truth <- attr(sim, "truth")
    tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
    fit <- lamp_twfe(sim, "crime_total", tr)
    lo <- fit$coefficients$conf_low[1]
    hi <- fit$coefficients$conf_high[1]
    lo <= truth$effect_crime_total && truth$effect_crime_total <= hi
  }, logical(1))
  # a 95 percent interval should cover nearly always; allow for 25 draws
  expect_gte(mean(covered), 0.8)
})

test_that("every family runs and agrees on the sign", {
  sim <- lamp_simulate(n_areas = 30, n_months = 20, design = "event", effect = -0.3, seed = 3)
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  fits <- lapply(lamp_families(), function(f) lamp_twfe(sim, "crime_total", tr, family = f))
  est <- vapply(fits, function(f) f$coefficients$estimate[1], numeric(1))
  expect_true(all(est < 0))
  expect_lt(max(est) - min(est), 0.15)
  expect_true(all(!is.na(vapply(fits[1:2], function(f) f$diagnostics$dispersion, numeric(1)))))
  expect_true(is.na(fits[[3]]$diagnostics$dispersion))
  expect_equal(fits[[1]]$meta$family, "poisson")
})

test_that("controls, force-by-month effects and force clustering are honoured", {
  sim <- lamp_simulate(n_areas = 36, n_months = 20, design = "event", effect = -0.25, seed = 4)
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)

  base <- lamp_twfe(sim, "crime_total", tr)
  with_fm <- lamp_twfe(sim, "crime_total", tr, force_month = TRUE)
  expect_true(with_fm$diagnostics$force_month)
  expect_lt(abs(with_fm$coefficients$estimate[1] - truth$effect), 0.15)

  by_force <- lamp_twfe(sim, "crime_total", tr, cluster = "force")
  expect_equal(by_force$meta$cluster, "force")
  expect_equal(by_force$coefficients$estimate[1], base$coefficients$estimate[1])
  expect_false(isTRUE(all.equal(by_force$coefficients$std_error[1], base$coefficients$std_error[1])))

  sim$covariate <- as.numeric(sim$stops_s60)
  with_ctrl <- lamp_twfe(sim, "crime_total", tr, controls = "covariate")
  expect_equal(nrow(with_ctrl$coefficients), 2L)
  expect_true("covariate" %in% with_ctrl$coefficients$term)
  expect_error(lamp_twfe(sim, "crime_total", tr, controls = "nope"), class = "streetlamp_error_input")
})

test_that("force-months with no file are dropped and counted", {
  sim <- lamp_simulate(n_areas = 20, n_months = 20, design = "event", missing = 0.25, seed = 5)
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  fit <- lamp_twfe(sim, "crime_total", tr)
  n_missing <- sum(sim$coverage_status == "missing")
  expect_gt(n_missing, 0L)
  expect_equal(fit$diagnostics$n_dropped_coverage, n_missing)
  expect_equal(fit$sample$n_rows[1], nrow(sim))
  expect_equal(fit$sample$n_rows[2], nrow(sim) - n_missing)
  expect_equal(fit$diagnostics$n_obs, fit$sample$n_rows[nrow(fit$sample)])
  expect_message(print(fit), "dropped for coverage")
})

test_that("a staggered treatment warns that two-way fixed effects may be biased", {
  sim <- lamp_simulate(n_areas = 30, n_months = 30, design = "staggered", effect = -0.2, seed = 6)
  ad <- attr(sim, "truth")$adoption
  ad <- ad[!is.na(ad$adoption_month), ]
  tr <- lamp_treatment(sim, "staggered", adoption = ad)
  expect_warning(lamp_twfe(sim, "crime_total", tr), class = "streetlamp_warning_estimator")
})

test_that("a treatment reaching every area is refused with an explanation", {
  sim <- lamp_simulate(n_areas = 16, n_months = 16, design = "event", seed = 9)
  truth <- attr(sim, "truth")
  # no scope, so every area is treated on the same date: the treatment is then
  # the same thing as a month effect
  everywhere <- lamp_treatment(sim, "event", date = truth$event_date)
  err <- tryCatch(lamp_twfe(sim, "crime_total", everywhere), error = identity)
  expect_s3_class(err, "streetlamp_error_input")
  expect_match(conditionMessage(err), "Every area is treated")
  expect_match(conditionMessage(err), "scope")

  err2 <- tryCatch(lamp_event_study(sim, "crime_total", everywhere), error = identity)
  expect_s3_class(err2, "streetlamp_error_input")
  expect_match(conditionMessage(err2), "Every area is treated")
})

test_that("a treatment can also be a plain panel column", {
  sim <- lamp_simulate(n_areas = 16, n_months = 16, design = "event", seed = 7)
  fit <- lamp_twfe(sim, "crime_total", "treat")
  expect_equal(fit$coefficients$term[1], "treat")
  expect_equal(fit$meta$treatment_type, "column")
  expect_error(lamp_twfe(sim, "crime_total", "nope"), class = "streetlamp_error_input")
  expect_error(lamp_twfe(sim, "crime_total", 1), class = "streetlamp_error_input")
  expect_error(lamp_twfe(sim, "no_such_outcome", "treat"), class = "streetlamp_error_input")
  expect_error(lamp_twfe(tibble::tibble(a = 1), "crime_total", "treat"), class = "streetlamp_error_input")
  expect_error(lamp_twfe(sim, "crime_total", "treat", cluster = "month"), class = "rlang_error")
})

test_that("an estimate carries its assumption, contract, tidy form and plot", {
  sim <- lamp_simulate(n_areas = 16, n_months = 16, design = "event", seed = 8)
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  fit <- lamp_twfe(sim, "crime_total", tr)
  expect_s3_class(fit, "lamp_estimate")
  expect_s3_class(fit, "lamp_twfe")
  expect_match(fit$assumption, "Parallel trends")
  expect_s3_class(fit$contract$treatment, "lamp_treatment")
  td <- tidy(fit)
  expect_named(td, c("term", "estimate", "std_error", "statistic", "p_value", "conf_low", "conf_high"))
  expect_s3_class(plot(fit), "ggplot")
  expect_message(summary(fit), "Exclusions")
})

test_that("Moran's I is reported when the panel carries adjacency", {
  panel <- lamp_sample_panel()
  small <- panel[panel$month >= as.Date("2026-01-01"), ]
  tr <- lamp_treatment(small, "continuous", measure = "stop_rate", transform = "ihs")
  fit <- lamp_twfe(small, "crime_total", tr)
  m <- fit$diagnostics$moran
  expect_false(is.null(m))
  expect_true(is.numeric(m$statistic))
  expect_true(m$p_value >= 0 && m$p_value <= 1)
  expect_gt(m$n_areas, 100L)
})

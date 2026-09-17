test_that("pre-trends report the joint test and the trend the test would miss", {
  sim <- lamp_simulate(
    n_areas = 40, n_months = 24, design = "event", effect = -0.3,
    base_rate = 20, seed = 1
  )
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  es <- lamp_event_study(sim, "crime_total", tr, window = c(-6, 6))
  pt <- lamp_pretrends(es)

  expect_s3_class(pt, "lamp_pretrends")
  expect_equal(pt$test$df, 5L)
  expect_equal(pt$test$p_value, es$diagnostics$pretrend_p)
  expect_gt(pt$test$p_value, 0.05)
  expect_equal(nrow(pt$coefficients), 5L)

  expect_named(pt$power, c("power", "slope", "bias_mean_post"))
  expect_equal(pt$power$power, c(0.5, 0.8))
  expect_true(all(pt$power$slope > 0))
  # a trend detected only half the time must be smaller than one detected 80%
  expect_lt(pt$power$slope[1], pt$power$slope[2])
  expect_true(all(pt$power$bias_mean_post > 0))
  expect_match(pt$interpretation, "does not reject")
  expect_message(print(pt), "pre-trend")
  expect_s3_class(plot(pt), "ggplot")
})

test_that("a planted pre-trend is detected", {
  sim <- lamp_simulate(
    n_areas = 40, n_months = 24, design = "event", effect = 0,
    base_rate = 30, seed = 2
  )
  truth <- attr(sim, "truth")
  # give treated areas a rising path throughout, which is a parallel-trends
  # violation the pre-period test should catch
  treated <- sim$area %in% truth$treated_areas
  t_index <- as.integer(factor(sim$month))
  sim$crime_total <- as.integer(round(sim$crime_total * exp(0.05 * t_index * treated)))
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  es <- lamp_event_study(sim, "crime_total", tr, window = c(-6, 6))
  pt <- lamp_pretrends(es)
  expect_lt(pt$test$p_value, 0.05)
  expect_match(pt$interpretation, "doubtful")
})

test_that("pre-trends refuse estimates without relative time", {
  sim <- lamp_simulate(n_areas = 16, n_months = 16, design = "event", seed = 3)
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  fit <- lamp_twfe(sim, "crime_total", tr)
  expect_error(lamp_pretrends(fit), class = "streetlamp_error_input")
  expect_error(lamp_pretrends("not an estimate"), class = "streetlamp_error_input")
  es <- lamp_event_study(sim, "crime_total", tr, window = c(-4, 4))
  expect_error(lamp_pretrends(es, power = 1.5), class = "streetlamp_error_input")
})

test_that("a spatial placebo is centred near zero when treatment is reassigned", {
  sim <- lamp_simulate(
    n_areas = 30, n_months = 20, design = "event", effect = -0.4,
    base_rate = 20, seed = 4
  )
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  fit <- lamp_twfe(sim, "crime_total", tr)
  pl <- lamp_placebo(fit, type = "space", n = 25, seed = 1)

  expect_s3_class(pl, "lamp_placebo")
  expect_equal(pl$type, "space")
  expect_equal(nrow(pl$distribution), 25L)
  expect_gt(pl$n_valid, 20L)
  vals <- pl$distribution$estimate[is.finite(pl$distribution$estimate)]
  expect_lt(abs(stats::median(vals)), 0.15)
  expect_lt(pl$p_value, 0.2)
  expect_match(pl$interpretation, "real effect looks like")
  expect_s3_class(plot(pl), "ggplot")
})

test_that("a placebo in time uses only pre-period data", {
  sim <- lamp_simulate(
    n_areas = 30, n_months = 30, design = "event", effect = -0.4,
    base_rate = 20, seed = 5
  )
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  fit <- lamp_twfe(sim, "crime_total", tr)
  pl <- lamp_placebo(fit, type = "time", n = 8)
  expect_equal(pl$type, "time")
  expect_gt(pl$n_valid, 3L)
  vals <- pl$distribution$estimate[is.finite(pl$distribution$estimate)]
  expect_lt(abs(stats::median(vals)), 0.2)
  expect_match(pl$distribution$label[1], "^[0-9]{4}-[0-9]{2}$")
})

test_that("a placebo outcome finds nothing on an unaffected crime type", {
  sim <- lamp_simulate(
    n_areas = 30, n_months = 20, design = "event", effect = -0.4,
    base_rate = 20, seed = 6
  )
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  fit <- lamp_twfe(sim, "crime_total", tr)
  pl <- lamp_placebo(fit, type = "outcome")
  expect_equal(pl$placebo_outcome, "bicycle_theft")
  expect_lt(abs(pl$distribution$estimate[1]), abs(pl$actual))
  expect_error(lamp_placebo(fit, type = "outcome", outcome = "nope"), class = "streetlamp_error_input")
})

test_that("placebo distributions are centred on zero when there is no real effect", {
  sim <- lamp_simulate(
    n_areas = 30, n_months = 20, design = "event", effect = 0,
    base_rate = 20, seed = 7
  )
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  fit <- lamp_twfe(sim, "crime_total", tr)
  pl <- lamp_placebo(fit, type = "space", n = 30, seed = 2)
  vals <- pl$distribution$estimate[is.finite(pl$distribution$estimate)]
  expect_lt(abs(mean(vals)), 0.1)
  # with no real effect the real estimate sits inside the placebo spread
  expect_gt(pl$p_value, 0.1)
  expect_match(pl$interpretation, "where none should exist")
})

test_that("placebo tests validate their input", {
  sim <- lamp_simulate(n_areas = 16, n_months = 16, design = "continuous", seed = 8)
  tr <- lamp_treatment(sim, "continuous")
  fit <- lamp_twfe(sim, "crime_total", tr)
  expect_error(lamp_placebo(fit, type = "time"), class = "streetlamp_error_input")
  expect_error(lamp_placebo(fit, type = "space"), class = "streetlamp_error_input")
  expect_error(lamp_placebo("not an estimate"), class = "streetlamp_error_input")
  stripped <- fit
  stripped$data <- NULL
  expect_error(lamp_placebo(stripped, type = "space"), class = "streetlamp_error_input")
})

test_that("an event study placebo summarises the post-period coefficients", {
  sim <- lamp_simulate(
    n_areas = 24, n_months = 20, design = "event", effect = -0.4,
    base_rate = 20, seed = 9
  )
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  es <- lamp_event_study(sim, "crime_total", tr, window = c(-4, 4))
  pl <- lamp_placebo(es, type = "space", n = 10, seed = 3)
  post <- es$coefficients[es$coefficients$rel_time >= 0, ]
  expect_equal(pl$actual, mean(post$estimate))
  expect_gt(pl$n_valid, 5L)
})

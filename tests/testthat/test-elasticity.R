test_that("the mean group estimator matches a hand-computed two-area example", {
  # Two areas, each with its own slope. The mean group estimate must be the
  # mean of the two area regressions, and its standard error the spread of
  # those two coefficients.
  months <- seq(as.Date("2020-01-01"), by = "month", length.out = 24)
  set.seed(42)
  mk <- function(area, slope) {
    stops <- rep(c(4, 9, 6, 14, 3, 11), length.out = length(months))
    crime <- round(exp(3 + slope * log1p(stops) + stats::rnorm(length(months), 0, 0.02)))
    tibble::tibble(area = area, month = months, stops = stops, crime_total = crime)
  }
  d <- dplyr::bind_rows(mk("A", -0.4), mk("B", -0.1))
  d$force_id <- "f"
  d$coverage_status <- "submitted"
  panel <- streetlamp:::new_lamp_panel(d, streetlamp:::new_lamp_contract(geography = list(area = "test")))

  fit <- lamp_elasticity(panel, "crime_total", lags = 0, method = "cce_mg", min_months = 10)
  areas <- fit$diagnostics$area_coefficients
  expect_equal(nrow(areas), 2L)

  # by hand: each area's own regression of log crime on log stops and the
  # cross-sectional averages
  by_hand <- vapply(c("A", "B"), function(a) {
    dd <- d[d$area == a, ]
    dd$ly <- log1p(dd$crime_total)
    dd$ls <- log1p(dd$stops)
    cs_y <- tapply(log1p(d$crime_total), d$month, mean)
    cs_s <- tapply(log1p(d$stops), d$month, mean)
    dd$cy <- as.numeric(cs_y[as.character(dd$month)])
    dd$cs <- as.numeric(cs_s[as.character(dd$month)])
    unname(stats::coef(stats::lm(ly ~ ls + cy + cs, data = dd))[["ls"]])
  }, numeric(1))

  expect_equal(sort(areas$.log_s_lag0), sort(unname(by_hand)), tolerance = 1e-8)
  expect_equal(fit$coefficients$estimate[1], mean(by_hand), tolerance = 1e-8)
  expect_equal(
    fit$coefficients$std_error[1],
    stats::sd(by_hand) / sqrt(2),
    tolerance = 1e-8
  )
  expect_equal(fit$diagnostics$n_areas_used, 2L)
})

test_that("lags enter as distributed lags within each area", {
  months <- seq(as.Date("2020-01-01"), by = "month", length.out = 8)
  d <- tibble::tibble(
    area = rep(c("A", "B"), each = 8),
    month = rep(months, 2),
    x = c(1:8, 11:18)
  )
  lagged <- streetlamp:::lamp_lag_matrix(d, "x", 0:2)
  expect_equal(colnames(lagged), c("x_lag0", "x_lag1", "x_lag2"))
  expect_equal(lagged[1:8, "x_lag0"], 1:8)
  # the first months of an area have no history, and no value leaks across areas
  expect_true(is.na(lagged[1, "x_lag1"]))
  expect_equal(unname(lagged[2, "x_lag1"]), 1)
  expect_true(is.na(lagged[9, "x_lag1"]))
  expect_true(is.na(lagged[10, "x_lag2"]))
  expect_equal(unname(lagged[11, "x_lag2"]), 11)
})

test_that("the three methods run and report the CD test", {
  sim <- lamp_simulate(
    n_areas = 40, n_months = 36, design = "continuous", effect = -0.2,
    base_rate = 20, seed = 2
  )
  fits <- lapply(c("fe", "cce_pooled", "cce_mg"), function(m) {
    lamp_elasticity(sim, "crime_total", lags = 0:1, method = m)
  })
  for (f in fits) {
    expect_s3_class(f, "lamp_elasticity")
    expect_equal(nrow(f$coefficients), 2L)
    expect_lt(f$diagnostics$long_run$estimate, 0)
    cd <- f$diagnostics$cd_test
    expect_false(is.null(cd))
    expect_true(is.finite(cd$statistic))
    expect_gt(cd$n_areas, 30L)
  }
  # the CD test is computed on area-effect residuals, where a shared seasonal
  # factor shows up as positive correlation
  expect_gt(fits[[1]]$diagnostics$cd_test$statistic, 0)
  expect_lt(fits[[1]]$diagnostics$cd_test$p_value, 0.05)
  expect_message(print(fits[[1]]), "Pesaran CD")
})

test_that("the long-run sum and its interval are reported", {
  sim <- lamp_simulate(n_areas = 30, n_months = 30, design = "continuous", seed = 3)
  fit <- lamp_elasticity(sim, "crime_total", lags = 0:2)
  lr <- fit$diagnostics$long_run
  expect_equal(lr$estimate, sum(fit$coefficients$estimate), tolerance = 1e-10)
  expect_lt(lr$conf_low, lr$estimate)
  expect_gt(lr$conf_high, lr$estimate)
  expect_equal(fit$diagnostics$lags, 0:2)
  expect_equal(nrow(fit$coefficients), 3L)
  # rows without the full lag history are dropped and counted
  steps <- fit$sample$step
  expect_true(any(grepl("lag history", steps)))
  expect_lt(fit$sample$n_rows[nrow(fit$sample)], nrow(sim))
})

test_that("the elasticity names its own limits and validates input", {
  sim <- lamp_simulate(n_areas = 20, n_months = 24, design = "continuous", seed = 4)
  fit <- lamp_elasticity(sim, "crime_total", lags = 0)
  expect_match(fit$assumption, "lamp_allocation")
  expect_match(fit$assumption, "association")

  expect_error(lamp_elasticity(sim, "nope"), class = "streetlamp_error_input")
  expect_error(lamp_elasticity(sim, "crime_total", stops = "nope"), class = "streetlamp_error_input")
  expect_error(lamp_elasticity(sim, "crime_total", lags = -1), class = "streetlamp_error_input")
  expect_error(lamp_elasticity(sim, "crime_total", method = "nope"), class = "rlang_error")
  expect_error(
    lamp_elasticity(sim, "crime_total", lags = 0, method = "cce_mg", min_months = 500),
    class = "streetlamp_error_input"
  )
})

test_that("the allocation model finds a planted response and calls itself descriptive", {
  sim <- lamp_simulate(
    n_areas = 40, n_months = 36, design = "continuous", base_rate = 20, seed = 5
  )
  d <- sim[order(sim$area, sim$month), ]
  lagged <- stats::ave(d$crime_total, d$area, FUN = function(x) c(NA, utils::head(x, -1)))
  d$stops <- as.integer(d$stops + ifelse(is.na(lagged), 0, round(0.5 * lagged)))

  fit <- lamp_allocation(d, crime_lags = 1:2)
  expect_s3_class(fit, "lamp_allocation")
  expect_gt(fit$diagnostics$total$conf_low, 0)
  expect_match(fit$diagnostics$interpretation, "follows recorded crime")
  expect_match(fit$assumption, "descriptive")
  expect_equal(fit$meta$outcome, "stops")
  expect_message(print(fit), "Sum over lags")

  # with no allocation response the interpretation says so
  plain <- lamp_allocation(sim, crime_lags = 1:2)
  expect_match(plain$diagnostics$interpretation, "No clear allocation response")

  expect_error(lamp_allocation(sim, crime_lags = 0), class = "streetlamp_error_input")
  expect_error(lamp_allocation(sim, stops = "nope"), class = "streetlamp_error_input")
})

test_that("crimes prevented converts an elasticity and carries the assumption chain", {
  sim <- lamp_simulate(
    n_areas = 30, n_months = 30, design = "continuous", effect = -0.2,
    base_rate = 20, seed = 6
  )
  el <- lamp_elasticity(sim, "crime_total", lags = 0:1)
  cp <- lamp_crimes_prevented(el, sim, per_stops = 1000, seed = 1)

  expect_s3_class(cp, "lamp_crimes_prevented")
  # the arithmetic: -elasticity * mean crime * per_stops / mean stops
  usable <- sim[sim$coverage_status == "submitted", ]
  expected <- -el$diagnostics$long_run$estimate *
    mean(usable$crime_total, na.rm = TRUE) * 1000 / mean(usable$stops, na.rm = TRUE)
  expect_equal(cp$crimes_prevented, expected, tolerance = 1e-8)
  expect_lt(cp$conf_low, cp$crimes_prevented)
  expect_gt(cp$conf_high, cp$crimes_prevented)

  expect_gte(length(cp$assumptions), 5L)
  expect_true(any(grepl("Recorded crime only", cp$assumptions)))
  expect_true(any(grepl("diminishing returns", cp$assumptions)))
  expect_true(any(grepl("lamp_allocation", cp$assumptions)))
  expect_message(print(cp), "Assumption chain")
})

test_that("crimes prevented converts a treatment effect only with the searches it added", {
  sim <- lamp_simulate(
    n_areas = 30, n_months = 24, design = "event", effect = -0.3,
    base_rate = 20, seed = 7
  )
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  fit <- lamp_twfe(sim, "crime_total", tr)

  expect_error(lamp_crimes_prevented(fit, sim), class = "streetlamp_error_input")
  cp <- lamp_crimes_prevented(fit, sim, stops_added = 8, seed = 1)
  usable <- sim[sim$coverage_status == "submitted", ]
  b <- fit$coefficients$estimate[1]
  expected <- -mean(usable$crime_total, na.rm = TRUE) * (exp(b) - 1) * 1000 / 8
  expect_equal(cp$crimes_prevented, expected, tolerance = 1e-8)
  expect_equal(cp$stops_added, 8)
  expect_true(any(grepl("added 8 searches", cp$assumptions)))

  expect_error(lamp_crimes_prevented("not an estimate", sim), class = "streetlamp_error_input")
  expect_error(lamp_crimes_prevented(fit, sim, stops_added = 8, per_stops = -1), class = "streetlamp_error_input")
})

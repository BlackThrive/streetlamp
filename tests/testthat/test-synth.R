test_that("the simplex projection returns valid weights", {
  p <- streetlamp:::lamp_project_simplex(c(0.5, 0.2, 0.9))
  expect_equal(sum(p), 1, tolerance = 1e-12)
  expect_true(all(p >= 0))
  # an already-valid point is unchanged
  q <- streetlamp:::lamp_project_simplex(c(0.2, 0.3, 0.5))
  expect_equal(q, c(0.2, 0.3, 0.5), tolerance = 1e-10)
  # negatives are clipped away
  r <- streetlamp:::lamp_project_simplex(c(-5, 0, 5))
  expect_true(all(r >= 0))
  expect_equal(sum(r), 1, tolerance = 1e-12)
})

test_that("synthetic weights reproduce a donor mixture exactly", {
  set.seed(1)
  donors <- matrix(stats::rnorm(60),
    nrow = 20, ncol = 3,
    dimnames = list(NULL, c("d1", "d2", "d3"))
  )
  true_w <- c(0.5, 0.3, 0.2)
  treated <- as.numeric(donors %*% true_w)
  w <- streetlamp:::lamp_synth_weights(treated, donors)
  expect_equal(sum(w), 1, tolerance = 1e-6)
  expect_true(all(w >= -1e-8))
  expect_equal(unname(w), true_w, tolerance = 0.02)
})

test_that("synthetic control tracks the treated unit and finds a planted effect", {
  skip_on_cran()
  sim <- lamp_simulate(
    n_areas = 30, n_months = 40, design = "event", effect = -0.5,
    base_rate = 60, seed = 1
  )
  truth <- attr(sim, "truth")
  sc <- lamp_synth(
    sim, "crime_total",
    treated_unit = truth$treated_areas[1],
    treatment_start = truth$event_date,
    donors = setdiff(unique(sim$area), truth$treated_areas)
  )
  expect_s3_class(sc, "lamp_synth")
  expect_equal(sc$treated_unit, truth$treated_areas[1])
  expect_equal(nrow(sc$path), length(unique(sim$month)))
  expect_named(sc$path, c("month", "observed", "synthetic", "gap", "period"))

  # the pre-period fit is close and the post-period gap is negative
  expect_lt(sc$pre_fit_ratio, 1)
  expect_lt(sc$effect, 0)
  expect_gt(sc$rmspe_ratio, 1)
  expect_true(all(sc$weights >= 0))
  expect_lte(sum(sc$weights), 1.0001)
  expect_gt(nrow(sc$placebos), 5L)
  expect_true(is.finite(sc$p_value))
  expect_message(print(sc), "synthetic control")
  expect_s3_class(plot(sc), "ggplot")
})

test_that("a null effect gives a gap no larger than the donors' own", {
  skip_on_cran()
  sim <- lamp_simulate(
    n_areas = 30, n_months = 40, design = "event", effect = 0,
    base_rate = 60, seed = 2
  )
  truth <- attr(sim, "truth")
  sc <- lamp_synth(
    sim, "crime_total",
    treated_unit = truth$treated_areas[1],
    treatment_start = truth$event_date,
    donors = setdiff(unique(sim$area), truth$treated_areas)
  )
  expect_gt(sc$p_value, 0.1)
  # either the gap is unremarkable, or the pre-period fit was too poor to
  # read anything from: both say there is no effect to report
  expect_match(sc$interpretation, "not unusual|does not track")
})

test_that("synthetic control validates its inputs", {
  sim <- lamp_simulate(n_areas = 12, n_months = 20, design = "event", seed = 3)
  truth <- attr(sim, "truth")
  expect_error(
    lamp_synth(sim, "crime_total", treated_unit = "nowhere", treatment_start = truth$event_date),
    class = "streetlamp_error_input"
  )
  expect_error(
    lamp_synth(sim, "nope", treated_unit = truth$treated_areas[1], treatment_start = truth$event_date),
    class = "streetlamp_error_input"
  )
  # too few pre-period months
  expect_error(
    lamp_synth(
      sim, "crime_total", truth$treated_areas[1],
      treatment_start = min(sim$month), min_pre = 6
    ),
    class = "streetlamp_error_input"
  )
  # too few donors
  expect_error(
    lamp_synth(
      sim, "crime_total", truth$treated_areas[1], truth$event_date,
      donors = truth$treated_areas[2]
    ),
    class = "streetlamp_error_input"
  )
})

test_that("the Synth backend is used when asked for and available", {
  skip_if_not_installed("Synth")
  skip_on_cran()
  sim <- lamp_simulate(
    n_areas = 16, n_months = 30, design = "event", effect = -0.4,
    base_rate = 50, seed = 4
  )
  truth <- attr(sim, "truth")
  sc <- lamp_synth(
    sim, "crime_total", truth$treated_areas[1], truth$event_date,
    donors = setdiff(unique(sim$area), truth$treated_areas),
    method = "synth", placebo = FALSE
  )
  expect_equal(sc$method, "synth")
  expect_true(all(sc$weights >= -1e-6))
  expect_lt(sc$effect, 0)
})

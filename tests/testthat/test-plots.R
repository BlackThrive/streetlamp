# Visual regression tests for every plot method.
#
# The other tests assert that `plot()` returns a ggplot, which catches a method
# that errors and nothing else: a panel plotted with the wrong series, a
# coverage heat map that stops shading the missing months, or an event study
# whose reference period drifts all return a perfectly good ggplot. These
# compare the rendered SVG against a stored baseline.
#
# Skipped on CRAN, as the specification requires, and skipped when vdiffr is
# not installed. Baselines are written by the graphics engine and a ggplot2
# release can change them legitimately; when that happens, look at the diff
# `testthat::snapshot_review()` shows before accepting it.

skip_if_no_vdiffr <- function() {
  skip_on_cran()
  skip_if_not_installed("vdiffr")
  skip_if_not_installed("ggplot2")
}

# One simulated panel behind most of the plots, with force-month missingness
# so that the coverage heat map has something to shade.
plot_fixture <- function() {
  sim <- lamp_simulate(
    n_areas = 36, n_months = 24, design = "event", effect = -0.3,
    base_rate = 20, missing = 0.12, seed = 404
  )
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  list(sim = sim, truth = truth, tr = tr)
}

test_that("the panel and its coverage audit look the way they did", {
  skip_if_no_vdiffr()
  f <- plot_fixture()
  vdiffr::expect_doppelganger("panel small multiples", plot(f$sim))
  vdiffr::expect_doppelganger("coverage heat map", plot(lamp_coverage(f$sim)))
})

test_that("the estimator plots look the way they did", {
  skip_if_no_vdiffr()
  f <- plot_fixture()

  fit <- lamp_twfe(f$sim, "crime_total", f$tr)
  vdiffr::expect_doppelganger("twfe coefficients", plot(fit))

  es <- lamp_event_study(f$sim, "crime_total", f$tr, window = c(-6, 6))
  vdiffr::expect_doppelganger("event study", plot(es))

  vdiffr::expect_doppelganger("pre-trends", plot(lamp_pretrends(es)))
  vdiffr::expect_doppelganger(
    "placebo in space",
    plot(lamp_placebo(fit, type = "space", n = 30, seed = 404))
  )
})

test_that("the staggered and synthetic control plots look the way they did", {
  skip_if_no_vdiffr()

  staggered <- lamp_simulate(
    n_areas = 36, n_months = 30, design = "staggered", effect = -0.3,
    base_rate = 20, seed = 405
  )
  adoption <- attr(staggered, "truth")$adoption
  adoption <- adoption[!is.na(adoption$adoption_month), ]
  tr <- lamp_treatment(staggered, "staggered", adoption = adoption)
  did <- suppressWarnings(lamp_did_staggered(staggered, "crime_total", tr))
  vdiffr::expect_doppelganger("staggered difference-in-differences", plot(did))

  event <- lamp_simulate(
    n_areas = 30, n_months = 40, design = "event", effect = -0.5,
    base_rate = 60, seed = 406
  )
  truth <- attr(event, "truth")
  sc <- lamp_synth(
    event, "crime_total",
    treated_unit = truth$treated_areas[1],
    treatment_start = truth$event_date,
    donors = setdiff(unique(event$area), truth$treated_areas)
  )
  vdiffr::expect_doppelganger("synthetic control path", plot(sc))
})

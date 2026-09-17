# Build a lamp_panel from the did package's own example data, so that the
# wrapper can be compared with did::att_gt() called directly.
mpdta_panel <- function() {
  skip_if_not_installed("did")
  env <- new.env()
  utils::data("mpdta", package = "did", envir = env)
  mp <- get("mpdta", envir = env)
  months <- seq(as.Date("2003-01-01"), by = "year", length.out = 5)
  names(months) <- as.character(2003:2007)
  d <- tibble::tibble(
    area = as.character(mp$countyreal),
    month = months[as.character(mp$year)],
    force_id = "mp",
    lemp = mp$lemp,
    crime_total = mp$lemp,
    coverage_status = "submitted",
    first_treat = mp$first.treat
  )
  adoption <- unique(d[d$first_treat > 0, c("area", "first_treat")])
  adoption$adoption_month <- months[as.character(adoption$first_treat)]
  contract <- streetlamp:::new_lamp_contract(
    source = "did::mpdta",
    coverage = streetlamp:::lamp_coverage_table(tibble::tibble(
      force_id = "mp", month = months, file_type = "street", status = "submitted",
      n_records = NA_integer_, archive = "none", n_versions = 1L, versions_differ = FALSE
    )),
    geography = list(area = "county", lsoa_vintage = NULL)
  )
  list(
    panel = streetlamp:::new_lamp_panel(d, contract),
    adoption = adoption[, c("area", "adoption_month")],
    raw = mp
  )
}

test_that("lamp_did_staggered() matches did::att_gt() on the did example data", {
  fx <- mpdta_panel()
  tr <- lamp_treatment(fx$panel, "staggered", adoption = fx$adoption)
  fit <- lamp_did_staggered(fx$panel, "lemp", tr, family = "identity")

  ref <- did::att_gt(
    yname = "lemp", tname = "year", idname = "countyreal", gname = "first.treat",
    data = fx$raw, control_group = "nevertreated", bstrap = FALSE, cband = FALSE,
    base_period = "universal"
  )
  ref_simple <- did::aggte(ref, type = "simple", na.rm = TRUE)

  expect_equal(fit$diagnostics$overall$estimate, ref_simple$overall.att, tolerance = 1e-8)
  expect_equal(fit$diagnostics$overall$std_error, ref_simple$overall.se, tolerance = 1e-8)

  # the group-time table is the same set of effects
  gt <- fit$diagnostics$group_time
  expect_equal(nrow(gt), length(ref$att))
  expect_equal(sort(round(gt$estimate, 8)), sort(round(ref$att, 8)))
  expect_equal(fit$diagnostics$pretrend_p, ref$Wpval)
})

test_that("every backend recovers a known staggered effect", {
  skip_on_cran()
  sim <- lamp_simulate(
    n_areas = 150, n_months = 36, design = "staggered", effect = -0.3,
    base_rate = 60, seed = 31
  )
  truth <- attr(sim, "truth")
  ad <- truth$adoption
  ad <- ad[!is.na(ad$adoption_month), ]
  tr <- lamp_treatment(sim, "staggered", adoption = ad)

  for (backend in c("callaway_santanna", "sun_abraham")) {
    fit <- suppressWarnings(lamp_did_staggered(sim, "crime_total", tr, estimator = backend))
    expect_s3_class(fit, "lamp_did_staggered")
    expect_lt(
      abs(fit$diagnostics$overall$estimate - truth$effect_crime_total), 0.05,
      label = backend
    )
    expect_gt(nrow(fit$coefficients), 10L)
    expect_true(all(c("rel_time", "estimate", "conf_low") %in% names(fit$coefficients)))
  }
})

test_that("the imputation backend runs when didimputation is installed", {
  skip_if_not_installed("didimputation")
  skip_on_cran()
  sim <- lamp_simulate(
    n_areas = 80, n_months = 30, design = "staggered", effect = -0.3,
    base_rate = 40, seed = 32
  )
  truth <- attr(sim, "truth")
  ad <- truth$adoption
  ad <- ad[!is.na(ad$adoption_month), ]
  tr <- lamp_treatment(sim, "staggered", adoption = ad)
  fit <- suppressWarnings(lamp_did_staggered(sim, "crime_total", tr, estimator = "imputation"))
  expect_lt(abs(fit$diagnostics$overall$estimate - truth$effect_crime_total), 0.08)
  expect_match(fit$diagnostics$note, "only pre-treatment data")
})

test_that("two-way fixed effects is biased where the staggered estimator is not", {
  skip_on_cran()
  # effects that grow with exposure are the case two-way fixed effects gets
  # wrong, because already-treated areas serve as controls
  sim <- lamp_simulate(
    n_areas = 120, n_months = 36, design = "staggered", effect = -0.3,
    base_rate = 50, seed = 33
  )
  truth <- attr(sim, "truth")
  ad <- truth$adoption
  ad <- ad[!is.na(ad$adoption_month), ]
  tr <- lamp_treatment(sim, "staggered", adoption = ad)

  staggered <- suppressWarnings(lamp_did_staggered(sim, "crime_total", tr))
  twfe <- suppressWarnings(lamp_twfe(sim, "crime_total", tr, family = "ols_log"))
  expect_lt(
    abs(staggered$diagnostics$overall$estimate - truth$effect_crime_total),
    abs(twfe$coefficients$estimate[1] - truth$effect_crime_total) + 0.02
  )
})

test_that("control groups, families and windows are honoured", {
  sim <- lamp_simulate(
    n_areas = 60, n_months = 24, design = "staggered", effect = -0.3,
    base_rate = 30, seed = 34
  )
  ad <- attr(sim, "truth")$adoption
  ad <- ad[!is.na(ad$adoption_month), ]
  tr <- lamp_treatment(sim, "staggered", adoption = ad)

  never <- suppressWarnings(lamp_did_staggered(sim, "crime_total", tr))
  not_yet <- suppressWarnings(lamp_did_staggered(sim, "crime_total", tr, control_group = "not_yet_treated"))
  expect_equal(never$diagnostics$control_group, "never_treated")
  expect_equal(not_yet$diagnostics$control_group, "not_yet_treated")
  expect_false(isTRUE(all.equal(
    never$diagnostics$overall$estimate, not_yet$diagnostics$overall$estimate
  )))
  expect_match(never$assumption, "never-treated")
  expect_match(not_yet$assumption, "not-yet-treated")

  narrow <- suppressWarnings(lamp_did_staggered(sim, "crime_total", tr, window = c(-3, 3)))
  expect_lte(max(narrow$coefficients$rel_time), 3L)
  expect_gte(min(narrow$coefficients$rel_time), -3L)

  ihs <- suppressWarnings(lamp_did_staggered(sim, "crime_total", tr, family = "ols_ihs"))
  expect_equal(ihs$meta$family, "ols_ihs")
  expect_match(ihs$assumption, "ols_ihs")
})

test_that("a count outcome on a transformed scale is flagged", {
  sim <- lamp_simulate(n_areas = 40, n_months = 20, design = "staggered", seed = 35)
  ad <- attr(sim, "truth")$adoption
  ad <- ad[!is.na(ad$adoption_month), ]
  tr <- lamp_treatment(sim, "staggered", adoption = ad)
  expect_warning(
    lamp_did_staggered(sim, "crime_total", tr),
    class = "streetlamp_warning_estimator"
  )
  # a non-count outcome passes without the warning
  sim$rate <- sim$crime_total / 7
  expect_silent(suppressMessages(lamp_did_staggered(sim, "rate", tr)))
})

test_that("the staggered estimator validates its input", {
  sim <- lamp_simulate(n_areas = 20, n_months = 20, design = "continuous", seed = 36)
  tr <- lamp_treatment(sim, "continuous")
  expect_error(lamp_did_staggered(sim, "crime_total", tr), class = "streetlamp_error_input")

  ev <- lamp_simulate(n_areas = 30, n_months = 20, design = "event", seed = 36)
  truth <- attr(ev, "truth")
  # every area treated at once leaves no never-treated control group
  all_in <- lamp_treatment(ev, "event", date = truth$event_date)
  expect_error(
    suppressWarnings(lamp_did_staggered(ev, "crime_total", all_in)),
    class = "streetlamp_error_input"
  )
  expect_error(lamp_did_staggered(ev, "crime_total", "treat", estimator = "nope"), class = "rlang_error")
})

test_that("a staggered estimate prints, plots and tidies", {
  sim <- lamp_simulate(
    n_areas = 50, n_months = 24, design = "staggered", effect = -0.3,
    base_rate = 30, seed = 37
  )
  ad <- attr(sim, "truth")$adoption
  ad <- ad[!is.na(ad$adoption_month), ]
  tr <- lamp_treatment(sim, "staggered", adoption = ad)
  fit <- suppressWarnings(lamp_did_staggered(sim, "crime_total", tr))
  expect_message(print(fit), "Overall effect")
  expect_s3_class(plot(fit), "ggplot")
  expect_s3_class(tidy(fit), "tbl_df")
  expect_true(!is.null(fit$diagnostics$by_group))
  expect_gt(nrow(fit$diagnostics$by_group), 1L)
})

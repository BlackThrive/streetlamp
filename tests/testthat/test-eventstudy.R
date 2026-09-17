test_that("an event study recovers the path of the effect", {
  sim <- lamp_simulate(
    n_areas = 60, n_months = 24, design = "event", effect = -0.3,
    base_rate = 20, seed = 1
  )
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  es <- lamp_event_study(sim, "crime_total", tr, window = c(-6, 6))

  expect_s3_class(es, "lamp_event_study")
  expect_true(all(c("rel_time", "estimate", "conf_low", "conf_high") %in% names(es$coefficients)))
  expect_equal(range(es$coefficients$rel_time), c(-6L, 6L))
  expect_equal(nrow(es$coefficients), 13L)

  # the reference month is exactly zero with no interval
  ref <- es$coefficients[es$coefficients$rel_time == -1, ]
  expect_equal(ref$estimate, 0)
  expect_equal(ref$conf_low, 0)

  pre <- es$coefficients[es$coefficients$rel_time < 0 & es$coefficients$rel_time != -1, ]
  post <- es$coefficients[es$coefficients$rel_time >= 0, ]
  expect_lt(abs(mean(pre$estimate)), 0.1)
  expect_lt(abs(mean(post$estimate) - truth$effect_crime_total), 0.12)
  expect_equal(es$diagnostics$n_pre, 6L)
  expect_equal(es$diagnostics$n_post, 7L)
  # the joint pre-trend test restricts itself to the pre-period coefficients
  expect_equal(es$diagnostics$pretrend$df1, 5)
})

test_that("the pre-trend test rejects at about its nominal rate when trends are parallel", {
  skip_on_cran()
  p <- vapply(seq_len(20), function(i) {
    sim <- lamp_simulate(
      n_areas = 40, n_months = 24, design = "event", effect = -0.2,
      base_rate = 20, seed = 200 + i
    )
    truth <- attr(sim, "truth")
    tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
    es <- lamp_event_study(sim, "crime_total", tr, window = c(-6, 6))
    es$diagnostics$pretrend_p
  }, numeric(1))
  # with truly parallel trends the test should reject rarely
  expect_lt(mean(p < 0.05), 0.25)
  expect_gt(stats::median(p), 0.15)
})

test_that("the window bins endpoints and the reference month can be moved", {
  sim <- lamp_simulate(n_areas = 30, n_months = 24, design = "event", effect = -0.2, seed = 2)
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)

  narrow <- lamp_event_study(sim, "crime_total", tr, window = c(-3, 3))
  expect_equal(range(narrow$coefficients$rel_time), c(-3L, 3L))
  expect_equal(nrow(narrow$coefficients), 7L)
  # every row still contributes to the fixed effects
  expect_equal(narrow$sample$n_rows[nrow(narrow$sample)], sum(!is.na(sim$crime_total)))

  moved <- lamp_event_study(sim, "crime_total", tr, window = c(-6, 6), reference = -2)
  expect_equal(moved$coefficients$estimate[moved$coefficients$rel_time == -2], 0)
  expect_equal(moved$meta$reference, -2L)
  expect_false(any(moved$coefficients$estimate[moved$coefficients$rel_time == -1] == 0))

  expect_error(lamp_event_study(sim, "crime_total", tr, window = c(6, -6)), class = "streetlamp_error_input")
  expect_error(lamp_event_study(sim, "crime_total", tr, reference = -99), class = "streetlamp_error_input")
  expect_error(lamp_event_study(sim, "crime_total", tr, reference = c(-1, -2)), class = "streetlamp_error_input")
})

test_that("the event study refuses plain two-way fixed effects under staggered adoption", {
  sim <- lamp_simulate(n_areas = 36, n_months = 30, design = "staggered", effect = -0.2, seed = 3)
  ad <- attr(sim, "truth")$adoption
  ad <- ad[!is.na(ad$adoption_month), ]
  tr <- lamp_treatment(sim, "staggered", adoption = ad)
  expect_gt(tr$details$n_cohorts, 1L)

  err <- tryCatch(lamp_event_study(sim, "crime_total", tr), error = identity)
  expect_s3_class(err, "streetlamp_error_estimator")
  msg <- conditionMessage(err)
  expect_match(msg, "different dates")

  # asked to, it hands the work to the staggered estimator and says so
  expect_message(
    handed <- suppressWarnings(
      lamp_event_study(sim, "crime_total", tr, staggered_ok = TRUE)
    ),
    class = "streetlamp_message_estimator"
  )
  expect_s3_class(handed, "lamp_did_staggered")

  # a single adoption date is fine
  one <- ad
  one$adoption_month <- min(ad$adoption_month)
  tr_one <- lamp_treatment(sim, "staggered", adoption = one)
  expect_s3_class(lamp_event_study(sim, "crime_total", tr_one, window = c(-4, 4)), "lamp_event_study")
})

test_that("an event study needs relative time and a treated area", {
  sim <- lamp_simulate(n_areas = 16, n_months = 16, design = "continuous", seed = 4)
  tr <- lamp_treatment(sim, "continuous")
  expect_error(lamp_event_study(sim, "crime_total", tr), class = "streetlamp_error_input")

  ev <- lamp_simulate(n_areas = 16, n_months = 16, design = "event", seed = 4)
  truth <- attr(ev, "truth")
  none <- lamp_treatment(ev, "event", date = truth$event_date, scope = character())
  expect_error(lamp_event_study(ev, "crime_total", none), class = "streetlamp_error_input")
})

test_that("the event study prints by relative time and plots with the pre-period shaded", {
  sim <- lamp_simulate(n_areas = 24, n_months = 20, design = "event", effect = -0.25, seed = 5)
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  es <- lamp_event_study(sim, "crime_total", tr, window = c(-5, 5))
  out <- capture.output(print(es), type = "message")
  expect_true(any(grepl("Pre-trend joint test", out)))
  p <- plot(es)
  expect_s3_class(p, "ggplot")
  expect_match(p$labels$subtitle, "pre-trend joint test")
  expect_s3_class(tidy(es), "tbl_df")
})

test_that("a continuous treatment offers three measures and three transforms", {
  sim <- lamp_simulate(n_areas = 16, n_months = 24, design = "continuous", seed = 1)
  tr <- lamp_treatment(sim, "continuous")
  expect_s3_class(tr, "lamp_treatment")
  expect_equal(tr$type, "continuous")
  expect_equal(tr$column, "treat")
  expect_equal(tr$details$measure, "stop_rate")
  expect_equal(tr$details$transform, "identity")
  expect_named(tr$data, c("area", "month", "rel_time", "cohort", "treat"))
  expect_equal(tr$data$treat, sim$stop_rate)

  raw <- lamp_treatment(sim, "continuous", measure = "stops")
  expect_equal(raw$data$treat, as.numeric(sim$stops))
  logged <- lamp_treatment(sim, "continuous", measure = "stops", transform = "log")
  expect_equal(logged$data$treat, log1p(as.numeric(sim$stops)))
  ihs <- lamp_treatment(sim, "continuous", measure = "stops", transform = "ihs")
  expect_equal(ihs$data$treat, asinh(as.numeric(sim$stops)))

  per100 <- lamp_treatment(sim, "continuous", measure = "stops_per_100_crimes")
  expect_equal(per100$details$measure, "stops_per_100_crimes")
  # the first month of each area has no history
  first <- per100$data[per100$data$month == min(per100$data$month), ]
  expect_true(all(is.na(first$treat)))
  expect_false(all(is.na(per100$data$treat)))
  expect_message(print(tr), "continuous")
})

test_that("a binary treatment marks named areas inside a window", {
  sim <- lamp_simulate(n_areas = 20, n_months = 24, seed = 2)
  areas <- sort(unique(sim$area))[1:5]
  tr <- lamp_treatment(sim, "binary", areas = areas, window = c("2018-06", "2018-11"))
  expect_equal(tr$type, "binary")
  expect_equal(tr$n_treated_areas, 5L)
  expect_equal(tr$n_control_areas, 15L)
  on <- tr$data$treat > 0
  expect_true(all(tr$data$area[on] %in% areas))
  expect_true(all(tr$data$month[on] >= as.Date("2018-06-01")))
  expect_true(all(tr$data$month[on] <= as.Date("2018-11-01")))
  expect_equal(sum(on), 5L * 6L)
  expect_true(all(is.na(tr$data$rel_time[!tr$data$area %in% areas])))
  expect_equal(tr$data$rel_time[tr$data$area == areas[1] & tr$data$month == as.Date("2018-06-01")], 0L)

  expect_error(lamp_treatment(sim, "binary", areas = areas), class = "streetlamp_error_input")
  expect_error(lamp_treatment(sim, "binary", window = c("2018-06", "2018-11")), class = "streetlamp_error_input")
  expect_error(
    lamp_treatment(sim, "binary", areas = "nowhere", window = c("2018-06", "2018-11")),
    class = "streetlamp_error_input"
  )
})

test_that("a staggered treatment carries cohorts and never-treated areas", {
  sim <- lamp_simulate(n_areas = 24, n_months = 24, design = "staggered", seed = 3)
  ad <- attr(sim, "truth")$adoption
  ad <- ad[!is.na(ad$adoption_month), ]
  tr <- lamp_treatment(sim, "staggered", adoption = ad)
  expect_equal(tr$type, "staggered")
  expect_equal(tr$n_treated_areas, nrow(ad))
  expect_gt(tr$details$n_cohorts, 1L)
  expect_gt(tr$details$never_treated, 0L)
  first <- ad$area[1]
  start <- ad$adoption_month[1]
  rows <- tr$data[tr$data$area == first, ]
  expect_true(all(rows$treat[rows$month >= start] == 1))
  expect_true(all(rows$treat[rows$month < start] == 0))
  expect_equal(rows$rel_time[rows$month == start], 0L)
  never <- setdiff(unique(sim$area), ad$area)
  expect_true(all(tr$data$treat[tr$data$area %in% never] == 0))

  expect_error(lamp_treatment(sim, "staggered", adoption = data.frame(x = 1)), class = "streetlamp_error_input")
  expect_error(
    lamp_treatment(sim, "staggered", adoption = data.frame(area = "nowhere", adoption_month = "2019-01")),
    class = "streetlamp_error_input"
  )
})

test_that("an event treatment can come from the bundled shocks table", {
  sim <- lamp_simulate(n_areas = 12, n_months = 24, seed = 4)
  tr <- lamp_treatment(sim, "event", date = "2018-12", window = c(-6, 6))
  expect_equal(tr$type, "event")
  expect_equal(tr$details$event_date, as.Date("2018-12-01"))
  expect_equal(tr$details$window, c(-6L, 6L))
  expect_equal(tr$data$rel_time[tr$data$month == as.Date("2018-12-01")][1], 0L)
  expect_equal(tr$data$rel_time[tr$data$month == as.Date("2018-11-01")][1], -1L)
  expect_true(all(tr$data$treat[tr$data$month < as.Date("2018-12-01")] == 0))

  scoped <- lamp_treatment(sim, "event", date = "2018-12", scope = unique(sim$area)[1:4])
  expect_equal(scoped$n_treated_areas, 4L)
  expect_equal(scoped$n_control_areas, 8L)

  # a named shock: this one starts before the simulated period, so every month
  # is post-event, which the treatment still represents faithfully
  # the shock's day of the month is floored to the month the panel uses
  sh <- lamp_treatment(sim, "event", event = "s60_relaxation_all_forces")
  expect_equal(sh$details$event_date, as.Date("2019-08-01"))
  expect_match(sh$details$event_name, "Section 60")

  expect_error(lamp_treatment(sim, "event"), class = "streetlamp_error_input")
  expect_error(lamp_treatment(sim, "event", event = "no-such-shock"), class = "streetlamp_error_input")
  expect_error(lamp_treatment(sim, "event", date = "2018-12", window = c(6, -6)), class = "streetlamp_error_input")
  expect_error(lamp_treatment(tibble::tibble(a = 1), "event", date = "2018-12"), class = "streetlamp_error_input")
})

test_that("surge detection flags months far above the trailing mean", {
  sim <- lamp_simulate(n_areas = 8, n_months = 30, design = "continuous", seed = 5)
  # plant an unmistakable surge in one area
  hit <- sim$area == sort(unique(sim$area))[1] & sim$month == sort(unique(sim$month))[20]
  sim$stops[hit] <- 500L

  su <- lamp_detect_surges(sim, min_stops = 5)
  expect_s3_class(su, "lamp_surges")
  expect_named(su, c(
    "area", "adoption_month", "n_flagged", "trailing_mean", "trailing_sd",
    "peak_stops", "peak_ratio"
  ))
  expect_equal(nrow(su), 8L)
  planted <- su[su$area == sort(unique(sim$area))[1], ]
  expect_equal(planted$adoption_month, sort(unique(sim$month))[20])
  expect_gte(planted$n_flagged, 1L)
  expect_gt(planted$peak_ratio, 10)
  flags <- attr(su, "flags")
  expect_true(any(flags$stops == 500L))
  expect_equal(attr(su, "k"), 2)

  # the output feeds a staggered treatment
  ad <- su[!is.na(su$adoption_month), c("area", "adoption_month")]
  tr <- lamp_treatment(sim, "staggered", adoption = ad)
  expect_equal(tr$n_treated_areas, nrow(ad))
  expect_message(print(su), "endogenous")
})

test_that("surge detection needs history and validates its input", {
  sim <- lamp_simulate(n_areas = 6, n_months = 8, design = "continuous", seed = 6)
  su <- lamp_detect_surges(sim)
  expect_true(all(is.na(su$adoption_month)))
  expect_error(lamp_detect_surges(sim, method = "cusum"), class = "rlang_error")
  no_stops <- sim
  no_stops$stops <- NULL
  expect_error(lamp_detect_surges(no_stops), class = "streetlamp_error_input")
})

test_that("breakpoint detection runs when strucchange is available", {
  skip_if_not_installed("strucchange")
  sim <- lamp_simulate(n_areas = 6, n_months = 40, design = "continuous", seed = 7)
  late <- sim$month >= sort(unique(sim$month))[25] & sim$area == sort(unique(sim$area))[1]
  sim$stops[late] <- sim$stops[late] + 40L
  su <- lamp_detect_surges(sim, method = "breakpoints", min_stops = 5)
  expect_equal(attr(su, "method"), "breakpoints")
  expect_false(is.na(su$adoption_month[su$area == sort(unique(sim$area))[1]]))
})

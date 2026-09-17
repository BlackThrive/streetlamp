test_that("a simulated panel is a valid lamp_panel with a known truth", {
  sim <- lamp_simulate(n_areas = 16, n_months = 18, design = "event", effect = -0.2, seed = 1)
  expect_s3_class(sim, "lamp_panel")
  expect_equal(nrow(sim), 16L * 18L)
  ct <- lamp_crime_types()
  type_keys <- setdiff(ct$key, "anti_social_behaviour")
  expect_true(all(c(
    "area", "month", "force_id", type_keys, "crime_total", "asb", "stops",
    "stops_s60", "population", "stop_rate", "coverage_status", "treat", "rel_time"
  ) %in% names(sim)))
  expect_equal(sim$crime_total, as.integer(rowSums(sim[, type_keys])))
  expect_equal(length(unique(sim$area)), 16L)
  expect_equal(length(unique(sim$month)), 18L)
  expect_equal(length(unique(sim$force_id)), 2L)

  truth <- attr(sim, "truth")
  expect_equal(truth$effect, -0.2)
  expect_equal(truth$design, "event")
  expect_equal(truth$placebo_type, "bicycle_theft")
  expect_false("bicycle_theft" %in% truth$affected_types)
  expect_length(truth$treated_areas, 8L)
  expect_s3_class(truth$event_date, "Date")

  con <- lamp_contract(sim)
  expect_s3_class(con$treatment, "lamp_treatment")
  expect_equal(con$source, "simulated")
  expect_s3_class(con$coverage, "lamp_coverage")
  expect_equal(nrow(con$coverage), 2L * 18L * 3L)
})

test_that("forces and treatment cross, so force-by-month effects leave variation", {
  sim <- lamp_simulate(n_areas = 36, n_months = 12, design = "event", seed = 2)
  treated <- attr(sim, "truth")$treated_areas
  tab <- table(
    force = unique(sim[, c("area", "force_id")])$force_id,
    treated = unique(sim[, c("area", "force_id")])$area %in% treated
  )
  expect_true(all(tab > 0))
})

test_that("the treatment effect is in the data at roughly the stated size", {
  sim <- lamp_simulate(
    n_areas = 100, n_months = 24, design = "event", effect = -0.3,
    base_rate = 40, seed = 3
  )
  truth <- attr(sim, "truth")
  treated <- sim$area %in% truth$treated_areas
  post <- sim$month >= truth$event_date
  cell <- function(tr, po) mean(sim$crime_total[treated == tr & post == po], na.rm = TRUE)
  did <- log(cell(TRUE, TRUE) / cell(TRUE, FALSE)) - log(cell(FALSE, TRUE) / cell(FALSE, FALSE))
  expect_lt(abs(did - -0.3), 0.1)
  # bicycle theft is never affected
  bike <- function(tr, po) mean(sim$bicycle_theft[treated == tr & post == po], na.rm = TRUE)
  did_bike <- log(bike(TRUE, TRUE) / bike(TRUE, FALSE)) - log(bike(FALSE, TRUE) / bike(FALSE, FALSE))
  expect_lt(abs(did_bike), 0.25)
})

test_that("every design produces its own treatment shape", {
  ev <- lamp_simulate(n_areas = 16, n_months = 16, design = "event", seed = 4)
  expect_equal(length(unique(stats::na.omit(ev$cohort))), 1L)

  st <- lamp_simulate(n_areas = 24, n_months = 24, design = "staggered", seed = 4)
  expect_gt(length(unique(stats::na.omit(st$cohort))), 1L)
  ad <- attr(st, "truth")$adoption
  expect_true(any(is.na(ad$adoption_month)))

  co <- lamp_simulate(n_areas = 16, n_months = 16, design = "continuous", seed = 4)
  expect_true(all(co$treat >= 0, na.rm = TRUE))
  expect_gt(length(unique(round(co$treat, 3))), 5L)
  expect_true(all(is.na(co$rel_time)))

  sp <- lamp_simulate(n_areas = 25, n_months = 16, design = "spillover", spillover_effect = 0.1, seed = 4)
  expect_equal(attr(sp, "truth")$spillover_effect, 0.1)
  expect_length(attr(sp, "truth")$nb, 25L)
})

test_that("missingness leaves NA counts and a missing coverage status", {
  sim <- lamp_simulate(n_areas = 16, n_months = 20, missing = 0.2, seed = 5)
  expect_gt(sum(sim$coverage_status == "missing"), 0L)
  gone <- sim$coverage_status == "missing"
  expect_true(all(is.na(sim$crime_total[gone])))
  expect_true(all(is.na(sim$stops[gone])))
  expect_false(anyNA(sim$crime_total[!gone]))
  cov <- lamp_coverage(sim)
  expect_true(any(cov$status == "missing"))
  # missingness is by force-month, as in the real archive
  by_fm <- unique(sim[, c("force_id", "month", "coverage_status")])
  expect_equal(nrow(by_fm), 2L * 20L)
})

test_that("simulation arguments are validated", {
  expect_error(lamp_simulate(n_areas = 2), class = "streetlamp_error_input")
  expect_error(lamp_simulate(n_months = 3), class = "streetlamp_error_input")
  expect_error(lamp_simulate(missing = 1.5), class = "streetlamp_error_input")
  expect_error(lamp_simulate(design = "nope"), class = "rlang_error")
})

test_that("the same seed gives the same panel", {
  a <- lamp_simulate(n_areas = 12, n_months = 12, seed = 99)
  b <- lamp_simulate(n_areas = 12, n_months = 12, seed = 99)
  expect_equal(a$crime_total, b$crime_total)
  expect_equal(a$stops, b$stops)
})

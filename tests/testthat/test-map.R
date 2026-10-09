map_fixture <- function(authority = "Ceredigion") {
  panel <- lamp_sample_panel()
  boundaries <- lamp_sample_boundaries()
  areas <- boundaries$area[sub(" [0-9].*$", "", boundaries$name) == authority]
  list(
    panel = panel[panel$area %in% areas, ],
    boundaries = boundaries,
    areas = areas
  )
}

test_that("a panel column is mapped over the areas the panel covers", {
  f <- map_fixture()
  p <- lamp_map(f$panel, "stop_rate", f$boundaries)
  expect_s3_class(p, "ggplot")
  # the default extent is the panel, not every boundary supplied
  expect_equal(nrow(p$data), length(f$areas))
  expect_lt(nrow(p$data), nrow(f$boundaries))
  expect_true(all(p$data$area %in% f$areas))
})

test_that("every statistic and a single month work", {
  f <- map_fixture()
  for (s in c("mean", "total", "rate")) {
    expect_s3_class(lamp_map(f$panel, "crime_total", f$boundaries, statistic = s), "ggplot")
  }
  months <- sort(unique(f$panel$month))
  p <- lamp_map(f$panel, "crime_total", f$boundaries, month = months[2])
  expect_s3_class(p, "ggplot")
  expect_match(p$labels$subtitle, lamp_month_id(months[2]), fixed = TRUE)

  # the rate needs a denominator
  no_pop <- f$panel
  no_pop$population <- NULL
  expect_error(
    lamp_map(no_pop, "crime_total", f$boundaries, statistic = "rate"),
    class = "streetlamp_error_input"
  )
})

test_that("an area with no file is drawn as missing and counted, never as zero", {
  f <- map_fixture()
  d <- f$panel
  gone <- utils::head(f$areas, 10)
  d$coverage_status[d$area %in% gone] <- "missing"
  p <- lamp_map(d, "crime_total", f$boundaries)

  # the value is absent, not zero
  vals <- p$data$.value[p$data$area %in% gone]
  expect_true(all(is.na(vals)))
  expect_false(any(vals == 0, na.rm = TRUE))
  expect_match(p$labels$caption, "10 of")
  expect_match(p$labels$caption, "not as zero")

  # and the fill for those areas is the neutral grey, not the red the coverage
  # grid uses for a missing status: on a sequential ramp red reads as a high
  # value, which is the opposite of what is meant
  na_fill <- p$scales$get_scales("fill")$na.value
  expect_equal(na_fill, unname(lamp_colours()[["neutral"]]))
  expect_false(identical(na_fill, unname(lamp_colours()[["missing"]])))
})

test_that("areas outside the panel are counted apart from missing data", {
  f <- map_fixture()
  p <- lamp_map(f$panel, "crime_total", f$boundaries, extent = "all")
  expect_equal(nrow(p$data), nrow(f$boundaries))
  expect_match(p$labels$caption, "lie outside the panel")
  # with no missing force-months there is nothing to report as missing
  expect_no_match(p$labels$caption, "not as zero")

  # clipped to the panel, there is nothing to say at all
  q <- lamp_map(f$panel, "crime_total", f$boundaries)
  expect_null(q$labels$caption)
})

test_that("per-area elasticities and synthetic control donors can be mapped", {
  f <- map_fixture("Powys")
  mg <- lamp_elasticity(f$panel, "crime_total", lags = 0, method = "cce_mg")
  p <- lamp_map(mg, f$boundaries)
  expect_s3_class(p, "ggplot")
  # an elasticity crosses zero, so the scale is diverging and centred there
  limits <- p$scales$get_scales("fill")$limits
  expect_length(limits, 2L)
  expect_equal(limits[1], -limits[2])
  expect_match(p$labels$subtitle, "lamp_allocation", fixed = TRUE)

  # the pooled estimator has no per-area coefficients to map
  fe <- lamp_elasticity(f$panel, "crime_total", lags = 0, method = "fe")
  err <- tryCatch(lamp_map(fe, f$boundaries), error = identity)
  expect_s3_class(err, "streetlamp_error_input")
  expect_match(conditionMessage(err), "cce_mg")
})

test_that("an estimate with one effect for the whole sample is refused", {
  f <- map_fixture()
  tr <- lamp_treatment(f$panel, "continuous", measure = "stop_rate", transform = "ihs")
  fit <- lamp_twfe(f$panel, "crime_total", tr)
  err <- tryCatch(lamp_map(fit, f$boundaries), error = identity)
  expect_s3_class(err, "streetlamp_error_input")
  expect_match(conditionMessage(err), "nothing to map by area")
  expect_match(conditionMessage(err), "lamp_synth")
})

test_that("bad input is refused with an explanation", {
  f <- map_fixture()
  expect_error(lamp_map(f$panel, "crime_total"), class = "streetlamp_error_input")
  expect_error(
    lamp_map(f$panel, "crime_total", tibble::tibble(area = "x")),
    class = "streetlamp_error_input"
  )
  expect_error(lamp_map(f$panel, "nope", f$boundaries), class = "streetlamp_error_input")
  expect_error(
    lamp_map(f$panel, "crime_total", f$boundaries[, "name"]),
    class = "streetlamp_error_input"
  )
  expect_error(
    lamp_map(f$panel, "crime_total", f$boundaries, month = c("2026-01", "2026-02")),
    class = "streetlamp_error_input"
  )
  expect_error(
    lamp_map(f$panel, "crime_total", f$boundaries, month = "1999-01"),
    class = "streetlamp_error_input"
  )
})

test_that("the map looks the way it did", {
  skip_on_cran()
  skip_if_not_installed("vdiffr")
  f <- map_fixture()
  vdiffr::expect_doppelganger(
    "choropleth",
    lamp_map(f$panel, "stop_rate", f$boundaries)
  )
})

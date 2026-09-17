test_that("own and neighbour effects are recovered together, and their net is right", {
  skip_on_cran()
  sim <- lamp_simulate(
    n_areas = 100, n_months = 30, design = "spillover", effect = -0.3,
    spillover_effect = 0.15, base_rate = 40, seed = 1
  )
  truth <- attr(sim, "truth")
  adj <- lamp_adjacency_from_nb(truth$nb, truth$lattice$area)
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  fit <- lamp_spillover(sim, "crime_total", tr, adjacency = adj, rings = 1)

  expect_s3_class(fit, "lamp_spillover")
  expect_equal(nrow(fit$coefficients), 2L)
  expect_equal(fit$coefficients$term, c("own area", "neighbours, ring 1"))

  own <- fit$coefficients$estimate[1]
  nbr <- fit$coefficients$estimate[2]
  expect_lt(own, 0)
  expect_gt(nbr, 0)

  # own and neighbour exposure are collinear when treated areas are
  # contiguous, so each coefficient is imprecise; their sum is what the
  # design identifies well, and it is the net effect on a treated area whose
  # neighbours are all treated
  net_truth <- truth$effect_crime_total +
    log((12 * exp(truth$spillover_effect) + 1) / 13)
  expect_lt(abs(fit$diagnostics$net$estimate - net_truth), 0.06)
  expect_lte(fit$diagnostics$net$conf_low, net_truth)
  expect_gte(fit$diagnostics$net$conf_high, net_truth)
  expect_message(print(fit), "Net effect")
})

test_that("omitting the spillover term biases two-way fixed effects toward zero", {
  skip_on_cran()
  sim <- lamp_simulate(
    n_areas = 100, n_months = 30, design = "spillover", effect = -0.3,
    spillover_effect = 0.2, base_rate = 40, seed = 2
  )
  truth <- attr(sim, "truth")
  adj <- lamp_adjacency_from_nb(truth$nb, truth$lattice$area)
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)

  with_spill <- lamp_spillover(sim, "crime_total", tr, adjacency = adj, rings = 1)
  without <- lamp_twfe(sim, "crime_total", tr)

  # a positive spillover onto the control areas raises the comparison group,
  # so the plain estimate understates the own-area reduction
  expect_gt(without$coefficients$estimate[1], with_spill$coefficients$estimate[1])
  expect_lt(abs(without$coefficients$estimate[1]), abs(with_spill$coefficients$estimate[1]))
})

test_that("rings beyond the first are built and can be requested", {
  sim <- lamp_simulate(
    n_areas = 64, n_months = 20, design = "spillover", effect = -0.3,
    spillover_effect = 0.1, base_rate = 30, seed = 3
  )
  truth <- attr(sim, "truth")
  adj <- lamp_adjacency_from_nb(truth$nb, truth$lattice$area)
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  fit <- lamp_spillover(sim, "crime_total", tr, adjacency = adj, rings = 1:2)
  expect_equal(nrow(fit$coefficients), 3L)
  expect_equal(fit$diagnostics$rings, 1:2)
  expect_true(any(grepl("ring 2", fit$coefficients$term)))

  # the second ring is a different set of areas from the first
  rings <- streetlamp:::lamp_ring_neighbours(truth$nb, 1:2)
  centre <- which(vapply(rings[[1]], length, integer(1)) == 4L)[1]
  expect_gt(length(rings[[2]][[centre]]), 0L)
  expect_equal(length(intersect(rings[[1]][[centre]], rings[[2]][[centre]])), 0L)
  expect_false(centre %in% rings[[2]][[centre]])
})

test_that("spillovers need adjacency and validate their input", {
  sim <- lamp_simulate(n_areas = 25, n_months = 16, design = "spillover", seed = 4)
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  expect_error(lamp_spillover(sim, "crime_total", tr), class = "streetlamp_error_contract")

  adj <- lamp_adjacency_from_nb(truth$nb, truth$lattice$area)
  expect_error(lamp_spillover(sim, "crime_total", tr, adjacency = adj, rings = 0), class = "streetlamp_error_input")
  expect_error(lamp_spillover(sim, "crime_total", tr, adjacency = adj, rings = 1.5), class = "streetlamp_error_input")
  expect_error(lamp_adjacency_from_nb(truth$nb, "one-area"), class = "streetlamp_error_input")

  # areas missing from the adjacency are reported
  short <- lamp_adjacency_from_nb(truth$nb, truth$lattice$area)
  short$areas <- c(utils::head(short$areas, -1), "not-a-real-area")
  expect_warning(
    lamp_spillover(sim, "crime_total", tr, adjacency = short, rings = 1),
    class = "streetlamp_warning_coverage"
  )
})

test_that("the weighted displacement quotient reproduces a hand-computed value", {
  # A: treated, B: buffer, C: control, two months before and two after.
  # Totals: A0 = 100, A1 = 50, B0 = 100, B1 = 150, C0 = 100, C1 = 100.
  # success = (50/100) - (100/100) = -0.5
  # buffer  = (150/100) - (100/100) = 0.5
  # WDQ = 0.5 / -0.5 = -1, complete displacement.
  months <- as.Date(c("2020-01-01", "2020-02-01", "2020-06-01", "2020-07-01"))
  build <- function(areas, values) {
    tidyr::expand_grid(area = areas, month = months) |>
      dplyr::mutate(crime_total = rep(values, times = length(areas)))
  }
  d <- dplyr::bind_rows(
    build(c("A1", "A2"), c(25, 25, 12.5, 12.5)),
    build(c("B1", "B2"), c(25, 25, 37.5, 37.5)),
    build(c("C1", "C2"), c(25, 25, 25, 25))
  )
  d$force_id <- "f"
  d$coverage_status <- "submitted"
  contract <- streetlamp:::new_lamp_contract(geography = list(area = "test"))
  panel <- streetlamp:::new_lamp_panel(d, contract)

  res <- lamp_displacement_quotient(
    panel, "crime_total",
    treated_areas = c("A1", "A2"), buffer_areas = c("B1", "B2"),
    control_areas = c("C1", "C2"),
    pre = c("2020-01", "2020-02"), post = c("2020-06", "2020-07"),
    n_boot = 20, seed = 1
  )
  expect_equal(res$wdq, -1)
  expect_equal(res$success, -0.5)
  expect_equal(res$totals$a0, 100)
  expect_equal(res$totals$a1, 50)
  expect_equal(res$totals$b1, 150)
  expect_match(res$interpretation, "displacement looks like")
  expect_message(print(res), "displacement quotient")
})

test_that("a diffusion of benefit gives a quotient between zero and one", {
  months <- as.Date(c("2020-01-01", "2020-06-01"))
  mk <- function(areas, pre, post) {
    tidyr::expand_grid(area = areas, month = months) |>
      dplyr::mutate(crime_total = rep(c(pre, post), times = length(areas)))
  }
  # treated halve, buffer falls by a quarter, controls flat
  d <- dplyr::bind_rows(mk("A", 100, 50), mk("B", 100, 75), mk("C", 100, 100))
  d$force_id <- "f"
  d$coverage_status <- "submitted"
  panel <- streetlamp:::new_lamp_panel(d, streetlamp:::new_lamp_contract(geography = list(area = "test")))
  res <- lamp_displacement_quotient(
    panel, "crime_total",
    treated_areas = "A", buffer_areas = "B", control_areas = "C",
    pre = c("2020-01", "2020-01"), post = c("2020-06", "2020-06"), n_boot = 10
  )
  expect_equal(res$wdq, 0.5)
  expect_match(res$interpretation, "diffusion of benefit")
})

test_that("the displacement quotient validates its areas and periods", {
  sim <- lamp_simulate(n_areas = 20, n_months = 16, design = "event", seed = 5)
  areas <- unique(sim$area)
  expect_error(
    lamp_displacement_quotient(
      sim, "crime_total", areas[1:3], areas[3:5], areas[6:8],
      pre = c("2018-01", "2018-04"), post = c("2018-09", "2018-12")
    ),
    class = "streetlamp_error_input"
  )
  expect_error(
    lamp_displacement_quotient(
      sim, "crime_total", areas[1:3], areas[4:6], areas[7:9],
      pre = "2018-01", post = c("2018-09", "2018-12")
    ),
    class = "streetlamp_error_input"
  )
  expect_error(
    lamp_displacement_quotient(
      sim, "no_such_column", areas[1:3], areas[4:6], areas[7:9],
      pre = c("2018-01", "2018-04"), post = c("2018-09", "2018-12")
    ),
    class = "streetlamp_error_input"
  )
})

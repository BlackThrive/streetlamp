# Simulated panels with known effects ------------------------------------------------
#
# lamp_simulate() generates a panel whose data-generating process is known, so
# that the estimators can be checked for recovery of a true effect, for the
# bias of a mis-specified estimator, and for behaviour under force-month
# missingness. The panel is an ordinary lamp_panel and can be passed to every
# estimator; its truth is in attr(x, "truth").

lamp_sim_designs <- function() c("staggered", "event", "continuous", "spillover")

# Areas on a square lattice, so that neighbours are well defined.
lamp_sim_lattice <- function(n_areas) {
  n_row <- max(2L, floor(sqrt(n_areas)))
  n_col <- ceiling(n_areas / n_row)
  grid <- expand.grid(row = seq_len(n_row), col = seq_len(n_col))[seq_len(n_areas), ]
  tibble::tibble(
    area = sprintf("S%05d", seq_len(n_areas)),
    row = grid$row, col = grid$col
  )
}

# First-order rook neighbours on that lattice, row-standardised.
lamp_sim_neighbours <- function(lattice) {
  n <- nrow(lattice)
  nb <- vector("list", n)
  for (i in seq_len(n)) {
    d <- abs(lattice$row - lattice$row[i]) + abs(lattice$col - lattice$col[i])
    hit <- which(d == 1L)
    nb[[i]] <- if (length(hit) == 0L) 0L else hit
  }
  class(nb) <- "nb"
  attr(nb, "region.id") <- lattice$area
  nb
}

lamp_sim_neighbour_mean <- function(nb, x) {
  vapply(seq_along(nb), function(i) {
    j <- nb[[i]]
    if (length(j) == 1L && j[1] == 0L) 0 else mean(x[j])
  }, numeric(1))
}

#' Simulate a panel with a known treatment effect
#'
#' Generates an area-by-month panel from a known data-generating process, for
#' testing estimators and for the simulation evidence in the vignettes. Crime
#' counts are Poisson draws around area and month fixed effects, and the
#' treatment multiplies the mean of the affected crime types by `exp(effect)`,
#' so `effect` is a log point effect: -0.1 is a 9.5 percent reduction.
#'
#' @details
#' Designs:
#' * `event`: one date; the areas in the treated half are treated from that
#'   month onward. Suits [lamp_event_study()].
#' * `staggered`: areas adopt in cohorts spread across the middle of the
#'   period, with never-treated areas kept as controls. Plain two-way fixed
#'   effects are biased here, which is what `lamp_did_staggered()` is for.
#' * `continuous`: every area has a stop intensity that varies over time, and
#'   the outcome responds to `log(stops + 1)` with elasticity `effect`.
#' * `spillover`: as `event`, and in addition the mean treatment of an area's
#'   first-order lattice neighbours shifts its outcome by `spillover_effect`,
#'   so an estimator that omits the neighbour term is biased.
#'
#' Areas sit on a square lattice and belong to two forces, so that
#' force-month missingness, clustering and adjacency are all exercisable. A
#' share `missing` of force-months has no street file: those rows carry `NA`
#' counts and `coverage_status = "missing"`, exactly as a real panel does.
#' Bicycle theft is never affected by treatment, which makes it the default
#' placebo outcome in [lamp_placebo()].
#'
#' @param n_areas Number of areas.
#' @param n_months Number of months.
#' @param design One of `"staggered"`, `"event"`, `"continuous"` or
#'   `"spillover"`.
#' @param effect True treatment effect in log points on the affected crime
#'   types (for `continuous`, the elasticity of crime with respect to
#'   `log(stops + 1)`).
#' @param spillover_effect True neighbour effect in log points, used by the
#'   `spillover` design.
#' @param adoption Adoption months for the `staggered` design, as month
#'   indices within the panel; `NULL` picks three evenly spaced cohorts.
#' @param missing Share of force-months with no street file (0 to 1).
#' @param base_rate Expected monthly count per area before fixed effects.
#' @param population Population per area, used for `stop_rate`.
#' @param seed Random seed.
#'
#' @return A `lamp_panel` with the usual columns plus `treat` (the treatment
#'   variable) and, for the event and staggered designs, `rel_time` and
#'   `cohort`. Its contract carries the treatment definition, and
#'   `attr(x, "truth")` holds the true `effect`, the implied effect on the
#'   crime total (`effect_crime_total`, smaller in size than `effect`
#'   because bicycle theft is unaffected), `spillover_effect`, `design`, the
#'   affected crime types, the treated areas, the event date, the adoption
#'   table and the neighbour list.
#' @family simulation
#' @export
#' @examples
#' sim <- lamp_simulate(n_areas = 36, n_months = 24, design = "event", effect = -0.2)
#' sim
#' attr(sim, "truth")$effect
#' table(sim$coverage_status)
lamp_simulate <- function(n_areas = 36L, n_months = 24L,
                          design = c("staggered", "event", "continuous", "spillover"),
                          effect = -0.15, spillover_effect = 0.05, adoption = NULL,
                          missing = 0, base_rate = 8, population = 1500, seed = NULL) {
  design <- rlang::arg_match(design)
  if (!is.numeric(n_areas) || n_areas < 4) {
    lamp_abort("{.arg n_areas} must be at least 4.", "input")
  }
  if (!is.numeric(n_months) || n_months < 6) {
    lamp_abort("{.arg n_months} must be at least 6.", "input")
  }
  if (!is.numeric(missing) || missing < 0 || missing >= 1) {
    lamp_abort("{.arg missing} must be at least 0 and below 1.", "input")
  }
  if (!is.null(seed)) {
    withr::local_seed(seed)
  }
  n_areas <- as.integer(n_areas)
  n_months <- as.integer(n_months)

  lattice <- lamp_sim_lattice(n_areas)
  nb <- lamp_sim_neighbours(lattice)
  months <- seq(as.Date("2018-01-01"), by = "month", length.out = n_months)
  # forces split the lattice by row and treatment by column, so that the two
  # cross: every force holds treated and control areas, and force-by-month
  # fixed effects do not absorb the treatment.
  force_id <- ifelse(lattice$row <= stats::median(lattice$row), "sim-north", "sim-south")

  # fixed effects: area heterogeneity, a trend and a seasonal cycle
  alpha <- stats::rnorm(n_areas, 0, 0.35)
  t_index <- seq_len(n_months)
  gamma <- 0.004 * t_index + 0.12 * sin(2 * pi * t_index / 12)

  grid <- tidyr::expand_grid(area_i = seq_len(n_areas), t = t_index)
  grid$area <- lattice$area[grid$area_i]
  grid$month <- months[grid$t]
  grid$force_id <- force_id[grid$area_i]

  # treatment
  treated_area <- rep(FALSE, n_areas)
  adoption_t <- rep(NA_integer_, n_areas)
  if (design %in% c("event", "spillover")) {
    treated_area[lattice$col <= stats::median(lattice$col)] <- TRUE
    event_t <- ceiling(n_months / 2)
    adoption_t[treated_area] <- event_t
  } else if (design == "staggered") {
    if (is.null(adoption)) {
      adoption <- round(stats::quantile(t_index, c(0.35, 0.5, 0.65), names = FALSE))
    }
    adoption <- sort(unique(as.integer(adoption)))
    cohort <- rep(c(seq_along(adoption), NA_integer_), length.out = n_areas)
    treated_area <- !is.na(cohort)
    adoption_t[treated_area] <- adoption[cohort[treated_area]]
  }
  if (design == "continuous") {
    # an exponential mean keeps the Poisson rate positive whatever the area
    # effect and season do
    stop_rate <- exp(log(6) + 0.3 * sin(2 * pi * grid$t / 12) + alpha[grid$area_i])
    stops <- stats::rpois(nrow(grid), lambda = stop_rate)
    grid$treat <- log1p(stops)
    grid$rel_time <- NA_integer_
    grid$cohort <- NA_integer_
  } else {
    grid$treat <- as.numeric(!is.na(adoption_t[grid$area_i]) & grid$t >= adoption_t[grid$area_i])
    start_t <- adoption_t[grid$area_i]
    grid$rel_time <- ifelse(is.na(start_t), NA_integer_, grid$t - start_t)
    grid$cohort <- adoption_t[grid$area_i]
    stops <- stats::rpois(nrow(grid), lambda = 4 + 8 * grid$treat)
  }

  # neighbour exposure
  by_t <- split(seq_len(nrow(grid)), grid$t)
  neighbour_treat <- numeric(nrow(grid))
  for (idx in by_t) {
    ord <- order(grid$area_i[idx])
    neighbour_treat[idx[ord]] <- lamp_sim_neighbour_mean(nb, grid$treat[idx[ord]])
  }
  grid$neighbour_treat <- neighbour_treat

  ct <- lamp_crime_types()
  type_keys <- setdiff(ct$key, "anti_social_behaviour")
  affected <- setdiff(type_keys, "bicycle_theft")
  share <- 1 / length(type_keys)

  # Each crime type is a Poisson draw around an equal share of the area-month
  # mean; the treatment multiplies that mean by exp(effect) for the affected
  # types, so `effect` is exactly the log point effect an estimator recovers.
  eta_base <- log(base_rate * share) + alpha[grid$area_i] + gamma[grid$t]
  spill <- if (design == "spillover") spillover_effect * grid$neighbour_treat else 0
  out <- tibble::tibble(area = grid$area, month = grid$month, force_id = grid$force_id)
  for (k in type_keys) {
    eta <- eta_base
    if (k %in% affected) {
      eta <- eta + effect * grid$treat + spill
    }
    out[[k]] <- stats::rpois(nrow(grid), lambda = exp(eta))
  }
  out$crime_total <- as.integer(rowSums(out[, type_keys]))
  out$asb <- stats::rpois(nrow(grid), lambda = exp(eta_base) * 0.3)
  out$stops <- as.integer(stops)
  out$stops_s60 <- stats::rbinom(nrow(grid), out$stops, 0.02)
  out$population <- population
  out$stop_rate <- 1000 * out$stops / out$population
  out$treat <- grid$treat
  out$rel_time <- grid$rel_time
  out$cohort <- grid$cohort

  # force-month missingness: a force did not submit, so counts are NA
  fm <- unique(out[, c("force_id", "month")])
  fm$status <- "submitted"
  if (missing > 0) {
    n_miss <- max(1L, round(missing * nrow(fm)))
    fm$status[sample.int(nrow(fm), n_miss)] <- "missing"
  }
  key <- paste(out$force_id, lamp_month_id(out$month))
  status <- fm$status[match(key, paste(fm$force_id, lamp_month_id(fm$month)))]
  gone <- status == "missing"
  for (k in c(type_keys, "crime_total", "asb", "stops", "stops_s60", "stop_rate")) {
    out[[k]][gone] <- NA
  }
  out$coverage_status <- status
  out$stops_status <- status

  coverage <- dplyr::bind_rows(lapply(c("street", "outcomes", "stop-and-search"), function(ft) {
    tibble::tibble(
      force_id = fm$force_id, month = fm$month, file_type = ft, status = fm$status,
      n_records = NA_integer_, archive = "simulated", n_versions = 1L,
      versions_differ = FALSE
    )
  }))
  coverage <- lamp_coverage_table(
    street = coverage[coverage$file_type == "street", ],
    outcomes = coverage[coverage$file_type == "outcomes", ],
    stops = coverage[coverage$file_type == "stop-and-search", ]
  )

  treatment_type <- switch(design,
    continuous = "continuous",
    staggered = "staggered",
    "event"
  )
  treatment <- new_lamp_treatment(
    type = treatment_type,
    column = "treat",
    data = out[, c("area", "month", "treat", "rel_time", "cohort")],
    details = list(design = design, simulated = TRUE),
    n_treated_areas = sum(treated_area),
    n_control_areas = sum(!treated_area)
  )
  contract <- new_lamp_contract(
    source = "simulated",
    coverage = coverage,
    geography = list(
      area = "simulated", lsoa_vintage = NULL, n_areas = n_areas,
      forces = unique(force_id)
    ),
    population = "simulated",
    crime_scope = list(crime_total = type_keys, include_asb = FALSE, attribution = "falls_within"),
    stops = list(origin = "simulated", definition = "raw count", area = "simulated"),
    treatment = treatment
  )
  panel <- new_lamp_panel(out[order(out$area, out$month), ], contract)
  # The effect on `crime_total` is not `effect`, because bicycle theft is
  # never affected: the total moves by the log of the share-weighted mean of
  # the per-type multipliers. Tests and vignettes compare estimates on
  # `crime_total` with this number.
  n_types <- length(type_keys)
  n_affected <- length(affected)
  effect_crime_total <- log((n_affected * exp(effect) + n_types - n_affected) / n_types)
  event_date <- if (design %in% c("event", "spillover")) {
    months[adoption_t[which(treated_area)[1]]]
  } else {
    as.Date(NA)
  }
  attr(panel, "truth") <- list(
    design = design, effect = effect, effect_crime_total = effect_crime_total,
    spillover_effect = if (design == "spillover") spillover_effect else 0,
    affected_types = affected, placebo_type = "bicycle_theft",
    treated_areas = lattice$area[treated_area],
    event_date = event_date,
    adoption = tibble::tibble(area = lattice$area, adoption_month = months[adoption_t]),
    lattice = lattice, nb = nb, n_missing_force_months = sum(fm$status == "missing")
  )
  panel
}

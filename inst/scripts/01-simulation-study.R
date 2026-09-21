# Validation 1: simulation study
#
# Across the four designs, with and without force-month missingness, measure
# each estimator's bias, root mean squared error and interval coverage against
# a known truth. Writes inst/validation/simulation-study.csv and a summary
# table of which estimator to use when.
#
# Run on a schedule, not at check time:
#   Rscript inst/scripts/01-simulation-study.R [n_reps] [n_workers]
#
# One replication of all eight grid cells takes roughly seven minutes at 400
# areas and 60 months, so 200 replications is about a day on one core and
# about four hours across ten. Replications are independent, so they are run
# on a cluster of workers, and each grid cell is written out as it finishes:
# a run that is stopped early still leaves usable results.

suppressMessages(library(streetlamp))

args <- commandArgs(trailingOnly = TRUE)
n_reps <- if (length(args) > 0) as.integer(args[1]) else 200L
n_workers <- if (length(args) > 1) {
  as.integer(args[2])
} else {
  max(1L, parallel::detectCores() - 2L)
}
n_areas <- 400L
n_months <- 60L
out_dir <- file.path("inst", "validation")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

message(sprintf(
  "Simulation study: %d replications, %d areas, %d months, %d worker%s",
  n_reps, n_areas, n_months, n_workers, if (n_workers == 1L) "" else "s"
))

# The continuous design has no single true elasticity to compare against. The
# outcome responds to log(1 + stops) with elasticity `effect`, but only on
# twelve of the thirteen crime types, so the elasticity of the total depends
# on the level of stops and is not constant. The quantity the fixed effects
# estimator is consistent for is the slope of the noise-free log mean on
# log(1 + stops) after area and month effects, which this computes from the
# data-generating process and the stops actually drawn. What is left between
# this and an estimate is the estimator's own doing: it regresses log(1 + a
# noisy count), not the log mean.
continuous_target <- function(sim, truth) {
  d <- sim[sim$coverage_status != "missing" & !is.na(sim$stops), ]
  n_types <- length(truth$affected_types) + 1L
  n_affected <- length(truth$affected_types)
  d$.log_s <- log1p(d$stops)
  d$.log_mean <- log(n_affected * exp(truth$effect * d$.log_s) + (n_types - n_affected))
  d$.area <- factor(d$area)
  d$.month <- factor(format(d$month, "%Y-%m"))
  fit <- fixest::feols(.log_mean ~ .log_s | .area + .month, data = d, notes = FALSE)
  unname(stats::coef(fit)[[".log_s"]])
}

one_rep <- function(rep, design, missing) {
  sim <- lamp_simulate(
    n_areas = n_areas, n_months = n_months, design = design,
    effect = -0.25, spillover_effect = 0.12, base_rate = 30,
    missing = missing, seed = 10000L + rep
  )
  truth <- attr(sim, "truth")
  target <- truth$effect_crime_total
  rows <- list()

  record <- function(estimator, estimate, lo, hi, target_value = target) {
    tibble::tibble(
      rep = rep, design = design, missing = missing, estimator = estimator,
      target = target_value, estimate = estimate, conf_low = lo, conf_high = hi,
      error = estimate - target_value,
      covered = !is.na(lo) && !is.na(hi) && lo <= target_value && target_value <= hi
    )
  }

  if (design %in% c("event", "spillover")) {
    tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
    fit <- try(lamp_twfe(sim, "crime_total", tr), silent = TRUE)
    if (!inherits(fit, "try-error")) {
      co <- fit$coefficients
      rows[[length(rows) + 1L]] <- record("lamp_twfe", co$estimate[1], co$conf_low[1], co$conf_high[1])
    }
    es <- try(lamp_event_study(sim, "crime_total", tr, window = c(-12, 12)), silent = TRUE)
    if (!inherits(es, "try-error")) {
      post <- es$coefficients[es$coefficients$rel_time >= 0, ]
      rows[[length(rows) + 1L]] <- record(
        "lamp_event_study", mean(post$estimate),
        mean(post$conf_low), mean(post$conf_high)
      )
    }
    if (design == "spillover") {
      adj <- lamp_adjacency_from_nb(truth$nb, truth$lattice$area)
      sp <- try(lamp_spillover(sim, "crime_total", tr, adjacency = adj, rings = 1), silent = TRUE)
      if (!inherits(sp, "try-error")) {
        net_target <- target + log((12 * exp(truth$spillover_effect) + 1) / 13)
        net <- sp$diagnostics$net
        rows[[length(rows) + 1L]] <- record(
          "lamp_spillover (net)", net$estimate, net$conf_low, net$conf_high, net_target
        )
        co <- sp$coefficients
        rows[[length(rows) + 1L]] <- record(
          "lamp_spillover (own)", co$estimate[1], co$conf_low[1], co$conf_high[1]
        )
      }
    }
  }

  if (design == "staggered") {
    ad <- truth$adoption
    ad <- ad[!is.na(ad$adoption_month), ]
    tr <- lamp_treatment(sim, "staggered", adoption = ad)
    for (backend in c("callaway_santanna", "sun_abraham")) {
      fit <- try(
        suppressWarnings(lamp_did_staggered(sim, "crime_total", tr, estimator = backend)),
        silent = TRUE
      )
      if (!inherits(fit, "try-error") && !is.null(fit$diagnostics$overall)) {
        ov <- fit$diagnostics$overall
        z <- stats::qnorm(0.975)
        rows[[length(rows) + 1L]] <- record(
          paste0("lamp_did_staggered (", backend, ")"),
          ov$estimate, ov$estimate - z * ov$std_error, ov$estimate + z * ov$std_error
        )
      }
    }
    twfe <- try(suppressWarnings(lamp_twfe(sim, "crime_total", tr, family = "ols_log")), silent = TRUE)
    if (!inherits(twfe, "try-error")) {
      co <- twfe$coefficients
      rows[[length(rows) + 1L]] <- record(
        "lamp_twfe (wrong here)", co$estimate[1], co$conf_low[1], co$conf_high[1]
      )
    }
  }

  if (design == "continuous") {
    elasticity_target <- continuous_target(sim, truth)
    for (m in c("fe", "cce_pooled", "cce_mg")) {
      fit <- try(lamp_elasticity(sim, "crime_total", lags = 0, method = m), silent = TRUE)
      if (!inherits(fit, "try-error")) {
        lr <- fit$diagnostics$long_run
        rows[[length(rows) + 1L]] <- record(
          paste0("lamp_elasticity (", m, ")"), lr$estimate, lr$conf_low, lr$conf_high,
          target_value = elasticity_target
        )
      }
    }
  }
  dplyr::bind_rows(rows)
}

grid <- expand.grid(
  design = c("event", "staggered", "continuous", "spillover"),
  missing = c(0, 0.1),
  stringsAsFactors = FALSE
)
cl <- NULL
if (n_workers > 1L) {
  cl <- parallel::makeCluster(n_workers)
  on.exit(parallel::stopCluster(cl), add = TRUE)
  parallel::clusterEvalQ(cl, suppressMessages(library(streetlamp)))
  parallel::clusterExport(cl, c("n_areas", "n_months", "continuous_target", "one_rep"))
}

all_rows <- list()
for (g in seq_len(nrow(grid))) {
  design <- grid$design[g]
  missing <- grid$missing[g]
  t0 <- Sys.time()
  reps <- seq_len(n_reps)
  # `design` and `missing` are passed as arguments, not captured: a worker
  # cannot see this script's global environment
  cell <- if (is.null(cl)) {
    lapply(reps, one_rep, design = design, missing = missing)
  } else {
    parallel::parLapply(cl, reps, one_rep, design = design, missing = missing)
  }
  all_rows <- c(all_rows, cell)
  message(sprintf(
    "  %-11s missingness %3.0f%%  %d reps in %.1f min",
    design, 100 * missing, n_reps,
    as.numeric(difftime(Sys.time(), t0, units = "mins"))
  ))
  # written after every cell, so that a run stopped early is still usable
  utils::write.csv(
    dplyr::bind_rows(all_rows), file.path(out_dir, "simulation-study.csv"),
    row.names = FALSE
  )
}
results <- dplyr::bind_rows(all_rows)

summary_table <- results |>
  dplyr::filter(!is.na(.data$target)) |>
  dplyr::group_by(.data$design, .data$missing, .data$estimator) |>
  dplyr::summarise(
    n = dplyr::n(),
    bias = mean(.data$error, na.rm = TRUE),
    rmse = sqrt(mean(.data$error^2, na.rm = TRUE)),
    coverage = mean(.data$covered, na.rm = TRUE),
    .groups = "drop"
  )
utils::write.csv(summary_table, file.path(out_dir, "simulation-summary.csv"), row.names = FALSE)
print(as.data.frame(summary_table), digits = 3)
message("written ", file.path(out_dir, "simulation-summary.csv"))

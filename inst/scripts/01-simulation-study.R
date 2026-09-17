# Validation 1: simulation study
#
# Across the four designs, with and without force-month missingness, measure
# each estimator's bias, root mean squared error and interval coverage against
# a known truth. Writes inst/validation/simulation-study.csv and a summary
# table of which estimator to use when.
#
# Run on a schedule, not at check time:
#   Rscript inst/scripts/01-simulation-study.R [n_reps]
#
# Roughly 10 minutes for 200 replications on one core.

suppressMessages(library(streetlamp))

args <- commandArgs(trailingOnly = TRUE)
n_reps <- if (length(args) > 0) as.integer(args[1]) else 200L
n_areas <- 400L
n_months <- 60L
out_dir <- file.path("inst", "validation")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

message(sprintf("Simulation study: %d replications, %d areas, %d months", n_reps, n_areas, n_months))

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
    for (m in c("fe", "cce_pooled", "cce_mg")) {
      fit <- try(lamp_elasticity(sim, "crime_total", lags = 0, method = m), silent = TRUE)
      if (!inherits(fit, "try-error")) {
        lr <- fit$diagnostics$long_run
        rows[[length(rows) + 1L]] <- record(
          paste0("lamp_elasticity (", m, ")"), lr$estimate, lr$conf_low, lr$conf_high,
          target_value = NA_real_
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
all_rows <- list()
for (g in seq_len(nrow(grid))) {
  design <- grid$design[g]
  missing <- grid$missing[g]
  message(sprintf("  %s, missingness %.0f%%", design, 100 * missing))
  for (rep in seq_len(n_reps)) {
    all_rows[[length(all_rows) + 1L]] <- one_rep(rep, design, missing)
    if (rep %% 25 == 0) message(sprintf("    %d/%d", rep, n_reps))
  }
}
results <- dplyr::bind_rows(all_rows)
utils::write.csv(results, file.path(out_dir, "simulation-study.csv"), row.names = FALSE)

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

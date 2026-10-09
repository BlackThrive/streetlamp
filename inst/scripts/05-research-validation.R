# Research validation of 0.2.0 development changes. No downloads.
# Run from the package root: Rscript inst/scripts/05-research-validation.R 200 2
# Historical 0.1.0 results are preserved in inst/validation.
suppressMessages(devtools::load_all(quiet = TRUE))
fixest::setFixest_nthreads(1)
args <- commandArgs(trailingOnly = TRUE)
n_reps <- if (length(args)) as.integer(args[1]) else 200L
n_workers <- if (length(args) > 1L) as.integer(args[2]) else 1L
stopifnot(is.finite(n_reps), n_reps > 0, is.finite(n_workers), n_workers > 0)
out_dir <- file.path("inst", "validation", "research-upgrade")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

record <- function(rep, scenario, estimator, target, fit, n_areas, n_months, seed) {
  failed <- inherits(fit, "error")
  tibble::tibble(rep = rep, scenario = scenario, estimator = estimator,
    n_areas = n_areas, n_months = n_months, seed = seed, target = target,
    status = if (failed) "failed" else "ok",
    message = if (failed) conditionMessage(fit) else NA_character_,
    estimate = if (failed) NA_real_ else fit$estimate,
    std_error = if (failed) NA_real_ else fit$std_error,
    conf_low = if (failed) NA_real_ else fit$conf_low,
    conf_high = if (failed) NA_real_ else fit$conf_high,
    covered = if (failed) FALSE else fit$conf_low <= target && fit$conf_high >= target)
}

one_rep <- function(rep, scenario) {
  seed <- 20261006L + rep
  na <- 100L
  nt <- 36L
  rows <- list()
  if (scenario %in% c("count_mean", "sparse_counts", "overdispersed", "selective_missing")) {
    sim <- lamp_simulate(n_areas = na, n_months = nt, design = "continuous",
      effect = -0.25, base_rate = if (scenario == "sparse_counts") 8 else 30,
      dispersion = if (scenario == "overdispersed") 2 else Inf,
      missing = if (scenario == "selective_missing") 0.1 else 0,
      missing_mechanism = if (scenario == "selective_missing") "high_outcome" else "random", seed = seed)
    # All 12 affected types have this exact log conditional mean slope.
    # The legacy row intentionally compares a different response scale with
    # this target, exposing the historical estimand mismatch.
    for (family in c("poisson", "ols_log")) {
      fit <- tryCatch(lamp_effect_summary(lamp_elasticity(sim, "affected_crime", lags = 0,
                                                         family = family)), error = function(e) e)
      rows[[length(rows) + 1L]] <- record(rep, scenario,
        if (family == "poisson") "PPML (matched count-mean target)" else "OLS log1p (count-mean target mismatch)",
        -0.25, fit, na, nt, seed)
    }
  } else {
    na <- 96L
    nt <- 24L
    heterogeneous <- scenario != "homogeneous_additive"
    sim <- lamp_simulate(n_areas = na, n_months = nt, design = "staggered", adoption = c(8, 12, 16),
      effect = -6, cohort_effects = if (heterogeneous) c("8" = -10, "12" = -4, "16" = 5) else NULL,
      dynamic_effect = if (scenario %in% c("dynamic_cohorts", "violated_parallel_trends")) c(0, 0.5, 1) else NULL,
      trend_violation = if (scenario == "violated_parallel_trends") 0.25 else 0,
      base_rate = 100, effect_scale = "additive", seed = seed)
    truth <- lamp_simulation_truth(sim, "affected_crime", "identity")
    # Balanced panel: the simple ATT weights each observed treated area-month
    # equally. Both backend overall ATT definitions are checked on this support.
    target <- mean(truth$effect[truth$treated == 1])
    adoption <- attr(sim, "truth")$adoption
    tr <- lamp_treatment(sim, "staggered", adoption = adoption[!is.na(adoption$adoption_month), ])
    for (backend in c("callaway_santanna", "sun_abraham")) {
      fit <- tryCatch(suppressMessages(lamp_effect_summary(lamp_did_staggered(sim, "affected_crime", tr,
        estimator = backend, family = "identity", window = c(-6, 8)))), error = function(e) e)
      rows[[length(rows) + 1L]] <- record(rep, scenario, backend, target, fit, na, nt, seed)
    }
    fit <- tryCatch({
      d <- as.data.frame(sim)
      m <- fixest::feols(affected_crime ~ treat | area + month, data = d, cluster = ~area, notes = FALSE)
      co <- streetlamp:::lamp_coefficients(m)
      co[1, ]
    }, error = function(e) e)
    rows[[length(rows) + 1L]] <- record(rep, scenario, "linear TWFE comparator", target, fit, na, nt, seed)
  }
  dplyr::bind_rows(rows)
}

run_study <- function() {
  cl <- NULL
  if (n_workers > 1L) {
    cl <- parallel::makeCluster(n_workers)
    on.exit(parallel::stopCluster(cl), add = TRUE)
    root <- normalizePath(".", winslash = "/")
    parallel::clusterExport(cl, "root", envir = environment())
    parallel::clusterEvalQ(cl, {
      suppressMessages(devtools::load_all(root, quiet = TRUE))
      fixest::setFixest_nthreads(1)
      NULL
    })
    parallel::clusterExport(cl, c("one_rep", "record"))
  }
  scenarios <- c("count_mean", "sparse_counts", "overdispersed", "selective_missing",
                 "homogeneous_additive", "heterogeneous_cohorts", "dynamic_cohorts", "violated_parallel_trends")
  all <- list()
  # Resume only completed count scenarios. Staggered scenarios are always
  # rerun so that revised additive settings cannot mix with an earlier run.
  saved <- file.path(out_dir, "simulation-replications.csv")
  if (file.exists(saved)) {
    previous <- utils::read.csv(saved, stringsAsFactors = FALSE)
    for (scenario in scenarios[seq_len(4)]) {
      cell <- previous[previous$scenario == scenario, ]
      if (nrow(cell) == 2L * n_reps && setequal(unique(cell$rep), seq_len(n_reps)) &&
          all(cell$seed == 20261006L + cell$rep)) all[[scenario]] <- cell
    }
  }
  for (scenario in scenarios) {
    if (scenario %in% names(all)) {
      message("Retaining completed count scenario: ", scenario)
      next
    }
    message("Running ", scenario, ": ", n_reps, " replications")
    cell <- if (is.null(cl)) lapply(seq_len(n_reps), one_rep, scenario = scenario) else
      parallel::parLapply(cl, seq_len(n_reps), one_rep, scenario = scenario)
    all[[scenario]] <- dplyr::bind_rows(cell)
    utils::write.csv(dplyr::bind_rows(all), file.path(out_dir, "simulation-replications.csv"), row.names = FALSE)
    message("Completed ", scenario)
  }
  dplyr::bind_rows(all)
}
results <- run_study()
summary <- results |>
  dplyr::group_by(.data$scenario, .data$estimator) |>
  dplyr::summarise(attempted = dplyr::n(), succeeded = sum(.data$status == "ok"),
    failure_rate = mean(.data$status != "ok"),
    bias = mean(.data$estimate - .data$target, na.rm = TRUE),
    rmse = sqrt(mean((.data$estimate - .data$target)^2, na.rm = TRUE)),
    coverage = mean(.data$covered[.data$status == "ok"]),
    coverage_including_failures = mean(.data$covered),
    .groups = "drop")
# Wilson intervals describe Monte Carlo uncertainty in coverage.
z <- stats::qnorm(0.975)
n <- summary$succeeded
p <- summary$coverage
centre <- (p + z^2 / (2 * n)) / (1 + z^2 / n)
half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / (1 + z^2 / n)
summary$coverage_mc_low <- centre - half
summary$coverage_mc_high <- centre + half
summary$bias_mc_se <- vapply(seq_len(nrow(summary)), function(i) {
  d <- results[results$scenario == summary$scenario[i] & results$estimator == summary$estimator[i] &
                 results$status == "ok", ]
  stats::sd(d$estimate - d$target) / sqrt(nrow(d))
}, numeric(1))
utils::write.csv(summary, file.path(out_dir, "simulation-summary.csv"), row.names = FALSE)
writeLines(c(paste("Package", utils::packageVersion("streetlamp")), paste("UTC", format(Sys.time(), tz = "UTC")),
             paste("Replications", n_reps), paste("Workers", n_workers), capture.output(sessionInfo())),
           file.path(out_dir, "session-info.txt"))
print(as.data.frame(summary), digits = 4, row.names = FALSE)

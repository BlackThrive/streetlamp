# Match the dimensions, mixture outcome and missingness of the old study.
# Rscript inst/scripts/05b-elasticity-original-design.R 200 2
suppressMessages(devtools::load_all(quiet = TRUE))
fixest::setFixest_nthreads(1)
args <- commandArgs(trailingOnly = TRUE)
n_reps <- if (length(args)) as.integer(args[1]) else 200L
n_workers <- if (length(args) > 1L) as.integer(args[2]) else 1L
stopifnot(n_reps > 0, n_workers > 0)
out_dir <- file.path("inst", "validation", "research-upgrade")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
one_rep <- function(rep, missing) {
  seed <- 30300000L + rep
  sim <- lamp_simulate(n_areas = 400, n_months = 60, design = "continuous", effect = -0.25,
                       base_rate = 30, missing = missing, seed = seed)
  truth <- lamp_simulation_truth(sim, "crime_total", "identity")
  d <- as.data.frame(sim)
  d$mean_total <- truth$mean_treated
  d <- d[d$coverage_status != "missing", ]
  d$x <- log1p(d$stops)
  # The total mixes affected and unaffected offences and has no one constant
  # structural slope. Define each finite-panel projection target explicitly.
  ppml_target <- unname(stats::coef(fixest::fepois(mean_total ~ x | area + month, data = d, notes = FALSE)))
  old_target <- unname(stats::coef(fixest::feols(log(mean_total) ~ x | area + month, data = d, notes = FALSE)))
  dplyr::bind_rows(lapply(c("poisson", "ols_log"), function(family) {
    target <- if (family == "poisson") ppml_target else old_target
    fit <- tryCatch(lamp_effect_summary(lamp_elasticity(sim, "crime_total", lags = 0, family = family)),
                    error = function(e) e)
    failed <- inherits(fit, "error")
    tibble::tibble(rep = rep, seed = seed, n_areas = 400L, n_months = 60L, missing = missing,
      estimator = if (family == "poisson") "PPML expected-count projection" else "legacy OLS vs log-mean projection (mismatch)",
      target = target, estimate = if (failed) NA_real_ else fit$estimate,
      conf_low = if (failed) NA_real_ else fit$conf_low,
      conf_high = if (failed) NA_real_ else fit$conf_high,
      status = if (failed) "failed" else "ok", message = if (failed) conditionMessage(fit) else NA_character_,
      covered = if (failed) FALSE else fit$conf_low <= target && fit$conf_high >= target)
  }))
}
run <- function() {
  cl <- NULL
  if (n_workers > 1) {
    cl <- parallel::makeCluster(n_workers)
    on.exit(parallel::stopCluster(cl), add = TRUE)
    root <- normalizePath(".", winslash = "/")
    parallel::clusterExport(cl, "root", envir = environment())
    parallel::clusterEvalQ(cl, {
      suppressMessages(devtools::load_all(root, quiet = TRUE))
      fixest::setFixest_nthreads(1)
      NULL
    })
    parallel::clusterExport(cl, "one_rep")
  }
  all <- list()
  for (missing in c(0, 0.1)) {
    message("Original design: 400 areas, 60 months, missing = ", missing)
    rows <- if (is.null(cl)) lapply(seq_len(n_reps), one_rep, missing = missing) else
      parallel::parLapply(cl, seq_len(n_reps), one_rep, missing = missing)
    all[[length(all) + 1L]] <- dplyr::bind_rows(rows)
    utils::write.csv(dplyr::bind_rows(all), file.path(out_dir, "elasticity-original-design.csv"), row.names = FALSE)
  }
  dplyr::bind_rows(all)
}
results <- run()
summary <- results |>
  dplyr::group_by(.data$missing, .data$estimator) |>
  dplyr::summarise(attempted = dplyr::n(), succeeded = sum(.data$status == "ok"),
    bias = mean(.data$estimate - .data$target, na.rm = TRUE),
    rmse = sqrt(mean((.data$estimate - .data$target)^2, na.rm = TRUE)),
    coverage = mean(.data$covered[.data$status == "ok"]), .groups = "drop")
z <- stats::qnorm(0.975)
n <- summary$succeeded
p <- summary$coverage
centre <- (p + z^2 / (2 * n)) / (1 + z^2 / n)
half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / (1 + z^2 / n)
summary$coverage_mc_low <- centre - half
summary$coverage_mc_high <- centre + half
utils::write.csv(summary, file.path(out_dir, "elasticity-original-design-summary.csv"), row.names = FALSE)
print(as.data.frame(summary), row.names = FALSE, digits = 4)

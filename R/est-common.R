# Estimator plumbing ------------------------------------------------------------------
#
# Every estimator returns a `lamp_estimate`: coefficients with clustered
# standard errors and intervals, the identifying assumption in words, the
# sample counts after each exclusion step, and a diagnostics list. The
# exclusion table is what makes "force did not submit is never a zero"
# visible in the output: rows dropped for coverage are counted, not silently
# ignored.

lamp_families <- function() c("poisson", "negbin", "ols_log", "ols_ihs")

lamp_family_label <- function(family) {
  switch(family,
    poisson = "Poisson pseudo-likelihood on counts",
    negbin = "negative binomial on counts",
    ols_log = "least squares on log(1 + outcome)",
    ols_ihs = "least squares on the inverse hyperbolic sine of the outcome"
  )
}

new_lamp_estimate <- function(estimator, coefficients, assumption, sample, diagnostics,
                              meta, model = NULL, contract = NULL, data = NULL) {
  structure(
    list(
      estimator = estimator,
      coefficients = coefficients,
      assumption = assumption,
      sample = sample,
      diagnostics = diagnostics,
      meta = meta,
      model = model,
      contract = contract,
      data = data,
      created = Sys.time()
    ),
    # the estimator's own class comes first so that its print and plot
    # methods are dispatched before the shared ones
    class = c(estimator, "lamp_estimate")
  )
}

# Prepare the modelling frame: attach the treatment, drop rows the estimator
# cannot use, and count every exclusion.
lamp_model_frame <- function(panel, outcome, treatment, controls = NULL, cluster = "area",
                             call = rlang::caller_env()) {
  contract <- lamp_check_panel(panel, call = call)
  check_string(outcome, call = call)
  if (!outcome %in% names(panel)) {
    lamp_abort(
      c(
        "{.arg outcome} must name a panel column; {.val {outcome}} is not one.",
        "i" = "Crime type columns are the keys of {.fn lamp_crime_types}."
      ),
      "input",
      call = call
    )
  }
  cluster <- rlang::arg_match(cluster, values = c("area", "force"), error_call = call)
  d <- tibble::as_tibble(panel)

  if (inherits(treatment, "lamp_treatment")) {
    tr <- treatment
    key_d <- paste(d$area, lamp_month_id(d$month))
    key_t <- paste(tr$data$area, lamp_month_id(tr$data$month))
    idx <- match(key_d, key_t)
    d$.treat <- tr$data[[tr$column]][idx]
    d$.rel_time <- tr$data$rel_time[idx]
    d$.cohort <- tr$data$cohort[idx]
  } else if (is.character(treatment) && length(treatment) == 1L) {
    if (!treatment %in% names(d)) {
      lamp_abort(
        "{.arg treatment} must name a panel column or be a {.cls lamp_treatment}.",
        "input",
        call = call
      )
    }
    tr <- new_lamp_treatment("column", treatment, d[, c("area", "month")], list(column = treatment))
    d$.treat <- d[[treatment]]
    d$.rel_time <- if ("rel_time" %in% names(d)) d$rel_time else NA_integer_
    d$.cohort <- if ("cohort" %in% names(d)) d$cohort else as.Date(NA)
  } else {
    lamp_abort(
      "{.arg treatment} must be a {.cls lamp_treatment} or the name of a panel column.",
      "input",
      call = call
    )
  }
  if (!is.null(controls)) {
    missing_controls <- setdiff(controls, names(d))
    if (length(missing_controls) > 0L) {
      lamp_abort(
        "Control{?s} {.field {missing_controls}} {?is/are} not panel columns.",
        "input",
        call = call
      )
    }
  }

  steps <- list(tibble::tibble(
    step = "panel rows", n_rows = nrow(d), n_areas = length(unique(d$area))
  ))
  if ("coverage_status" %in% names(d)) {
    keep <- d$coverage_status %in% lamp_filled_statuses()
    n_cov <- sum(!keep)
    d <- d[keep, ]
    steps[[length(steps) + 1L]] <- tibble::tibble(
      step = "after dropping force-months with no file", n_rows = nrow(d),
      n_areas = length(unique(d$area))
    )
  } else {
    n_cov <- 0L
  }
  keep <- !is.na(d[[outcome]]) & !is.na(d$.treat)
  if (!is.null(controls)) {
    for (cn in controls) keep <- keep & !is.na(d[[cn]])
  }
  d <- d[keep, ]
  steps[[length(steps) + 1L]] <- tibble::tibble(
    step = "after dropping missing outcome, treatment or controls", n_rows = nrow(d),
    n_areas = length(unique(d$area))
  )
  if (nrow(d) == 0L) {
    lamp_abort("No usable rows remain after exclusions.", "input", call = call)
  }
  d$.area <- factor(d$area)
  d$.month <- factor(lamp_month_id(d$month))
  d$.cluster <- if (cluster == "area") d$.area else factor(d$force_id)
  list(
    data = d, treatment = tr, contract = contract, outcome = outcome,
    cluster = cluster, sample = dplyr::bind_rows(steps),
    n_dropped_coverage = n_cov
  )
}

# Build the response for a family, so that every estimator transforms counts
# the same way and says so.
lamp_response <- function(outcome, family) {
  switch(family,
    poisson = outcome,
    negbin = outcome,
    ols_log = sprintf("log1p(%s)", outcome),
    ols_ihs = sprintf("asinh(%s)", outcome)
  )
}

lamp_fit <- function(formula, data, family, cluster, call = rlang::caller_env()) {
  fit <- rlang::try_fetch(
    switch(family,
      poisson = fixest::fepois(formula, data = data, cluster = ~.cluster, notes = FALSE),
      negbin = fixest::fenegbin(formula, data = data, cluster = ~.cluster, notes = FALSE),
      fixest::feols(formula, data = data, cluster = ~.cluster, notes = FALSE)
    ),
    error = function(e) {
      # a treatment that reaches every area is indistinguishable from a month
      # effect, which is the commonest way for this fit to fail
      treated <- unique(data$area[!is.na(data$.treat) & data$.treat > 0])
      hint <- if (length(treated) > 0L && length(treated) == length(unique(data$area))) {
        paste(
          "Every area is treated, so the treatment cannot be separated from the",
          "month fixed effects. Name the treated areas with the {.arg scope} or",
          "{.arg areas} argument of {.fn lamp_treatment}, leaving the rest as",
          "controls."
        )
      } else {
        "This usually means the treatment has no variation left after the fixed effects."
      }
      lamp_abort(
        c("The model could not be fitted.", "i" = hint),
        "input",
        call = call,
        parent = e
      )
    }
  )
  fit
}

# Coefficients with clustered standard errors and normal intervals.
lamp_coefficients <- function(fit, level = 0.95, keep = NULL) {
  ct <- as.data.frame(fixest::coeftable(fit))
  out <- tibble::tibble(
    term = rownames(ct),
    estimate = ct[[1]],
    std_error = ct[[2]],
    statistic = ct[[3]],
    p_value = ct[[4]]
  )
  z <- stats::qnorm(1 - (1 - level) / 2)
  out$conf_low <- out$estimate - z * out$std_error
  out$conf_high <- out$estimate + z * out$std_error
  if (!is.null(keep)) {
    out <- out[grepl(keep, out$term), ]
  }
  out
}

# Dispersion: the Pearson chi-square over residual degrees of freedom. Well
# above one means the counts are overdispersed and a negative binomial or
# clustered Poisson is the safer family.
lamp_dispersion <- function(fit, family) {
  if (!family %in% c("poisson", "negbin")) {
    return(NA_real_)
  }
  r <- rlang::try_fetch(stats::residuals(fit, type = "pearson"), error = function(e) NULL)
  if (is.null(r)) {
    return(NA_real_)
  }
  df <- fixest::degrees_freedom(fit, type = "resid")
  sum(r^2, na.rm = TRUE) / df
}

# Moran's I of the area-mean residuals, when the panel carries adjacency.
lamp_residual_moran <- function(fit, data, contract) {
  adj <- contract$geography$adjacency
  if (is.null(adj) || !inherits(adj, "lamp_adjacency")) {
    return(NULL)
  }
  r <- rlang::try_fetch(stats::residuals(fit), error = function(e) NULL)
  if (is.null(r) || length(r) != nrow(data)) {
    return(NULL)
  }
  by_area <- tapply(r, data$area, mean, na.rm = TRUE)
  areas <- intersect(adj$areas, names(by_area))
  if (length(areas) < 5L) {
    return(NULL)
  }
  keep <- match(areas, adj$areas)
  nb <- spdep::subset.nb(adj$nb, seq_along(adj$areas) %in% keep)
  listw <- rlang::try_fetch(
    spdep::nb2listw(nb, style = "W", zero.policy = TRUE),
    error = function(e) NULL
  )
  if (is.null(listw)) {
    return(NULL)
  }
  test <- rlang::try_fetch(
    spdep::moran.test(as.numeric(by_area[areas]), listw, zero.policy = TRUE),
    error = function(e) NULL
  )
  if (is.null(test)) {
    return(NULL)
  }
  list(
    statistic = unname(test$estimate[["Moran I statistic"]]),
    p_value = unname(test$p.value),
    n_areas = length(areas),
    note = paste(
      "Positive spatial correlation in the residuals means the standard",
      "errors understate uncertainty; consider clustering at force level or",
      "modelling spillovers."
    )
  )
}

#' @export
print.lamp_estimate <- function(x, ...) {
  cli::cli_h3("streetlamp estimate: {x$estimator}")
  cli::cli_text("Outcome: {.field {x$meta$outcome}}; family: {lamp_family_label(x$meta$family)}")
  cli::cli_text("Treatment: {x$meta$treatment_type}; clustered by {x$meta$cluster}")
  cli::cli_text("{.strong Identifying assumption}: {x$assumption}")
  used <- x$sample[nrow(x$sample), ]
  cli::cli_text(
    "Sample: {used$n_rows} area-month{?s} in {used$n_areas} area{?s}; ",
    "{x$diagnostics$n_dropped_coverage} row{?s} dropped for coverage."
  )
  if (!is.null(x$diagnostics$pretrend_p)) {
    cli::cli_text("Pre-trend joint test: p = {signif(x$diagnostics$pretrend_p, 3)}")
  }
  if (!is.null(x$diagnostics$dispersion) && !is.na(x$diagnostics$dispersion)) {
    cli::cli_text("Dispersion: {signif(x$diagnostics$dispersion, 3)}")
  }
  if (!is.null(x$diagnostics$moran)) {
    m <- x$diagnostics$moran
    cli::cli_text("Moran's I of residuals: {signif(m$statistic, 3)} (p = {signif(m$p_value, 3)})")
  }
  print(as.data.frame(x$coefficients), row.names = FALSE, digits = 3)
  invisible(x)
}

#' @export
summary.lamp_estimate <- function(object, ...) {
  print(object, ...)
  cli::cli_h3("Exclusions")
  print(as.data.frame(object$sample), row.names = FALSE)
  invisible(object)
}

#' @importFrom generics tidy
#' @export
generics::tidy

#' Tidy a streetlamp estimate
#'
#' @param x A `lamp_estimate`.
#' @param ... Unused.
#' @return A tibble with columns `term`, `estimate`, `std_error`,
#'   `statistic`, `p_value`, `conf_low` and `conf_high`.
#' @family estimators
#' @exportS3Method generics::tidy
tidy.lamp_estimate <- function(x, ...) {
  x$coefficients
}

# Wrap a long assumption so that it fits under a plot title instead of
# running off the right edge of the panel.
lamp_wrap_subtitle <- function(x, width = 90L) {
  paste(strwrap(x, width = width), collapse = "\n")
}

#' @export
plot.lamp_estimate <- function(x, y = NULL, ...) {
  d <- x$coefficients
  d$term <- factor(d$term, levels = rev(d$term))
  ggplot2::ggplot(d, ggplot2::aes(y = .data$term, x = .data$estimate)) +
    ggplot2::geom_vline(xintercept = 0, linetype = 2, colour = "grey50") +
    ggplot2::geom_pointrange(ggplot2::aes(xmin = .data$conf_low, xmax = .data$conf_high)) +
    ggplot2::labs(
      x = "estimate", y = NULL,
      title = sprintf("%s: %s", x$estimator, x$meta$outcome),
      subtitle = lamp_wrap_subtitle(x$assumption)
    ) +
    ggplot2::theme_minimal()
}

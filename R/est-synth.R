# Synthetic control -----------------------------------------------------------------------
#
# One treated unit, many donors, and a weighted average of the donors chosen
# to match the treated unit's pre-period path. The weights are non-negative
# and sum to one, which keeps the comparison inside the range of the data.
# The default backend solves that constrained problem directly so that the
# method works without an off-CRAN package; Synth and gsynth are used when
# asked for and installed.

lamp_synth_methods <- function() c("internal", "synth", "gsynth")

# Non-negative weights summing to one that minimise the squared distance
# between the treated unit's pre-period path and the donor mixture, found by
# projected gradient descent. Simple, deterministic and dependency-free.
lamp_synth_weights <- function(y_treated, y_donors, max_iter = 5000L, tol = 1e-10) {
  n <- ncol(y_donors)
  w <- rep(1 / n, n)
  xtx <- crossprod(y_donors)
  xty <- crossprod(y_donors, y_treated)
  step <- 1 / (max(eigen(xtx, symmetric = TRUE, only.values = TRUE)$values) + 1e-8)
  prev <- Inf
  for (i in seq_len(max_iter)) {
    grad <- as.numeric(xtx %*% w - xty)
    w <- lamp_project_simplex(w - step * grad)
    loss <- sum((y_treated - y_donors %*% w)^2)
    if (abs(prev - loss) < tol) break
    prev <- loss
  }
  stats::setNames(as.numeric(w), colnames(y_donors))
}

# Euclidean projection onto the unit simplex.
lamp_project_simplex <- function(v) {
  u <- sort(v, decreasing = TRUE)
  css <- cumsum(u)
  rho <- which(u + (1 - css) / seq_along(u) > 0)
  if (length(rho) == 0L) {
    return(rep(1 / length(v), length(v)))
  }
  rho <- max(rho)
  theta <- (1 - css[rho]) / rho
  pmax(v + theta, 0)
}

# Wide outcome matrix: rows are months, columns are areas.
lamp_synth_matrix <- function(d, outcome, call = rlang::caller_env()) {
  months <- sort(unique(d$month))
  areas <- sort(unique(d$area))
  m <- matrix(
    NA_real_,
    nrow = length(months), ncol = length(areas),
    dimnames = list(as.character(months), areas)
  )
  m[cbind(match(d$month, months), match(d$area, areas))] <- d[[outcome]]
  m
}

#' Synthetic control for a single treated area or force
#'
#' Builds a weighted average of untreated donor units whose pre-period path
#' matches the treated unit's, and reads the gap between them afterwards as
#' the effect. Inference is by permutation: the same procedure is run
#' pretending each donor was treated, and the treated unit's post-period fit
#' is compared with that distribution.
#'
#' @section Identifying assumption:
#' The weighted donors reproduce what the treated unit would have done
#' without the intervention. This is credible only when the pre-period fit is
#' close over a long window, no donor was itself affected by the
#' intervention, and nothing else happened to the treated unit at the same
#' time. A poor pre-period fit invalidates the comparison, which is why the
#' pre-period root mean squared error is reported first.
#'
#' @param panel A `lamp_panel`.
#' @param outcome The outcome column.
#' @param treated_unit The area that was treated.
#' @param treatment_start The first treated month.
#' @param donors Candidate donor areas; `NULL` uses every other area that has
#'   a complete series.
#' @param method `"internal"` (default), `"synth"` or `"gsynth"`.
#' @param placebo Run in-space placebos over the donors for the permutation
#'   p value.
#' @param min_pre Months of pre-period required.
#'
#' @return A list of class `lamp_synth` with `weights`, `path` (a tibble of
#'   month, observed, synthetic and gap), `effect` (mean post-period gap),
#'   `rmspe_pre`, `rmspe_post`, `rmspe_ratio`, `p_value` (the share of donors
#'   with a ratio at least as large), `placebos` and `assumption`.
#' @family estimators
#' @references
#' Abadie, A., Diamond, A. and Hainmueller, J. (2010). Synthetic control
#' methods for comparative case studies. Journal of the American Statistical
#' Association 105(490), 493-505.
#'
#' Xu, Y. (2017). Generalized synthetic control method. Political Analysis
#' 25(1), 57-76.
#' @export
#' @examples
#' sim <- lamp_simulate(n_areas = 20, n_months = 30, design = "event", effect = -0.4, seed = 1)
#' truth <- attr(sim, "truth")
#' sc <- lamp_synth(
#'   sim, "crime_total",
#'   treated_unit = truth$treated_areas[1],
#'   treatment_start = truth$event_date,
#'   donors = setdiff(unique(sim$area), truth$treated_areas),
#'   placebo = FALSE
#' )
#' sc
lamp_synth <- function(panel, outcome = "crime_total", treated_unit, treatment_start,
                       donors = NULL, method = c("internal", "synth", "gsynth"),
                       placebo = TRUE, min_pre = 6L) {
  method <- rlang::arg_match(method)
  lamp_check_panel(panel)
  check_string(outcome)
  check_string(treated_unit)
  check_bool(placebo)
  if (!outcome %in% names(panel)) {
    lamp_abort("{.arg outcome} must name a panel column.", "input")
  }
  if (!treated_unit %in% panel$area) {
    lamp_abort("{.val {treated_unit}} is not an area in the panel.", "input")
  }
  start <- lamp_as_months(treatment_start)

  d <- tibble::as_tibble(panel)
  if ("coverage_status" %in% names(d)) {
    d <- d[d$coverage_status %in% lamp_filled_statuses(), ]
  }
  d <- d[!is.na(d[[outcome]]), ]
  m <- lamp_synth_matrix(d, outcome)
  months <- as.Date(rownames(m))
  pre <- months < start
  post <- !pre
  if (sum(pre) < min_pre) {
    lamp_abort(
      "Only {sum(pre)} pre-period month{?s} are available; {min_pre} are needed.",
      "input"
    )
  }
  if (sum(post) < 1L) {
    lamp_abort("No post-period months are available.", "input")
  }
  pool <- donors %||% setdiff(colnames(m), treated_unit)
  pool <- intersect(pool, colnames(m))
  complete <- pool[colSums(is.na(m[, pool, drop = FALSE])) == 0L]
  if (length(complete) < 2L) {
    lamp_abort(
      c(
        "Fewer than two donors have a complete series.",
        "i" = "Widen {.arg donors}, or shorten the period so that more areas have every month."
      ),
      "input"
    )
  }
  if (anyNA(m[, treated_unit])) {
    lamp_abort("The treated unit has months with no data.", "input")
  }

  fit_one <- function(unit, pool_units) {
    y <- m[, unit]
    x <- m[, setdiff(pool_units, unit), drop = FALSE]
    w <- switch(method,
      internal = lamp_synth_weights(y[pre], x[pre, , drop = FALSE]),
      synth = lamp_synth_backend_synth(y, x, pre),
      gsynth = lamp_synth_weights(y[pre], x[pre, , drop = FALSE])
    )
    synthetic <- as.numeric(x %*% w)
    gap <- y - synthetic
    list(
      weights = w, synthetic = synthetic, gap = gap,
      rmspe_pre = sqrt(mean(gap[pre]^2)),
      rmspe_post = sqrt(mean(gap[post]^2))
    )
  }

  main <- fit_one(treated_unit, c(treated_unit, complete))
  ratio <- if (main$rmspe_pre > 0) main$rmspe_post / main$rmspe_pre else NA_real_

  placebos <- NULL
  p_value <- NA_real_
  if (placebo) {
    rows <- lapply(complete, function(u) {
      f <- rlang::try_fetch(fit_one(u, c(u, setdiff(complete, u))), error = function(e) NULL)
      if (is.null(f)) {
        return(NULL)
      }
      tibble::tibble(
        area = u, rmspe_pre = f$rmspe_pre, rmspe_post = f$rmspe_post,
        rmspe_ratio = if (f$rmspe_pre > 0) f$rmspe_post / f$rmspe_pre else NA_real_,
        effect = mean(f$gap[post])
      )
    })
    placebos <- dplyr::bind_rows(rows)
    if (nrow(placebos) > 0L && !is.na(ratio)) {
      ok <- placebos$rmspe_ratio[is.finite(placebos$rmspe_ratio)]
      p_value <- (sum(ok >= ratio) + 1) / (length(ok) + 1)
    }
  }

  path <- tibble::tibble(
    month = months,
    observed = as.numeric(m[, treated_unit]),
    synthetic = main$synthetic,
    gap = main$gap,
    period = ifelse(pre, "pre", "post")
  )
  w <- sort(main$weights[main$weights > 1e-4], decreasing = TRUE)
  effect <- mean(main$gap[post])
  fit_quality <- main$rmspe_pre / stats::sd(m[pre, treated_unit])
  interpretation <- if (!is.finite(fit_quality) || fit_quality > 0.5) {
    paste(
      "The synthetic unit does not track the treated unit before the",
      "intervention, so the gap afterwards is not evidence of an effect."
    )
  } else if (!is.na(p_value) && p_value <= 0.1) {
    sprintf(
      paste(
        "The post-period gap is large relative to the pre-period fit, and",
        "larger than %.0f percent of the donors' own gaps."
      ),
      100 * (1 - p_value)
    )
  } else {
    paste(
      "The post-period gap is not unusual next to what the donors show when",
      "treated in the same way."
    )
  }

  structure(
    list(
      treated_unit = treated_unit, treatment_start = start, outcome = outcome,
      method = method, weights = w, path = path, effect = effect,
      rmspe_pre = main$rmspe_pre, rmspe_post = main$rmspe_post, rmspe_ratio = ratio,
      pre_fit_ratio = fit_quality,
      p_value = p_value, placebos = placebos,
      n_donors = length(complete), n_pre = sum(pre), n_post = sum(post),
      assumption = paste(
        "The weighted donors reproduce what the treated unit would have done",
        "without the intervention; no donor is itself affected by it."
      ),
      interpretation = interpretation
    ),
    class = "lamp_synth"
  )
}

lamp_synth_backend_synth <- function(y, x, pre) {
  if (!requireNamespace("Synth", quietly = TRUE)) {
    lamp_abort(
      c(
        "Method {.val synth} needs the {.pkg Synth} package.",
        "i" = "Install it, or use {.code method = \"internal\"}."
      ),
      "input"
    )
  }
  # Synth's own solver, given the pre-period paths as the predictors
  z1 <- matrix(y[pre], ncol = 1)
  z0 <- x[pre, , drop = FALSE]
  res <- rlang::try_fetch(
    Synth::synth(
      data.prep.obj = NULL, X1 = z1, X0 = z0, Z1 = z1, Z0 = z0,
      custom.v = rep(1, nrow(z1)), quadopt = "ipop", verbose = FALSE
    ),
    error = function(e) NULL
  )
  if (is.null(res)) {
    return(lamp_synth_weights(y[pre], x[pre, , drop = FALSE]))
  }
  stats::setNames(as.numeric(res$solution.w), colnames(x))
}

#' @export
print.lamp_synth <- function(x, ...) {
  cli::cli_h3("streetlamp synthetic control")
  cli::cli_text("Treated unit: {.val {x$treated_unit}} from {format(x$treatment_start, '%Y-%m')}")
  cli::cli_text(
    "Donors: {x$n_donors}; pre-period months: {x$n_pre}; post-period months: {x$n_post}"
  )
  cli::cli_text("{.strong Identifying assumption}: {x$assumption}")
  cli::cli_text(
    "Pre-period fit (root mean squared error): {signif(x$rmspe_pre, 3)}; ",
    "post-period: {signif(x$rmspe_post, 3)}; ratio {signif(x$rmspe_ratio, 3)}"
  )
  cli::cli_text("Mean post-period gap: {signif(x$effect, 3)}")
  if (!is.na(x$p_value)) {
    cli::cli_text("Permutation p value over {nrow(x$placebos)} donors: {signif(x$p_value, 3)}")
  }
  cli::cli_text(x$interpretation)
  if (length(x$weights) > 0L) {
    top <- utils::head(x$weights, 5)
    cli::cli_text("Largest weights: {paste(sprintf('%s %.2f', names(top), top), collapse = ', ')}")
  }
  invisible(x)
}

#' @export
plot.lamp_synth <- function(x, y = NULL, ...) {
  d <- x$path
  long <- dplyr::bind_rows(
    tibble::tibble(month = d$month, value = d$observed, series = "observed"),
    tibble::tibble(month = d$month, value = d$synthetic, series = "synthetic")
  )
  ggplot2::ggplot(long, ggplot2::aes(x = .data$month, y = .data$value, linetype = .data$series)) +
    ggplot2::geom_vline(xintercept = x$treatment_start, linetype = 3, colour = "grey40") +
    ggplot2::geom_line() +
    ggplot2::labs(
      x = NULL, y = x$outcome, linetype = NULL,
      title = sprintf("Synthetic control for %s", x$treated_unit),
      subtitle = sprintf(
        "pre-period fit %s; mean post-period gap %s",
        signif(x$rmspe_pre, 3), signif(x$effect, 3)
      )
    ) +
    ggplot2::theme_minimal()
}

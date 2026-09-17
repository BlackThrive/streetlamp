# Event study -------------------------------------------------------------------------

#' Event study around a dated intervention
#'
#' Estimates one coefficient per month relative to the intervention, so that
#' the path of the outcome before and after the event is visible rather than
#' summarised in a single number. The months before the event are the
#' pre-trend test: if the outcome was already moving, the parallel-trends
#' assumption behind any difference-in-differences estimate is in doubt.
#'
#' @section Identifying assumption:
#' In the absence of the event, treated areas would have followed the same
#' path as controls, net of area and month fixed effects. The pre-period
#' coefficients test a necessary consequence of this, not the assumption
#' itself: passing the test does not establish parallel trends, and with few
#' areas the test has little power to detect a trend that matters. See
#' [lamp_pretrends()].
#'
#' @section Staggered adoption:
#' When areas adopt at different dates, relative-time dummies in a two-way
#' fixed effects regression use already-treated areas as controls and are
#' biased. This function never does that: with more than one adoption date it
#' stops and explains, or, with `staggered_ok = TRUE`, hands the work to
#' [lamp_did_staggered()] and says so. The result is then a
#' `lamp_did_staggered` estimate, not an event study.
#'
#' @inheritParams lamp_twfe
#' @param event A [lamp_treatment()] object of type `event` or `binary`, or
#'   the name of a panel column holding relative time.
#' @param window The first and last relative month to estimate, default
#'   `c(-12, 12)`. Months outside it are pooled into endpoint bins so that
#'   they still contribute to the fixed effects.
#' @param reference The omitted relative month, default `-1` (the month
#'   before the event).
#' @param staggered_ok With several adoption dates, delegate to
#'   [lamp_did_staggered()] instead of stopping.
#'
#' @return A `lamp_estimate` of class `lamp_event_study`. Its coefficients
#'   carry a `rel_time` column, and `diagnostics$pretrend_p` holds the joint
#'   test that every pre-period coefficient is zero.
#' @family estimators
#' @export
#' @examples
#' sim <- lamp_simulate(n_areas = 24, n_months = 24, design = "event", effect = -0.25, seed = 4)
#' truth <- attr(sim, "truth")
#' # half the areas are treated; the rest are the comparison group
#' tr <- lamp_treatment(
#'   sim, "event",
#'   date = truth$event_date, scope = truth$treated_areas, window = c(-6, 6)
#' )
#' es <- lamp_event_study(sim, "crime_total", tr, window = c(-6, 6))
#' es
#' plot(es)
lamp_event_study <- function(panel, outcome = "crime_total", event, window = c(-12, 12),
                             reference = -1, cluster = c("area", "force"),
                             family = c("poisson", "negbin", "ols_log", "ols_ihs"),
                             controls = NULL, staggered_ok = FALSE) {
  cluster <- rlang::arg_match(cluster)
  family <- rlang::arg_match(family)
  if (length(window) != 2L || window[1] >= window[2]) {
    lamp_abort("{.arg window} must give a first and last relative month.", "input")
  }
  if (!is.numeric(reference) || length(reference) != 1L) {
    lamp_abort("{.arg reference} must be a single relative month.", "input")
  }
  mf <- lamp_model_frame(panel, outcome, event, controls, cluster)
  d <- mf$data
  if (all(is.na(d$.rel_time))) {
    lamp_abort(
      c(
        "The treatment carries no relative time.",
        "i" = "Use {.fn lamp_treatment} with type {.val event}, {.val binary} or {.val staggered}."
      ),
      "input"
    )
  }
  n_cohorts <- lamp_n_cohorts(d)
  if (n_cohorts > 1L) {
    if (!isTRUE(staggered_ok)) {
      lamp_abort(
        c(
          "Areas adopt the treatment at {n_cohorts} different dates.",
          "x" = paste(
            "Relative-time dummies in a two-way fixed effects regression are",
            "biased under staggered adoption, because already-treated areas act",
            "as controls."
          ),
          "i" = "Set {.code staggered_ok = TRUE} to hand this to {.fn lamp_did_staggered}."
        ),
        "estimator"
      )
    }
    lamp_inform(
      c(
        "Areas adopt at {n_cohorts} different dates: two-way fixed effects would be biased.",
        "i" = "Calling {.fn lamp_did_staggered} instead, with the Callaway and Sant'Anna estimator."
      ),
      class = "estimator"
    )
    return(lamp_did_staggered(
      panel, outcome, event,
      cluster = cluster, window = window
    ))
  }

  window <- as.integer(window)
  if (!reference %in% seq(window[1], window[2])) {
    lamp_abort("{.arg reference} must lie inside {.arg window}.", "input")
  }
  rel <- d$.rel_time
  binned <- pmin(pmax(rel, window[1]), window[2])
  d$.rel <- ifelse(is.na(binned), reference, binned)
  d$.treated_area <- as.numeric(!is.na(rel))
  if (sum(d$.treated_area) == 0L) {
    lamp_abort("No area is treated in this panel.", "input")
  }
  d$.rel <- stats::relevel(factor(d$.rel), ref = as.character(reference))

  fml <- stats::as.formula(paste(
    lamp_response(outcome, family), "~",
    sprintf("i(.rel, .treated_area, ref = '%s')", reference),
    if (!is.null(controls)) paste("+", paste(controls, collapse = " + ")) else "",
    "| .area + .month"
  ))
  fit <- lamp_fit(fml, d, family, cluster)

  coefs <- lamp_coefficients(fit, keep = "^\\.rel::")
  coefs$rel_time <- as.integer(sub("^\\.rel::(-?[0-9]+).*$", "\\1", coefs$term))
  coefs <- coefs[order(coefs$rel_time), ]
  ref_row <- tibble::tibble(
    term = paste0(".rel::", reference, ":.treated_area"), estimate = 0, std_error = 0,
    statistic = NA_real_, p_value = NA_real_, conf_low = 0, conf_high = 0,
    rel_time = as.integer(reference)
  )
  coefs <- dplyr::bind_rows(coefs, ref_row)
  coefs <- coefs[order(coefs$rel_time), ]

  pre_terms <- coefs$term[coefs$rel_time < 0 & coefs$rel_time != reference]
  pretrend <- if (length(pre_terms) > 0L) {
    keep <- paste0("^", gsub("([.:])", "\\\\\\1", pre_terms), "$")
    w <- rlang::try_fetch(
      fixest::wald(fit, keep = keep, print = FALSE),
      error = function(e) NULL
    )
    if (is.null(w)) NULL else w
  } else {
    NULL
  }

  diagnostics <- list(
    n_dropped_coverage = mf$n_dropped_coverage,
    pretrend_p = if (is.null(pretrend)) NA_real_ else pretrend$p,
    pretrend = pretrend,
    n_pre = sum(coefs$rel_time < 0), n_post = sum(coefs$rel_time >= 0),
    dispersion = lamp_dispersion(fit, family),
    moran = lamp_residual_moran(fit, d, mf$contract),
    reference = as.integer(reference), window = window,
    n_cohorts = n_cohorts
  )
  contract <- mf$contract
  contract$treatment <- mf$treatment
  new_lamp_estimate(
    "lamp_event_study", coefs,
    assumption = paste(
      "Parallel trends around the event: without it, treated areas would have",
      "followed the control path, net of area and month fixed effects.",
      "Pre-period coefficients test a consequence of this, not the assumption."
    ),
    sample = mf$sample, diagnostics = diagnostics,
    meta = list(
      outcome = outcome, family = family, cluster = cluster,
      treatment_type = mf$treatment$type, controls = controls,
      reference = as.integer(reference)
    ),
    model = fit, contract = contract, data = d
  )
}

#' @export
print.lamp_event_study <- function(x, ...) {
  # show relative time rather than the fixest term names
  compact <- x
  compact$coefficients <- x$coefficients[, c(
    "rel_time", "estimate", "std_error", "conf_low", "conf_high", "p_value"
  )]
  print.lamp_estimate(compact, ...)
  invisible(x)
}

#' @export
plot.lamp_event_study <- function(x, y = NULL, ...) {
  d <- x$coefficients
  ref <- x$meta$reference
  ggplot2::ggplot(d, ggplot2::aes(x = .data$rel_time, y = .data$estimate)) +
    ggplot2::annotate(
      "rect",
      xmin = min(d$rel_time) - 0.5, xmax = -0.5, ymin = -Inf, ymax = Inf,
      fill = "grey92"
    ) +
    ggplot2::geom_hline(yintercept = 0, linetype = 2, colour = "grey40") +
    ggplot2::geom_vline(xintercept = -0.5, linetype = 3, colour = "grey40") +
    ggplot2::geom_pointrange(ggplot2::aes(ymin = .data$conf_low, ymax = .data$conf_high)) +
    ggplot2::labs(
      x = sprintf("months relative to the event (reference %s)", ref),
      y = sprintf("effect on %s", x$meta$outcome),
      title = "Event study",
      subtitle = sprintf(
        "shaded: before the event; pre-trend joint test p = %s",
        signif(x$diagnostics$pretrend_p, 3)
      )
    ) +
    ggplot2::theme_minimal()
}

# Pre-trend and placebo diagnostics ----------------------------------------------------

# The headline number of an estimate: the treatment coefficient for a
# single-coefficient estimator, the mean post-period coefficient for an event
# study.
lamp_estimate_statistic <- function(x) {
  if (inherits(x, "lamp_event_study")) {
    post <- x$coefficients[x$coefficients$rel_time >= 0, ]
    return(mean(post$estimate))
  }
  x$coefficients$estimate[1]
}

#' Test and interpret pre-trends
#'
#' Reports the joint test that every pre-period coefficient of an event study
#' is zero, and answers the question the test cannot: how large a pre-trend
#' could have been present without this test detecting it, and how much bias
#' that undetected pre-trend would put into the post-period estimates.
#'
#' @details
#' The power calculation follows the argument in Roth (2022) and is
#' implemented here rather than taken from another package. Under a linear
#' violation of parallel trends with slope `s` per month, the expected
#' pre-period coefficients are `s` times their relative time (measured from
#' the reference month), so the Wald statistic is non-central chi-square with
#' non-centrality `s^2 * t' V^-1 t`, where `t` is that vector of relative
#' times and `V` the clustered covariance of the pre-period coefficients.
#' Inverting this gives the slope the test detects with a given probability.
#' The bias column shows what that slope would add to each post-period
#' coefficient if it continued, which is the quantity that matters: a test
#' that passes while remaining blind to a trend big enough to explain the
#' result is not reassurance.
#'
#' @param estimate A `lamp_estimate` from [lamp_event_study()].
#' @param power Detection probabilities to report, default 0.5 and 0.8.
#' @param level Significance level of the pre-trend test, default 0.05.
#'
#' @return A list of class `lamp_pretrends` with `test` (statistic, degrees
#'   of freedom and p value), `coefficients` (the pre-period coefficients),
#'   `power` (a tibble of `power`, `slope` in log points per month, and
#'   `bias_mean_post`, the bias such a slope would add to the mean
#'   post-period coefficient) and `interpretation`.
#' @family diagnostics
#' @references Roth, J. (2022). Pretest with caution: event-study estimates
#'   after testing for parallel trends. American Economic Review: Insights
#'   4(3), 305-322.
#' @export
#' @examples
#' sim <- lamp_simulate(n_areas = 24, n_months = 24, design = "event", effect = -0.25, seed = 5)
#' truth <- attr(sim, "truth")
#' tr <- lamp_treatment(
#'   sim, "event",
#'   date = truth$event_date, scope = truth$treated_areas, window = c(-6, 6)
#' )
#' es <- lamp_event_study(sim, "crime_total", tr, window = c(-6, 6))
#' pt <- lamp_pretrends(es)
#' pt
lamp_pretrends <- function(estimate, power = c(0.5, 0.8), level = 0.05) {
  if (!inherits(estimate, "lamp_estimate")) {
    lamp_abort("{.arg estimate} must come from a streetlamp estimator.", "input")
  }
  if (!inherits(estimate, "lamp_event_study")) {
    lamp_abort(
      c(
        "Pre-trends need one coefficient per relative month.",
        "i" = "Use {.fn lamp_event_study} (or a staggered estimator's event-study aggregation)."
      ),
      "input"
    )
  }
  if (!is.numeric(power) || any(power <= 0 | power >= 1)) {
    lamp_abort("{.arg power} must lie between 0 and 1.", "input")
  }
  ref <- estimate$meta$reference
  coefs <- estimate$coefficients
  pre <- coefs[coefs$rel_time < 0 & coefs$rel_time != ref, ]
  if (nrow(pre) == 0L) {
    lamp_abort("The event study has no pre-period coefficients to test.", "input")
  }
  post <- coefs[coefs$rel_time >= 0, ]

  v <- rlang::try_fetch(stats::vcov(estimate$model), error = function(e) NULL)
  test <- estimate$diagnostics$pretrend
  df <- nrow(pre)
  slopes <- NULL
  if (!is.null(v)) {
    keep <- intersect(pre$term, rownames(v))
    if (length(keep) == nrow(pre)) {
      vp <- v[keep, keep, drop = FALSE]
      t_vec <- pre$rel_time[match(keep, pre$term)] - ref
      inv <- rlang::try_fetch(solve(vp), error = function(e) NULL)
      if (!is.null(inv)) {
        # non-centrality per unit slope
        lambda_unit <- as.numeric(t(t_vec) %*% inv %*% t_vec)
        crit <- stats::qchisq(1 - level, df)
        slope_for <- function(p) {
          f <- function(s) stats::pchisq(crit, df, ncp = s^2 * lambda_unit, lower.tail = FALSE) - p
          hi <- 1
          while (f(hi) < 0 && hi < 1e6) hi <- hi * 2
          if (f(hi) < 0) {
            return(NA_real_)
          }
          stats::uniroot(f, c(1e-8, hi))$root
        }
        mean_post_time <- mean(post$rel_time - ref)
        slopes <- tibble::tibble(
          power = power,
          slope = vapply(power, slope_for, numeric(1))
        )
        slopes$bias_mean_post <- slopes$slope * mean_post_time
      }
    }
  }

  p <- estimate$diagnostics$pretrend_p
  observed <- mean(abs(pre$estimate))
  interpretation <- if (is.na(p)) {
    "The joint pre-trend test could not be computed."
  } else if (p < level) {
    paste0(
      "The pre-period coefficients are jointly different from zero (p = ",
      signif(p, 3), "). Parallel trends is doubtful; the estimate should not be read as causal."
    )
  } else if (!is.null(slopes)) {
    top <- slopes[slopes$power == max(power), ][1, ]
    paste0(
      "The pre-trend test does not reject (p = ", signif(p, 3),
      "), but it would detect a linear trend of ", signif(top$slope, 2),
      " log points a month only ", 100 * max(power),
      " percent of the time; such a trend would shift the mean post-period ",
      "coefficient by ", signif(top$bias_mean_post, 2),
      ". Compare that with the estimate itself before treating the test as ",
      "reassurance."
    )
  } else {
    paste0("The pre-trend test does not reject (p = ", signif(p, 3), ").")
  }

  structure(
    list(
      test = list(
        statistic = if (is.null(test)) NA_real_ else test$stat,
        p_value = p, df = df, level = level
      ),
      coefficients = pre,
      power = slopes,
      observed_mean_abs_pre = observed,
      interpretation = interpretation,
      estimator = estimate$estimator,
      outcome = estimate$meta$outcome
    ),
    class = "lamp_pretrends"
  )
}

#' @export
print.lamp_pretrends <- function(x, ...) {
  cli::cli_h3("streetlamp pre-trend diagnostic")
  cli::cli_text(
    "Joint test of {x$test$df} pre-period coefficient{?s}: ",
    "p = {signif(x$test$p_value, 3)}"
  )
  if (!is.null(x$power)) {
    cli::cli_text("Linear pre-trend the test would detect:")
    lamp_print_table(lamp_table(x))
  }
  cli::cli_text(x$interpretation)
  invisible(x)
}

#' @export
plot.lamp_pretrends <- function(x, y = NULL, ...) {
  lamp_plot_dynamic(
    x$coefficients,
    reference = NA,
    x_label = "Months before the event",
    y_label = sprintf("Effect on %s (log points)", tolower(lamp_pretty_name(x$outcome))),
    title = "Pre-period coefficients",
    subtitle = sprintf(
      "Joint test that all %s are zero: %s",
      x$test$df, lamp_fmt_p_phrase(x$test$p_value)
    ),
    shade = FALSE
  )
}

# Placebo -----------------------------------------------------------------------------

lamp_refit <- function(estimate, data) {
  fml <- stats::formula(estimate$model)
  family <- estimate$meta$family
  fit <- rlang::try_fetch(
    switch(family,
      poisson = fixest::fepois(fml, data = data, cluster = ~.cluster, notes = FALSE),
      negbin = fixest::fenegbin(fml, data = data, cluster = ~.cluster, notes = FALSE),
      fixest::feols(fml, data = data, cluster = ~.cluster, notes = FALSE)
    ),
    error = function(e) NULL
  )
  if (is.null(fit)) {
    return(NA_real_)
  }
  co <- stats::coef(fit)
  if (inherits(estimate, "lamp_event_study")) {
    hit <- grepl("^\\.rel::", names(co))
    rel <- as.integer(sub("^\\.rel::(-?[0-9]+).*$", "\\1", names(co)[hit]))
    post <- co[hit][rel >= 0]
    if (length(post) == 0L) NA_real_ else mean(post)
  } else {
    if (".treat" %in% names(co)) unname(co[[".treat"]]) else unname(co[[1]])
  }
}

#' Placebo tests for a streetlamp estimate
#'
#' Re-estimates the same specification under conditions in which the true
#' effect is zero, and compares the real estimate with that distribution. An
#' estimate that looks the same when the treatment is moved to the wrong
#' date, the wrong areas, or an outcome the intervention cannot plausibly
#' affect, is measuring something other than the intervention.
#'
#' @details
#' Types:
#' * `time`: the event is moved back to each month that leaves a full
#'   pre-period, and only pre-period data is used, so nothing real happens at
#'   the fake date.
#' * `space`: the same number of areas is drawn at random, keeping the real
#'   dates, and the treatment is reassigned to them.
#' * `outcome`: the same specification is run on a crime type the
#'   intervention is not expected to move (bicycle theft by default), which
#'   tests for anything that shifts recorded crime generally, such as a
#'   recording change.
#'
#' The reported p value is the share of placebo estimates at least as large
#' in absolute value as the real one. It is a randomisation p value, not a
#' test of a specific null, and with few areas it is coarse.
#'
#' @param estimate A `lamp_estimate`.
#' @param type `"time"`, `"space"` or `"outcome"`.
#' @param n Number of placebo draws for `type = "space"`.
#' @param outcome Placebo outcome for `type = "outcome"`, default
#'   `"bicycle_theft"`.
#' @param seed Random seed for `type = "space"`.
#'
#' @return A list of class `lamp_placebo` with `type`, `actual` (the real
#'   estimate), `distribution` (a tibble of placebo estimates), `p_value`,
#'   `n_valid` and `interpretation`.
#' @family diagnostics
#' @export
#' @examples
#' sim <- lamp_simulate(n_areas = 20, n_months = 24, design = "event", effect = -0.3, seed = 6)
#' truth <- attr(sim, "truth")
#' tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
#' fit <- lamp_twfe(sim, "crime_total", tr)
#' lamp_placebo(fit, type = "space", n = 20, seed = 1)
lamp_placebo <- function(estimate, type = c("time", "space", "outcome"), n = 200,
                         outcome = "bicycle_theft", seed = NULL) {
  type <- rlang::arg_match(type)
  if (!inherits(estimate, "lamp_estimate")) {
    lamp_abort("{.arg estimate} must come from a streetlamp estimator.", "input")
  }
  d <- estimate$data
  if (is.null(d)) {
    lamp_abort(
      "This estimate does not carry its model frame, so placebo tests cannot be run.",
      "input"
    )
  }
  if (!is.null(seed)) {
    withr::local_seed(seed)
  }
  actual <- lamp_estimate_statistic(estimate)

  if (type == "outcome") {
    if (!outcome %in% names(d)) {
      lamp_abort("Placebo outcome {.field {outcome}} is not a panel column.", "input")
    }
    d2 <- d
    d2[[estimate$meta$outcome]] <- d2[[outcome]]
    d2 <- d2[!is.na(d2[[estimate$meta$outcome]]), ]
    values <- lamp_refit(estimate, d2)
    dist <- tibble::tibble(draw = 1L, estimate = values, label = outcome)
  } else if (type == "space") {
    treated_areas <- unique(d$area[d$.treat > 0])
    all_areas <- unique(d$area)
    if (length(treated_areas) == 0L || length(treated_areas) >= length(all_areas)) {
      lamp_abort("A spatial placebo needs both treated and untreated areas.", "input")
    }
    # Each draw gives every treated area a stand-in somewhere else and copies
    # its timing across. Done area by area that is a scan of the whole panel
    # per treated area, which on a two-force LSOA panel is hundreds of
    # millions of comparisons per draw; the row key does it in one lookup.
    month_key <- lamp_month_id(d$month)
    key <- paste(d$area, month_key)
    values <- numeric(n)
    for (i in seq_len(n)) {
      stand_in <- sample(all_areas, length(treated_areas))
      # stand-in area -> the treated area whose timing it borrows
      origin <- unname(stats::setNames(treated_areas, stand_in)[d$area])
      hit <- !is.na(origin)
      borrowed <- d$.treat[match(paste(origin[hit], month_key[hit]), key)]
      d2 <- d
      d2$.treat <- 0
      d2$.treat[hit] <- as.numeric(!is.na(borrowed) & borrowed > 0)
      d2$.rel_time <- NA_integer_
      values[i] <- lamp_refit(estimate, d2)
    }
    dist <- tibble::tibble(draw = seq_len(n), estimate = values, label = "random areas")
  } else {
    if (all(is.na(d$.rel_time))) {
      lamp_abort("A placebo in time needs a dated event.", "input")
    }
    months <- sort(unique(d$month))
    real_start <- min(d$month[d$.treat > 0], na.rm = TRUE)
    pre_months <- months[months < real_start]
    if (length(pre_months) < 6L) {
      lamp_abort("A placebo in time needs at least six pre-period months.", "input")
    }
    fake_dates <- pre_months[seq(3L, length(pre_months) - 1L)]
    if (length(fake_dates) > n) fake_dates <- utils::tail(fake_dates, n)
    treated_areas <- unique(d$area[d$.treat > 0])
    values <- numeric(length(fake_dates))
    for (i in seq_along(fake_dates)) {
      d2 <- d[d$month < real_start, ]
      d2$.treat <- as.numeric(d2$area %in% treated_areas & d2$month >= fake_dates[i])
      d2$.rel_time <- ifelse(
        d2$area %in% treated_areas,
        lamp_months_between(fake_dates[i], d2$month) - 1L, NA_integer_
      )
      values[i] <- lamp_refit(estimate, d2)
    }
    dist <- tibble::tibble(
      draw = seq_along(fake_dates), estimate = values,
      label = format(fake_dates, "%Y-%m")
    )
  }

  valid <- dist$estimate[is.finite(dist$estimate)]
  p <- if (length(valid) == 0L) NA_real_ else mean(abs(valid) >= abs(actual))
  interpretation <- if (length(valid) == 0L) {
    "No placebo fit converged."
  } else if (is.na(p)) {
    "The placebo share could not be computed."
  } else if (p <= 0.1) {
    sprintf(
      paste(
        "The real estimate (%s) is larger than %.0f percent of the placebo",
        "estimates, which is what a real effect looks like."
      ),
      signif(actual, 3), 100 * (1 - p)
    )
  } else {
    sprintf(
      paste(
        "Placebo estimates are as large as the real one (%s) %.0f percent of",
        "the time: the specification produces effects where none should exist,",
        "so the real estimate is not evidence of one."
      ),
      signif(actual, 3), 100 * p
    )
  }
  structure(
    list(
      type = type, actual = actual, distribution = dist, p_value = p,
      n_valid = length(valid), outcome = estimate$meta$outcome,
      placebo_outcome = if (type == "outcome") outcome else NULL,
      interpretation = interpretation
    ),
    class = "lamp_placebo"
  )
}

#' @export
print.lamp_placebo <- function(x, ...) {
  cli::cli_h3("streetlamp placebo: {x$type}")
  cli::cli_text("Real estimate: {signif(x$actual, 3)} on {.field {x$outcome}}")
  share <- signif(x$p_value, 3)
  cli::cli_text("{x$n_valid} placebo estimate{?s}; share at least as extreme: {share}")
  cli::cli_text(x$interpretation)
  invisible(x)
}

#' @export
plot.lamp_placebo <- function(x, y = NULL, ...) {
  col <- lamp_colours()
  d <- x$distribution[is.finite(x$distribution$estimate), ]
  # put the label on whichever side of the line has more room
  on_left <- x$actual > stats::median(c(d$estimate, x$actual))
  ggplot2::ggplot(d, ggplot2::aes(x = .data$estimate)) +
    ggplot2::geom_histogram(
      bins = min(30L, max(5L, nrow(d))),
      fill = col[["neutral"]], colour = col[["surface"]], linewidth = 0.6
    ) +
    ggplot2::geom_vline(xintercept = x$actual, colour = col[["accent"]], linewidth = 0.9) +
    ggplot2::annotate(
      "text",
      x = x$actual, y = Inf, label = sprintf("actual estimate %s", lamp_fmt_num(x$actual)),
      hjust = if (on_left) 1.08 else -0.08, vjust = 1.6,
      colour = col[["secondary"]], size = 3.2
    ) +
    ggplot2::scale_y_continuous(
      labels = lamp_label_number, expand = ggplot2::expansion(mult = c(0, 0.12))
    ) +
    ggplot2::labs(
      x = "Placebo estimate", y = "Placebo draws",
      title = sprintf("Placebo in %s", x$type),
      subtitle = sprintf(
        "%s placebo estimates; share at least as extreme as the actual: %s",
        lamp_label_number(nrow(d)), lamp_fmt_p_phrase(x$p_value)
      )
    ) +
    lamp_theme() +
    ggplot2::theme(panel.grid.major.x = ggplot2::element_blank())
}

# Staggered difference-in-differences ----------------------------------------------------

lamp_staggered_estimators <- function() c("callaway_santanna", "sun_abraham", "imputation")

# did and didimputation need numeric period indices and a cohort index, with 0
# (or Inf) marking the never-treated.
lamp_staggered_frame <- function(d, call = rlang::caller_env()) {
  months <- sort(unique(d$month))
  d$.t <- match(d$month, months)
  d$.id <- as.integer(factor(d$area))
  cohort <- d$.cohort
  d$.g <- ifelse(is.na(cohort), 0L, match(cohort, months))
  d$.g[is.na(d$.g)] <- 0L
  treated <- unique(d$.g[d$.g > 0])
  if (length(treated) == 0L) {
    lamp_abort(
      c(
        "No area adopts the treatment.",
        "i" = "Use {.fn lamp_treatment} with type {.val staggered} and an adoption table."
      ),
      "input",
      call = call
    )
  }
  list(data = d, months = months, n_cohorts = length(treated))
}

lamp_check_count_outcome <- function(d, outcome, family, call = rlang::caller_env()) {
  y <- d[[outcome]]
  looks_count <- is.numeric(y) && all(y >= 0, na.rm = TRUE) && all(y == round(y), na.rm = TRUE)
  if (looks_count && family %in% c("ols_log", "ols_ihs")) {
    lamp_warn(
      c(
        "{.field {outcome}} is a count, and this backend models it on the {family} scale.",
        "i" = paste(
          "Coefficients are effects on that transformed scale, not proportional",
          "effects on the count; zeros are handled by the transformation, not",
          "modelled."
        )
      ),
      "estimator"
    )
  }
  invisible(NULL)
}

#' Difference-in-differences with staggered adoption
#'
#' Estimates the effect of an intervention that different areas adopt at
#' different dates, using an estimator that compares each adopting cohort with
#' areas that have not yet adopted rather than with areas already treated.
#' Plain two-way fixed effects does the latter and can return an estimate
#' outside the range of every area's true effect; this function exists so that
#' staggered designs are not analysed that way.
#'
#' @section Identifying assumption:
#' Parallel trends holds for each adopting cohort against the chosen control
#' group, from the period before that cohort adopts onward, and there is no
#' anticipation: the outcome does not move before adoption in response to it.
#' With `control_group = "never_treated"` the comparison is against areas that
#' never adopt, which must exist; with `"not_yet_treated"` it is against areas
#' that adopt later, which uses more data but assumes their later adoption
#' carries no information about their current path.
#'
#' @section Backends:
#' * `callaway_santanna` (default) calls `did::att_gt()` and
#'   `did::aggte()`, giving one effect per cohort and period and the
#'   aggregations of them.
#' * `sun_abraham` uses `fixest::sunab()`, an interaction-weighted estimator
#'   fitted in one regression.
#' * `imputation` uses the `didimputation` package, which fits the untreated
#'   potential outcome and imputes: efficient, but it needs that package,
#'   which is in Suggests.
#'
#' Counts are modelled on a transformed scale by all three backends, which is
#' why the function warns when a count outcome meets `ols_log` or `ols_ihs`:
#' the coefficients are effects on that scale.
#'
#' @inheritParams lamp_twfe
#' @param treatment A [lamp_treatment()] object of type `staggered` (or
#'   `event`, which is a single cohort).
#' @param estimator `"callaway_santanna"`, `"sun_abraham"` or
#'   `"imputation"`.
#' @param control_group `"never_treated"` (default) or `"not_yet_treated"`.
#' @param family Scale for the outcome: `"ols_log"` (default, log of one plus
#'   the outcome), `"ols_ihs"` or `"identity"`.
#' @param window Relative months to report in the dynamic aggregation.
#'
#' @return A `lamp_estimate` of class `lamp_did_staggered`. `coefficients`
#'   holds the dynamic (event-study) aggregation with a `rel_time` column;
#'   `diagnostics$overall` is the single summary effect with its standard
#'   error; `diagnostics$group_time` holds the group-time effects for the
#'   Callaway and Sant'Anna backend; and `diagnostics$pretrend_p` is that
#'   backend's pre-test.
#' @family estimators
#' @references
#' Callaway, B. and Sant'Anna, P. H. C. (2021). Difference-in-differences with
#' multiple time periods. Journal of Econometrics 225(2), 200-230.
#'
#' Sun, L. and Abraham, S. (2021). Estimating dynamic treatment effects in
#' event studies with heterogeneous treatment effects. Journal of Econometrics
#' 225(2), 175-199.
#'
#' Borusyak, K., Jaravel, X. and Spiess, J. (2024). Revisiting event-study
#' designs: robust and efficient estimation. Review of Economic Studies 91(6).
#' @export
#' @examples
#' # small: most of this example's cost is loading the did package, which
#' # whichever example reaches it first has to pay
#' sim <- lamp_simulate(n_areas = 24, n_months = 18, design = "staggered", effect = -0.3, seed = 1)
#' ad <- attr(sim, "truth")$adoption
#' tr <- lamp_treatment(sim, "staggered", adoption = ad[!is.na(ad$adoption_month), ])
#' fit <- lamp_did_staggered(sim, "crime_total", tr)
#' fit
#' fit$diagnostics$overall
lamp_did_staggered <- function(panel, outcome = "crime_total", treatment,
                               estimator = c("callaway_santanna", "sun_abraham", "imputation"),
                               control_group = c("never_treated", "not_yet_treated"),
                               cluster = c("area", "force"),
                               family = c("ols_log", "ols_ihs", "identity"),
                               window = c(-12, 12)) {
  estimator <- rlang::arg_match(estimator)
  control_group <- rlang::arg_match(control_group)
  cluster <- rlang::arg_match(cluster)
  family <- rlang::arg_match(family)
  mf <- lamp_model_frame(panel, outcome, treatment, NULL, cluster)
  d <- mf$data
  if (all(is.na(d$.cohort))) {
    lamp_abort(
      c(
        "The treatment carries no adoption dates.",
        "i" = "Use {.fn lamp_treatment} with type {.val staggered}."
      ),
      "input"
    )
  }
  lamp_check_count_outcome(d, outcome, family)
  sf <- lamp_staggered_frame(d)
  d <- sf$data
  d$.y <- switch(family,
    ols_log = log1p(d[[outcome]]),
    ols_ihs = asinh(d[[outcome]]),
    identity = as.numeric(d[[outcome]])
  )
  if (control_group == "never_treated" && !any(d$.g == 0L)) {
    lamp_abort(
      c(
        "No area is never treated, so there is no never-treated control group.",
        "i" = "Use {.code control_group = \"not_yet_treated\"}."
      ),
      "input"
    )
  }

  res <- switch(estimator,
    callaway_santanna = lamp_did_cs(d, control_group, cluster, window),
    sun_abraham = lamp_did_sa(d, cluster, window),
    imputation = lamp_did_imputation(d, window)
  )

  diagnostics <- c(
    res$diagnostics,
    list(
      n_dropped_coverage = mf$n_dropped_coverage,
      n_cohorts = sf$n_cohorts,
      control_group = control_group,
      estimator = estimator,
      family = family
    )
  )
  contract <- mf$contract
  contract$treatment <- mf$treatment
  new_lamp_estimate(
    "lamp_did_staggered", res$coefficients,
    assumption = paste0(
      "Parallel trends by cohort against ",
      if (control_group == "never_treated") "never-treated" else "not-yet-treated",
      " areas, and no anticipation before adoption.",
      " Outcome modelled on the ", family, " scale."
    ),
    sample = mf$sample, diagnostics = diagnostics,
    meta = list(
      outcome = outcome, family = family, cluster = cluster,
      treatment_type = mf$treatment$type, backend = estimator,
      reference = -1L
    ),
    model = res$model, contract = contract, data = d
  )
}

# Callaway and Sant'Anna: group-time effects, then aggregations.
lamp_did_cs <- function(d, control_group, cluster, window) {
  cg <- if (control_group == "never_treated") "nevertreated" else "notyettreated"
  att <- rlang::try_fetch(
    did::att_gt(
      yname = ".y", tname = ".t", idname = ".id", gname = ".g",
      data = as.data.frame(d), control_group = cg, bstrap = FALSE, cband = FALSE,
      clustervars = if (cluster == "force") "force_id" else NULL,
      allow_unbalanced_panel = TRUE, base_period = "universal"
    ),
    error = function(e) {
      lamp_abort(
        c(
          "The Callaway and Sant'Anna estimator could not be fitted.",
          "i" = "Cohorts need untreated comparison areas and pre-adoption months."
        ),
        "input",
        parent = e
      )
    }
  )
  dyn <- rlang::try_fetch(
    did::aggte(att, type = "dynamic", na.rm = TRUE, min_e = window[1], max_e = window[2]),
    error = function(e) NULL
  )
  overall <- rlang::try_fetch(
    did::aggte(att, type = "simple", na.rm = TRUE),
    error = function(e) NULL
  )
  group <- rlang::try_fetch(
    did::aggte(att, type = "group", na.rm = TRUE),
    error = function(e) NULL
  )

  coefs <- if (is.null(dyn)) {
    tibble::tibble()
  } else {
    z <- stats::qnorm(0.975)
    tibble::tibble(
      term = paste0("rel_time::", dyn$egt),
      rel_time = as.integer(dyn$egt),
      estimate = dyn$att.egt,
      std_error = dyn$se.egt,
      statistic = dyn$att.egt / dyn$se.egt,
      p_value = 2 * stats::pnorm(-abs(dyn$att.egt / dyn$se.egt)),
      conf_low = dyn$att.egt - z * dyn$se.egt,
      conf_high = dyn$att.egt + z * dyn$se.egt
    )
  }
  pre <- coefs[coefs$rel_time < 0, ]
  list(
    coefficients = coefs,
    model = att,
    diagnostics = list(
      overall = if (is.null(overall)) {
        NULL
      } else {
        list(estimate = overall$overall.att, std_error = overall$overall.se)
      },
      dynamic_overall = if (is.null(dyn)) {
        NULL
      } else {
        list(estimate = dyn$overall.att, std_error = dyn$overall.se)
      },
      by_group = if (is.null(group)) {
        NULL
      } else {
        tibble::tibble(
          cohort = group$egt, estimate = group$att.egt, std_error = group$se.egt
        )
      },
      group_time = tibble::tibble(
        cohort = att$group, period = att$t, estimate = att$att, std_error = att$se
      ),
      pretrend_p = att$Wpval,
      pretrend = list(stat = att$W, p = att$Wpval, df1 = nrow(pre)),
      n_pre = sum(coefs$rel_time < 0), n_post = sum(coefs$rel_time >= 0)
    )
  )
}

# Sun and Abraham: interaction-weighted estimator in one regression.
lamp_did_sa <- function(d, cluster, window) {
  # never-treated areas take a cohort far beyond the panel, which is how
  # fixest marks them. sunab() is written unqualified on purpose: fixest
  # intercepts the call when it parses the formula rather than evaluating it,
  # and does not recognise a namespace-qualified form.
  d$.g_sa <- ifelse(d$.g == 0L, 10000L, d$.g)
  fit <- rlang::try_fetch(
    fixest::feols(
      .y ~ sunab(.g_sa, .t) | .area + .month,
      data = d, cluster = ~.cluster, notes = FALSE
    ),
    error = function(e) {
      lamp_abort("The Sun and Abraham estimator could not be fitted.", "input", parent = e)
    }
  )
  co <- lamp_coefficients(fit, keep = "^\\.t::")
  co$rel_time <- as.integer(sub("^\\.t::(-?[0-9]+).*$", "\\1", co$term))
  co <- co[co$rel_time >= window[1] & co$rel_time <= window[2], ]
  co <- co[order(co$rel_time), ]
  agg <- rlang::try_fetch(stats::aggregate(fit, "att"), error = function(e) NULL)
  pre <- co[co$rel_time < 0, ]
  pre_p <- if (nrow(pre) == 0L) NA_real_ else lamp_joint_zero_p(pre)
  list(
    coefficients = co,
    model = fit,
    diagnostics = list(
      overall = if (is.null(agg)) {
        NULL
      } else {
        list(estimate = agg[1, 1], std_error = agg[1, 2])
      },
      pretrend_p = pre_p,
      pretrend = list(stat = NA_real_, p = pre_p, df1 = nrow(pre)),
      n_pre = nrow(pre), n_post = sum(co$rel_time >= 0)
    )
  )
}

# Borusyak, Jaravel and Spiess imputation, when didimputation is installed.
lamp_did_imputation <- function(d, window) {
  if (!requireNamespace("didimputation", quietly = TRUE)) {
    lamp_abort(
      c(
        "The {.val imputation} backend needs the {.pkg didimputation} package.",
        "i" = "Install it, or use {.val callaway_santanna} or {.val sun_abraham}."
      ),
      "input"
    )
  }
  dd <- as.data.frame(d)
  dd$.g_imp <- ifelse(dd$.g == 0L, Inf, dd$.g)
  dyn <- rlang::try_fetch(
    didimputation::did_imputation(
      data = dd, yname = ".y", gname = ".g_imp", tname = ".t", idname = ".id",
      horizon = TRUE, cluster_var = ".cluster"
    ),
    error = function(e) {
      lamp_abort("The imputation estimator could not be fitted.", "input", parent = e)
    }
  )
  overall <- rlang::try_fetch(
    didimputation::did_imputation(
      data = dd, yname = ".y", gname = ".g_imp", tname = ".t", idname = ".id",
      cluster_var = ".cluster"
    ),
    error = function(e) NULL
  )
  dyn <- as.data.frame(dyn)
  z <- stats::qnorm(0.975)
  co <- tibble::tibble(
    term = paste0("rel_time::", dyn$term),
    rel_time = as.integer(dyn$term),
    estimate = dyn$estimate,
    std_error = dyn$std.error,
    statistic = dyn$estimate / dyn$std.error,
    p_value = 2 * stats::pnorm(-abs(dyn$estimate / dyn$std.error)),
    conf_low = dyn$estimate - z * dyn$std.error,
    conf_high = dyn$estimate + z * dyn$std.error
  )
  co <- co[co$rel_time >= window[1] & co$rel_time <= window[2], ]
  co <- co[order(co$rel_time), ]
  list(
    coefficients = co,
    model = NULL,
    diagnostics = list(
      overall = if (is.null(overall)) {
        NULL
      } else {
        ov <- as.data.frame(overall)
        list(estimate = ov$estimate[1], std_error = ov$std.error[1])
      },
      pretrend_p = NA_real_,
      pretrend = NULL,
      note = paste(
        "The imputation estimator uses only pre-treatment data to fit the",
        "untreated outcome, so it reports no pre-period coefficients by default."
      ),
      n_pre = sum(co$rel_time < 0), n_post = sum(co$rel_time >= 0)
    )
  )
}

# Joint test that a set of independent-ish coefficients are zero, used where a
# backend gives no covariance matrix: a chi-square on the sum of squared
# t statistics, which is conservative when they are correlated.
lamp_joint_zero_p <- function(co) {
  t2 <- sum((co$estimate / co$std_error)^2, na.rm = TRUE)
  stats::pchisq(t2, df = nrow(co), lower.tail = FALSE)
}

#' @export
print.lamp_did_staggered <- function(x, ...) {
  print.lamp_estimate(x, ...)
  ov <- x$diagnostics$overall
  if (!is.null(ov)) {
    cli::cli_text(
      "Overall effect: {signif(ov$estimate, 3)} ",
      "(standard error {signif(ov$std_error, 3)})"
    )
  }
  invisible(x)
}

#' @export
plot.lamp_did_staggered <- function(x, y = NULL, ...) {
  # The reference period is normalised to zero and carries no standard error,
  # so it has no interval; lamp_plot_dynamic() draws it hollow rather than
  # dropping it with a warning on every render.
  ov <- x$diagnostics$overall
  subtitle <- lamp_wrap_subtitle(x$assumption)
  if (!is.null(ov)) {
    subtitle <- paste0(
      sprintf(
        "Overall effect %s (standard error %s). ",
        lamp_fmt_num(ov$estimate), lamp_fmt_num(ov$std_error)
      ),
      subtitle
    )
    subtitle <- lamp_wrap_subtitle(subtitle)
  }
  lamp_plot_dynamic(
    x$coefficients,
    reference = NA,
    x_label = "Months since adoption",
    y_label = lamp_effect_label(x),
    title = sprintf(
      "Staggered difference-in-differences: %s (%s)",
      lamp_pretty_name(x$meta$outcome), lamp_backend_label(x$meta$backend)
    ),
    subtitle = subtitle
  )
}

lamp_backend_label <- function(backend) {
  known <- c(
    callaway_santanna = "Callaway and Sant'Anna",
    sun_abraham = "Sun and Abraham",
    imputation = "imputation"
  )
  ifelse(backend %in% names(known), known[backend], backend)
}

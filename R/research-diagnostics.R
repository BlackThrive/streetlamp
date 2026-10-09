#' Recover exact expected outcomes from a simulated panel
#'
#' Keeps count-level effects and log mean ratios distinct. This function
#' deliberately does not treat a log mean as the expectation of log counts.
#' @param panel A panel returned by [lamp_simulate()].
#' @param outcome `"affected_crime"` or `"crime_total"`.
#' @param scale `"identity"` for expected count differences or `"log_mean"`
#'   for log ratios of expected counts.
#' @return A tibble of area-month counterfactual means and exact effects,
#'   including cohort, relative time and observed coverage status. For
#'   spillover designs the effect includes the simulated neighbour exposure.
#' @family simulation
#' @export
#' @examples
#' sim <- lamp_simulate(seed = 1)
#' head(lamp_simulation_truth(sim))
lamp_simulation_truth <- function(panel, outcome = c("affected_crime", "crime_total"),
                                  scale = c("identity", "log_mean")) {
  lamp_check_panel(panel)
  outcome <- rlang::arg_match(outcome)
  scale <- rlang::arg_match(scale)
  d <- attr(panel, "truth")$cell_means
  if (is.null(d)) lamp_abort("This panel has no area-month simulation truth.", "input")
  key <- paste(panel$area, lamp_month_id(panel$month))
  d <- d[match(key, paste(d$area, lamp_month_id(d$month))), ]
  mu0 <- d[[paste0(outcome, "_0")]]
  mu1 <- d[[paste0(outcome, "_1")]]
  tibble::tibble(
    area = d$area, month = d$month, cohort = d$cohort, rel_time = d$rel_time,
    treated = d$treated, coverage_status = d$coverage_status,
    mean_untreated = mu0, mean_treated = mu1,
    effect = if (scale == "identity") mu1 - mu0 else log(mu1 / mu0),
    outcome = outcome, scale = scale
  )
}

#' Summarise effects using their joint covariance
#'
#' Computes a linear combination with the full covariance matrix. For
#' staggered estimates, the default is the backend's overall ATT and its
#' own weighting, rather than an equally weighted mean of dynamic estimates.
#' @param estimate A `lamp_estimate`.
#' @param terms Coefficient names; `NULL` selects all elasticity lags,
#'   post-event coefficients for an event study, or the treatment coefficient.
#' @param weights Numeric weights in the order of `terms`. Defaults to one
#'   for elasticity lags and equal averaging weights otherwise. Supplied
#'   weights are used as supplied, without normalisation.
#' @param level Confidence level between zero and one.
#' @return A one-row tibble with estimate, standard error, interval, confidence
#'   level and the aggregation definition. Unsupported joint covariance is
#'   an error, rather than an independence approximation.
#' @family diagnostics
#' @export
#' @examples
#' sim <- lamp_simulate(design = "continuous", seed = 1)
#' lamp_effect_summary(lamp_elasticity(sim, lags = 0:1))
lamp_effect_summary <- function(estimate, terms = NULL, weights = NULL, level = 0.95) {
  if (!inherits(estimate, "lamp_estimate")) lamp_abort("Expected a lamp_estimate.", "input")
  if (!is.numeric(level) || length(level) != 1L || !is.finite(level) || level <= 0 || level >= 1) {
    lamp_abort("{.arg level} must be between zero and one.", "input")
  }
  df <- estimate$diagnostics$df %||% Inf
  if (inherits(estimate$model, "fixest")) df <- lamp_inference_df(estimate$model)
  if (inherits(estimate, "lamp_did_staggered") && is.null(terms) && is.null(weights)) {
    ov <- estimate$diagnostics$overall
    if (is.null(ov)) lamp_abort("The backend has no overall ATT for this estimate.", "input")
    b <- ov$estimate
    se <- ov$std_error
    definition <- "backend overall ATT (backend cohort/time weights)"
  } else {
    co <- estimate$coefficients
    if (is.null(terms)) {
      if (inherits(estimate, "lamp_elasticity")) {
        terms <- co$term
      } else if (inherits(estimate, "lamp_event_study")) {
        terms <- co$term[co$rel_time >= 0]
      } else if (".treat" %in% co$term) {
        terms <- ".treat"
      } else if ("treat" %in% co$term) {
        terms <- "treat"
      } else {
        terms <- co$term[1]
      }
    }
    if (!is.character(terms) || !length(terms) || anyNA(terms) || anyDuplicated(terms) ||
          !all(terms %in% co$term)) {
      lamp_abort("Select distinct, available coefficient terms.", "input")
    }
    if (is.null(weights)) {
      weights <- rep(if (inherits(estimate, "lamp_elasticity")) {
        1
      } else {
        1 / length(terms)
      }, length(terms))
    }
    if (!is.numeric(weights) || length(weights) != length(terms) || any(!is.finite(weights))) {
      lamp_abort("Supply one finite numeric weight per term.", "input")
    }
    v <- estimate$diagnostics$covariance
    if (is.null(v) && inherits(estimate$model, "fixest")) v <- stats::vcov(estimate$model)
    if (!is.null(v) && "treat" %in% co$term && ".treat" %in% rownames(v)) {
      rownames(v)[rownames(v) == ".treat"] <- "treat"
      colnames(v)[colnames(v) == ".treat"] <- "treat"
    }
    if (is.null(v) || !all(terms %in% rownames(v))) {
      lamp_abort(
        "Joint covariance is unavailable for these terms; use the backend overall ATT.", "input"
      )
    }
    b <- sum(weights * co$estimate[match(terms, co$term)])
    se <- sqrt(max(0, as.numeric(crossprod(weights, v[terms, terms, drop = FALSE] %*% weights))))
    definition <- paste(paste(weights, terms, sep = " * "), collapse = " + ")
  }
  critical <- stats::qt(1 - (1 - level) / 2, df)
  tibble::tibble(
    estimate = b, std_error = se, conf_low = b - critical * se,
    conf_high = b + critical * se, level = level, definition = definition
  )
}

#' Sensitivity to a specified differential linear trend
#'
#' Adjusts an event-study average for user-specified untreated trend slopes.
#' Each slope is an assumption in the model's outcome units per month, not a
#' trend estimated and treated as known. Intervals reflect sampling uncertainty
#' conditional on each slope. This is a transparent linear bias calculation,
#' not a general robust confidence procedure or a test of parallel trends.
#' @param estimate An estimate from [lamp_event_study()].
#' @param slopes Finite numeric differential trend assumptions.
#' @param periods Post-event relative months to average; defaults to available
#'   post-event months.
#' @param reference Reference relative month; must match the fitted model.
#' @param level Confidence level.
#' @return A tibble with the assumed slope, implied bias and adjusted estimate
#'   and interval for each scenario.
#' @family diagnostics
#' @export
#' @examples
#' sim <- lamp_simulate(design = "event", seed = 1)
#' truth <- attr(sim, "truth")
#' tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
#' fit <- lamp_event_study(sim, "crime_total", tr, window = c(-4, 4))
#' lamp_trend_sensitivity(fit, c(-0.01, 0, 0.01))
lamp_trend_sensitivity <- function(estimate, slopes, periods = NULL,
                                   reference = -1L, level = 0.95) {
  if (!inherits(estimate, "lamp_event_study")) {
    lamp_abort("Use a lamp_event_study estimate.", "input")
  }
  if (!is.numeric(slopes) || !length(slopes) || any(!is.finite(slopes))) {
    lamp_abort("{.arg slopes} must contain finite numeric trend assumptions.", "input")
  }
  fitted_reference <- estimate$meta$reference %||% estimate$diagnostics$reference %||% -1L
  if (length(reference) != 1L || is.na(reference) || reference != fitted_reference) {
    lamp_abort("{.arg reference} must match the fitted event-study reference.", "input")
  }
  co <- estimate$coefficients
  if (is.null(periods)) periods <- co$rel_time[co$rel_time >= 0]
  if (!is.numeric(periods) || !length(periods) || anyNA(periods) || anyDuplicated(periods) ||
        any(periods < 0) || !all(periods %in% co$rel_time)) {
    lamp_abort("Select distinct, available post-event periods.", "input")
  }
  terms <- co$term[match(periods, co$rel_time)]
  summary <- lamp_effect_summary(estimate, terms = terms, level = level)
  bias <- slopes * mean(periods - reference)
  tibble::tibble(
    slope = slopes, bias = bias, estimate = summary$estimate - bias,
    std_error = summary$std_error, conf_low = summary$conf_low - bias,
    conf_high = summary$conf_high - bias, level = level
  )
}

#' Audit the support and assumptions of an intervention design
#'
#' Reports missing submissions, pre/post support and detection-sensitive
#' outcomes. A clean data audit does not establish causal identification;
#' intervention assignment, contemporaneous changes and spillovers still
#' require substantive evidence.
#' @param panel A `lamp_panel`.
#' @param treatment Optional dated [lamp_treatment()] object.
#' @param outcomes Outcome columns under consideration.
#' @param min_pre,min_post Minimum observed months per treated area before
#'   and after adoption for the support audit.
#' @return A list with `issues` (check, status, detail), `area_support`, and
#'   `summary`. Statuses describe data support or required arguments, not
#'   certification of causality.
#' @family diagnostics
#' @export
#' @examples
#' sim <- lamp_simulate(design = "event", seed = 1)
#' lamp_design_audit(sim)
lamp_design_audit <- function(panel, treatment = NULL, outcomes = "crime_total",
                              min_pre = 6L, min_post = 6L) {
  contract <- lamp_check_panel(panel)
  if (!is.character(outcomes) || !length(outcomes) || anyNA(outcomes) ||
        !all(outcomes %in% names(panel))) {
    lamp_abort("Name available outcome columns.", "input")
  }
  for (x in list(min_pre, min_post)) {
    if (!is.numeric(x) || length(x) != 1L || !is.finite(x) || x < 1 || x != round(x)) {
      lamp_abort("Support thresholds must be positive whole months.", "input")
    }
  }
  available <- if ("coverage_status" %in% names(panel)) {
    panel$coverage_status %in% lamp_filled_statuses()
  } else {
    rep(TRUE, nrow(panel))
  }
  available <- available & stats::complete.cases(panel[, outcomes, drop = FALSE])
  n_missing <- sum(!available)
  issues <- list(tibble::tibble(
    check = "observed outcomes and submissions",
    status = if (n_missing) "concern" else "supported",
    detail = sprintf(
      "%d of %d area-months unavailable; missing submissions are not zeros.", n_missing, nrow(panel)
    )
  ))
  issues[[2]] <- tibble::tibble(
    check = "intervention assignment", status = "requires_argument",
    detail = "Document assignment, comparison areas, concurrent policies and spillovers."
  )
  if ("stops" %in% names(panel)) {
    missing_stops <- sum(is.na(panel$stops))
    issues[[length(issues) + 1L]] <- tibble::tibble(
      check = "observed stop intensity",
      status = if (missing_stops) "concern" else "supported",
      detail = sprintf(
        "%d area-month stop counts unavailable; check exposure coverage separately.", missing_stops
      )
    )
  }
  cov <- contract$coverage
  if (!is.null(cov) && all(c("file_type", "status") %in% names(cov))) {
    missing_files <- sum(cov$file_type %in% c("street", "stop-and-search") &
                           !cov$status %in% lamp_filled_statuses())
    issues[[length(issues) + 1L]] <- tibble::tibble(
      check = "force-month source files",
      status = if (missing_files) "concern" else "supported",
      detail = sprintf(
        "%d crime/search force-month files unavailable in the source contract.", missing_files
      )
    )
  }
  detection <- intersect(outcomes, c("drugs", "possession_of_weapons", "crime_total"))
  if (length(detection)) {
    issues[[length(issues) + 1L]] <- tibble::tibble(
      check = "detection-sensitive outcomes", status = "concern",
      detail = paste(
        "Searching can change detection or recording for", paste(detection, collapse = ", "),
        "without changing underlying offending."
      )
    )
  }
  support <- tibble::tibble()
  if (!is.null(treatment)) {
    if (!inherits(treatment, "lamp_treatment")) lamp_abort("Expected a lamp_treatment.", "input")
    if (treatment$type %in% c("event", "staggered")) {
      mf <- lamp_model_frame(panel, outcomes[1], treatment)
      d <- mf$data
      # Count only rows observed for all requested outcomes.
      d <- d[stats::complete.cases(d[, outcomes, drop = FALSE]), ]
      groups <- split(d, d$area)
      support <- dplyr::bind_rows(lapply(groups, function(dd) {
        treated <- any(!is.na(dd$.cohort))
        tibble::tibble(
          area = dd$area[1], treated = treated,
          n_pre = sum(dd$.rel_time < 0, na.rm = TRUE), n_post = sum(dd$.rel_time >= 0, na.rm = TRUE)
        )
      }))
      # Areas with no observed rows must remain visible.
      absent <- setdiff(unique(panel$area), support$area)
      if (length(absent)) {
        tr_areas <- unique(treatment$data$area[!is.na(treatment$data$cohort)])
        support <- dplyr::bind_rows(support, tibble::tibble(
          area = absent, treated = absent %in% tr_areas,
          n_pre = 0L, n_post = 0L
        ))
      }
      bad <- support$treated & (support$n_pre < min_pre | support$n_post < min_post)
      # Never-treated areas have undefined relative time; count their observed rows directly.
      n_controls <- sum(!support$treated & support$area %in% d$area)
      issues[[length(issues) + 1L]] <- tibble::tibble(
        check = "treated-area pre/post support",
        status = if (any(bad)) "concern" else "supported",
        detail = sprintf(
          "%d treated areas below %d pre / %d post months; %d observed never-treated areas.",
          sum(bad), min_pre, min_post, n_controls
        )
      )
      if (!n_controls) {
        issues[[length(issues) + 1L]] <- tibble::tibble(
          check = "untreated comparisons",
          status = "concern",
          detail = "No observed never-treated areas; justify alternatives or supply controls."
        )
      }
    }
  }
  list(
    issues = dplyr::bind_rows(issues), area_support = support,
    summary = list(
      n_rows = nrow(panel), n_areas = length(unique(panel$area)),
      n_months = length(unique(panel$month)), n_unavailable = n_missing,
      source = contract$source, causal_identification = "requires substantive evidence"
    )
  )
}

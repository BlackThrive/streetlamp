# Spillovers and displacement -----------------------------------------------------------

# Neighbour-weighted treatment for each contiguity ring: ring 1 is an area's
# immediate neighbours, ring 2 the neighbours of those neighbours that are not
# already in ring 1, and so on.
lamp_ring_neighbours <- function(nb, rings) {
  n <- length(nb)
  out <- vector("list", max(rings))
  direct <- lapply(seq_len(n), function(i) {
    j <- nb[[i]]
    if (length(j) == 1L && j[1] == 0L) integer(0) else as.integer(j)
  })
  out[[1]] <- direct
  if (max(rings) >= 2L) {
    for (r in 2:max(rings)) {
      prev <- out[[r - 1L]]
      earlier <- out[seq_len(r - 1L)]
      seen <- lapply(seq_len(n), function(i) {
        unique(c(i, unlist(lapply(earlier, function(x) x[[i]]))))
      })
      out[[r]] <- lapply(seq_len(n), function(i) {
        cand <- unique(unlist(direct[prev[[i]]]))
        setdiff(cand, seen[[i]])
      })
    }
  }
  out[rings]
}

lamp_neighbour_exposure <- function(d, adjacency, rings) {
  areas <- adjacency$areas
  ring_list <- lamp_ring_neighbours(adjacency$nb, rings)
  idx <- match(d$area, areas)
  months <- sort(unique(d$month))
  out <- matrix(NA_real_, nrow = nrow(d), ncol = length(rings))
  for (m in seq_along(months)) {
    rows <- which(d$month == months[m])
    treat_by_area <- rep(NA_real_, length(areas))
    # areas absent from the adjacency have no index and contribute nothing
    placed <- rows[!is.na(idx[rows])]
    treat_by_area[idx[placed]] <- d$.treat[placed]
    for (k in seq_along(rings)) {
      nbk <- ring_list[[k]]
      vals <- vapply(idx[rows], function(i) {
        if (is.na(i)) {
          return(NA_real_)
        }
        j <- nbk[[i]]
        j <- j[!is.na(treat_by_area[j])]
        if (length(j) == 0L) 0 else mean(treat_by_area[j])
      }, numeric(1))
      out[rows, k] <- vals
    }
  }
  colnames(out) <- paste0(".neighbour_ring", rings)
  out
}

#' Own-area and neighbour effects estimated together
#'
#' Adds the treatment of an area's neighbours to the specification, so that
#' the effect on the area itself and the effect on its neighbours are
#' estimated in one model. This is what separates a reduction in crime from
#' its displacement next door: if searching an area pushes offending into the
#' surrounding areas, the own-area coefficient is negative and the neighbour
#' coefficient positive, and the net effect is their sum.
#'
#' @section Identifying assumption:
#' Parallel trends as in two-way fixed effects, and in addition that the
#' treatment reaches an area only through its own treatment and that of the
#' rings included. If spillovers extend beyond the last ring, the areas used
#' as controls are themselves affected, and every coefficient is biased
#' toward zero.
#'
#' @inheritParams lamp_twfe
#' @param adjacency A [lamp_adjacency()] object; taken from the panel's
#'   contract when not given.
#' @param rings Contiguity rings to include, default first and second order.
#'
#' @return A `lamp_estimate` of class `lamp_spillover`, whose coefficients
#'   hold the own-area effect and one neighbour effect per ring, and whose
#'   `diagnostics$net` gives the implied net effect (own plus neighbours)
#'   with a standard error from the full covariance matrix.
#' @family estimators
#' @export
#' @examples
#' sim <- lamp_simulate(
#'   n_areas = 49, n_months = 20, design = "spillover",
#'   effect = -0.3, spillover_effect = 0.15, seed = 1
#' )
#' adj <- lamp_adjacency_from_nb(attr(sim, "truth")$nb, attr(sim, "truth")$lattice$area)
#' truth <- attr(sim, "truth")
#' tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
#' fit <- lamp_spillover(sim, "crime_total", tr, adjacency = adj, rings = 1)
#' fit
lamp_spillover <- function(panel, outcome = "crime_total", treatment, adjacency = NULL,
                           rings = 1:2, cluster = c("area", "force"),
                           family = c("poisson", "negbin", "ols_log", "ols_ihs"),
                           controls = NULL) {
  cluster <- rlang::arg_match(cluster)
  family <- rlang::arg_match(family)
  if (!is.numeric(rings) || any(rings < 1) || any(rings != round(rings))) {
    lamp_abort("{.arg rings} must be positive whole numbers.", "input")
  }
  rings <- as.integer(sort(unique(rings)))
  mf <- lamp_model_frame(panel, outcome, treatment, controls, cluster)
  d <- mf$data
  adjacency <- adjacency %||% mf$contract$geography$adjacency
  if (is.null(adjacency) || !inherits(adjacency, "lamp_adjacency")) {
    lamp_abort(
      c(
        "Spillovers need adjacency.",
        "i" = "Pass {.arg adjacency} from {.fn lamp_adjacency}, or build the panel with it."
      ),
      "contract"
    )
  }
  missing_areas <- setdiff(unique(d$area), adjacency$areas)
  if (length(missing_areas) > 0L) {
    lamp_warn(
      "{length(missing_areas)} panel area{?s} {?is/are} absent from the adjacency.",
      "coverage"
    )
  }

  exposure <- lamp_neighbour_exposure(d, adjacency, rings)
  for (k in seq_along(rings)) {
    d[[colnames(exposure)[k]]] <- exposure[, k]
  }
  ring_terms <- colnames(exposure)
  keep <- stats::complete.cases(d[, ring_terms, drop = FALSE])
  d <- d[keep, ]
  mf$sample <- dplyr::bind_rows(
    mf$sample,
    tibble::tibble(
      step = "after dropping rows with no neighbour exposure",
      n_rows = nrow(d), n_areas = length(unique(d$area))
    )
  )

  rhs <- paste(c(".treat", ring_terms, controls), collapse = " + ")
  fml <- stats::as.formula(paste(lamp_response(outcome, family), "~", rhs, "| .area + .month"))
  fit <- lamp_fit(fml, d, family, cluster)

  coefs <- lamp_coefficients(fit)
  pretty <- c(".treat" = "own area", stats::setNames(paste("neighbours, ring", rings), ring_terms))
  coefs$term <- ifelse(coefs$term %in% names(pretty), pretty[coefs$term], coefs$term)

  # net effect: own plus every neighbour ring, with the full covariance
  want <- c(".treat", ring_terms)
  v <- stats::vcov(fit)
  have <- intersect(want, rownames(v))
  net <- NULL
  if (length(have) == length(want)) {
    w <- rep(1, length(want))
    est <- sum(stats::coef(fit)[want])
    se <- sqrt(as.numeric(t(w) %*% v[want, want, drop = FALSE] %*% w))
    z <- stats::qnorm(0.975)
    net <- list(
      estimate = est, std_error = se, conf_low = est - z * se, conf_high = est + z * se,
      note = paste(
        "Own-area plus neighbour effects: the change in crime across the",
        "treated area and its rings together."
      )
    )
  }
  diagnostics <- list(
    n_dropped_coverage = mf$n_dropped_coverage,
    net = net, rings = rings,
    adjacency_method = adjacency$method,
    n_areas_without_adjacency = length(missing_areas),
    dispersion = lamp_dispersion(fit, family),
    moran = lamp_residual_moran(fit, d, mf$contract)
  )
  contract <- mf$contract
  contract$treatment <- mf$treatment
  new_lamp_estimate(
    "lamp_spillover", coefs,
    assumption = paste(
      "Parallel trends, and no spillover beyond the rings included:",
      "if there is any, control areas are treated too and every coefficient",
      "is pulled toward zero."
    ),
    sample = mf$sample, diagnostics = diagnostics,
    meta = list(
      outcome = outcome, family = family, cluster = cluster,
      treatment_type = mf$treatment$type, controls = controls, rings = rings
    ),
    model = fit, contract = contract, data = d
  )
}

#' @export
print.lamp_spillover <- function(x, ...) {
  print.lamp_estimate(x, ...)
  net <- x$diagnostics$net
  if (!is.null(net)) {
    cli::cli_text(
      "Net effect (own plus neighbours): {signif(net$estimate, 3)} ",
      "[{signif(net$conf_low, 3)}, {signif(net$conf_high, 3)}]"
    )
  }
  invisible(x)
}

#' Build an adjacency object from a neighbour list
#'
#' Wraps an existing `spdep` neighbour list, for example the lattice built by
#' [lamp_simulate()], in the object the spillover estimators expect.
#'
#' @param nb An `spdep` neighbour list.
#' @param areas Area identifiers in the same order as `nb`.
#' @param method Label recorded in the object.
#'
#' @return A `lamp_adjacency` object.
#' @family panel
#' @export
#' @examples
#' sim <- lamp_simulate(n_areas = 16, n_months = 12, design = "spillover", seed = 1)
#' truth <- attr(sim, "truth")
#' lamp_adjacency_from_nb(truth$nb, truth$lattice$area)
lamp_adjacency_from_nb <- function(nb, areas, method = "supplied") {
  if (length(nb) != length(areas)) {
    lamp_abort("{.arg nb} and {.arg areas} must have the same length.", "input")
  }
  listw <- spdep::nb2listw(nb, style = "W", zero.policy = TRUE)
  structure(
    list(
      areas = as.character(areas), nb = nb, listw = listw, method = method,
      k = NA_integer_, n_islands = sum(spdep::card(nb) == 0L),
      boundary_vintage = NULL, created = Sys.time()
    ),
    class = "lamp_adjacency"
  )
}

#' Weighted displacement quotient
#'
#' Measures whether crime prevented in a treated area reappeared in the areas
#' around it. The quotient compares the change in a buffer of surrounding
#' areas with the change in control areas, relative to the change in the
#' treated areas, following Bowers and Johnson (2003).
#'
#' @details
#' The statistic is
#' `WDQ = ((B1/C1) - (B0/C0)) / ((A1/C1) - (A0/C0))`, where `A`, `B` and `C`
#' are total crime in the treated, buffer and control areas and the
#' subscripts are the pre and post periods. Read it as:
#' * negative: crime moved into the buffer, so the gain in the treated area is
#'   partly or wholly displacement;
#' * between 0 and 1: the buffer improved too, a diffusion of benefit smaller
#'   than the treated area's gain;
#' * above 1: the buffer improved more than the treated area.
#'
#' The quotient is a descriptive ratio, not a causal estimate: it assumes the
#' control areas show what would have happened everywhere, and it is unstable
#' when the treated-area change is close to zero, which the bootstrap
#' interval will show as a very wide range.
#'
#' @param panel A `lamp_panel`.
#' @param outcome The outcome column.
#' @param treated_areas,buffer_areas,control_areas Area identifiers.
#' @param pre,post Two-element vectors giving the first and last month of the
#'   before and after periods.
#' @param n_boot Bootstrap replications over areas, default 1000.
#' @param seed Random seed.
#'
#' @return A list of class `lamp_wdq` with `wdq`, `conf_low`, `conf_high`,
#'   the underlying totals, `success` (the treated area's change net of
#'   controls) and `interpretation`.
#' @family estimators
#' @references Bowers, K. J. and Johnson, S. D. (2003). Measuring the
#'   geographical displacement and diffusion of benefit effects of crime
#'   prevention activity. Journal of Quantitative Criminology 19(3), 275-301.
#' @export
#' @examples
#' sim <- lamp_simulate(
#'   n_areas = 36, n_months = 20, design = "spillover",
#'   effect = -0.4, spillover_effect = 0.2, seed = 2
#' )
#' truth <- attr(sim, "truth")
#' areas <- truth$lattice$area
#' lamp_displacement_quotient(
#'   sim, "crime_total",
#'   treated_areas = truth$treated_areas[1:6],
#'   buffer_areas = truth$treated_areas[7:12],
#'   control_areas = setdiff(areas, truth$treated_areas),
#'   pre = c("2018-01", "2018-06"), post = c("2018-12", "2019-05"), n_boot = 50
#' )
lamp_displacement_quotient <- function(panel, outcome = "crime_total", treated_areas,
                                       buffer_areas, control_areas, pre, post,
                                       n_boot = 1000, seed = NULL) {
  lamp_check_panel(panel)
  check_string(outcome)
  if (!outcome %in% names(panel)) {
    lamp_abort("{.arg outcome} must name a panel column.", "input")
  }
  sets <- list(treated = treated_areas, buffer = buffer_areas, control = control_areas)
  for (nm in names(sets)) {
    if (!is.character(sets[[nm]]) || length(sets[[nm]]) == 0L) {
      lamp_abort("{.arg {nm}_areas} must name at least one area.", "input")
    }
  }
  overlaps <- length(intersect(treated_areas, buffer_areas)) > 0L ||
    length(intersect(treated_areas, control_areas)) > 0L ||
    length(intersect(buffer_areas, control_areas)) > 0L
  if (overlaps) {
    lamp_abort("The treated, buffer and control sets must not overlap.", "input")
  }
  pre <- lamp_as_months(pre)
  post <- lamp_as_months(post)
  if (length(pre) != 2L || length(post) != 2L) {
    lamp_abort("{.arg pre} and {.arg post} must each give a first and last month.", "input")
  }
  if (!is.null(seed)) {
    withr::local_seed(seed)
  }

  d <- tibble::as_tibble(panel)
  if ("coverage_status" %in% names(d)) {
    d <- d[d$coverage_status %in% lamp_filled_statuses(), ]
  }
  d <- d[!is.na(d[[outcome]]), ]
  d$.period <- ifelse(
    d$month >= pre[1] & d$month <= pre[2], "pre",
    ifelse(d$month >= post[1] & d$month <= post[2], "post", NA_character_)
  )
  d <- d[!is.na(d$.period), ]
  d$.set <- ifelse(
    d$area %in% treated_areas, "treated",
    ifelse(d$area %in% buffer_areas, "buffer",
      ifelse(d$area %in% control_areas, "control", NA_character_)
    )
  )
  d <- d[!is.na(d$.set), ]
  if (nrow(d) == 0L) {
    lamp_abort("No rows fall inside the chosen areas and periods.", "input")
  }

  totals <- function(dat) {
    s <- tapply(dat[[outcome]], list(dat$.set, dat$.period), sum, na.rm = TRUE)
    get <- function(set, period) {
      v <- tryCatch(s[set, period], error = function(e) NA_real_)
      if (is.null(v) || length(v) == 0L || is.na(v)) NA_real_ else as.numeric(v)
    }
    list(
      a0 = get("treated", "pre"), a1 = get("treated", "post"),
      b0 = get("buffer", "pre"), b1 = get("buffer", "post"),
      c0 = get("control", "pre"), c1 = get("control", "post")
    )
  }
  wdq_of <- function(t) {
    if (any(vapply(t, is.na, logical(1))) || t$c0 == 0 || t$c1 == 0) {
      return(NA_real_)
    }
    success <- (t$a1 / t$c1) - (t$a0 / t$c0)
    if (success == 0) {
      return(NA_real_)
    }
    (((t$b1 / t$c1) - (t$b0 / t$c0))) / success
  }
  tot <- totals(d)
  wdq <- wdq_of(tot)
  success <- (tot$a1 / tot$c1) - (tot$a0 / tot$c0)

  boot <- rep(NA_real_, n_boot)
  areas_by_set <- split(unique(d[, c("area", ".set")])$area, unique(d[, c("area", ".set")])$.set)
  for (i in seq_len(n_boot)) {
    picked <- unlist(lapply(areas_by_set, function(a) sample(a, length(a), replace = TRUE)))
    dd <- d[unlist(lapply(picked, function(a) which(d$area == a))), ]
    boot[i] <- wdq_of(totals(dd))
  }
  ok <- boot[is.finite(boot)]
  ci <- if (length(ok) > 10L) {
    stats::quantile(ok, c(0.025, 0.975), names = FALSE)
  } else {
    c(NA_real_, NA_real_)
  }

  interpretation <- if (is.na(wdq)) {
    paste(
      "The quotient could not be computed: the treated area's change net of",
      "controls is zero, or a total is missing."
    )
  } else if (wdq < 0) {
    sprintf(
      paste(
        "WDQ %.2f is negative: crime rose in the buffer as it fell in the",
        "treated areas, which is what displacement looks like."
      ),
      wdq
    )
  } else if (wdq < 1) {
    sprintf(
      paste(
        "WDQ %.2f lies between 0 and 1: the buffer improved as well, by less",
        "than the treated areas, a diffusion of benefit."
      ),
      wdq
    )
  } else {
    sprintf(
      paste(
        "WDQ %.2f is above 1: the buffer improved more than the treated areas,",
        "which is hard to attribute to the intervention."
      ),
      wdq
    )
  }
  structure(
    list(
      wdq = wdq, conf_low = ci[1], conf_high = ci[2], success = success,
      totals = tot, n_boot = n_boot, n_valid_boot = length(ok),
      outcome = outcome, pre = pre, post = post,
      n_areas = vapply(areas_by_set, length, integer(1)),
      interpretation = interpretation
    ),
    class = "lamp_wdq"
  )
}

#' @export
print.lamp_wdq <- function(x, ...) {
  cli::cli_h3("Weighted displacement quotient")
  cli::cli_text("Outcome: {.field {x$outcome}}")
  cli::cli_text(
    "WDQ: {signif(x$wdq, 3)} [{signif(x$conf_low, 3)}, {signif(x$conf_high, 3)}] ",
    "from {x$n_valid_boot} of {x$n_boot} bootstrap draws"
  )
  cli::cli_text("Treated-area change net of controls: {signif(x$success, 4)}")
  cli::cli_text(x$interpretation)
  invisible(x)
}

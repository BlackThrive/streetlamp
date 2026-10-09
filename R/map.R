# Maps. The package has carried boundaries and adjacency since M2 and never
# drew either, so the one thing a reader of a crime panel most expects to see
# has been missing. These draw it, in the projection the geography arrives in
# and with the same palette as every other figure.
#
# The rule that governs the rest of the package governs these too: a
# force-month with no file is not a zero. An area with no usable data is drawn
# in the missing colour with its own legend entry, never shaded as though it
# were quiet, and the caption says how many areas that covers.

#' Map a panel column, an area-level estimate or a synthetic control's donors
#'
#' Draws a choropleth of the areas in a panel. The geometry comes from
#' [lamp_boundaries()] or [lamp_sample_boundaries()]; the fill comes from a
#' panel column, from the per-area slopes of a mean-group elasticity, or from
#' the donor weights of a synthetic control.
#'
#' @section Missing is not zero:
#' An area whose value cannot be computed, because every month of it was a
#' force-month with no file or because it is absent from the panel, is filled
#' with the `missing` colour from [lamp_colours()] and given its own legend
#' entry. It is never shaded as a low value. The caption counts those areas,
#' and counts areas present in one of the panel and the boundaries but not the
#' other, so that a map with a hole in it says why.
#'
#' @param x A `lamp_panel`, a `lamp_elasticity` fitted with
#'   `method = "cce_mg"`, or a `lamp_synth` fit.
#' @param ... Passed to the method.
#'
#' @return A `ggplot`.
#' @family presentation
#' @export
#' @examples
#' panel <- lamp_sample_panel()
#' boundaries <- lamp_sample_boundaries()
#' # one local authority, so that the example draws quickly; a whole force is
#' # a few seconds and a national panel a few minutes
#' leeds <- boundaries$area[grepl("^Leeds", boundaries$name)]
#' lamp_map(panel[panel$area %in% leeds, ], "stop_rate", boundaries)
lamp_map <- function(x, ...) {
  UseMethod("lamp_map")
}

#' @rdname lamp_map
#' @param column The panel column to map.
#' @param boundaries An `sf` object with an `area` column, from
#'   [lamp_boundaries()] or [lamp_sample_boundaries()].
#' @param month A single month to map, as a date or `"YYYY-MM"`. `NULL`, the
#'   default, aggregates every month in the panel.
#' @param statistic How to combine months when `month` is `NULL`: the area's
#'   `"mean"` per month, its `"total"` over the period, or `"rate"`, the total
#'   per `per` residents per month.
#' @param per Denominator for `statistic = "rate"`.
#' @param border Colour for area borders, or `NA` for none. At lower-layer
#'   geography the borders swamp the fill, so the default is none.
#' @param extent `"panel"`, the default, draws only the areas the data covers.
#'   `"all"` keeps every boundary supplied, and the caption then counts the
#'   areas outside the panel separately from those whose data is missing.
#' @export
lamp_map.lamp_panel <- function(x, column = "crime_total", boundaries,
                                month = NULL,
                                statistic = c("mean", "total", "rate"),
                                per = 1000, border = NA,
                                extent = c("panel", "all"), ...) {
  extent <- rlang::arg_match(extent)
  statistic <- rlang::arg_match(statistic)
  lamp_check_boundaries(boundaries)
  if (!is.character(column) || length(column) != 1L || !column %in% names(x)) {
    lamp_abort(
      c(
        "{.arg column} must name a panel column.",
        "i" = "{.val {column}} is not one of them."
      ),
      "input"
    )
  }

  d <- tibble::as_tibble(x)
  if (!is.null(month)) {
    want <- lamp_as_months(month)
    if (length(want) != 1L) {
      lamp_abort("{.arg month} must be a single month.", "input")
    }
    d <- d[d$month == want, ]
    if (nrow(d) == 0L) {
      lamp_abort(
        "No panel rows fall in {.val {lamp_month_id(want)}}.", "input"
      )
    }
  }

  # a force-month with no file contributes nothing, rather than a zero
  if ("coverage_status" %in% names(d)) {
    d[[column]][!d$coverage_status %in% lamp_filled_statuses()] <- NA
  }
  value <- lamp_map_values(d, column, statistic, per)

  label <- lamp_pretty_name(column)
  legend <- switch(statistic,
    mean = if (is.null(month)) sprintf("%s, monthly mean", label) else label,
    total = sprintf("%s, period total", label),
    rate = sprintf("%s per %s residents a month", label, lamp_label_number(per))
  )
  when <- if (!is.null(month)) {
    lamp_month_id(lamp_as_months(month))
  } else {
    months <- sort(unique(d$month))
    sprintf(
      "%s to %s", lamp_month_id(months[1]), lamp_month_id(months[length(months)])
    )
  }

  lamp_draw_map(
    boundaries, value,
    legend = legend, title = label, subtitle = when,
    centre_zero = FALSE, border = border, extent = extent
  )
}

#' @rdname lamp_map
#' @export
lamp_map.lamp_elasticity <- function(x, boundaries, border = NA,
                                     extent = c("panel", "all"), ...) {
  extent <- rlang::arg_match(extent)
  lamp_check_boundaries(boundaries)
  areas <- x$diagnostics$area_coefficients
  if (is.null(areas) || nrow(areas) == 0L) {
    lamp_abort(
      c(
        "This elasticity has no per-area coefficients to map.",
        "i" = paste(
          "Only the mean group estimator fits an area at a time. Refit with",
          "{.code method = \"cce_mg\"}."
        )
      ),
      "input"
    )
  }
  slope <- setdiff(names(areas), c("area", "n_months"))[1]
  value <- stats::setNames(areas[[slope]], areas$area)
  lamp_draw_map(
    boundaries, value,
    legend = "Elasticity to stops",
    title = sprintf("Elasticity of %s to stops", lamp_pretty_name(x$meta$outcome)),
    subtitle = paste(
      "Mean group estimator, one regression per area.",
      "An association, not an effect; see lamp_allocation()."
    ),
    centre_zero = TRUE, border = border, extent = extent
  )
}

#' @rdname lamp_map
#' @export
lamp_map.lamp_synth <- function(x, boundaries, border = NA,
                                extent = c("panel", "all"), ...) {
  extent <- rlang::arg_match(extent)
  lamp_check_boundaries(boundaries)
  w <- x$weights
  w <- w[w > 0]
  value <- stats::setNames(as.numeric(w), names(w))
  lamp_draw_map(
    boundaries, value,
    legend = "Donor weight",
    title = sprintf("What stands in for %s", x$treated_unit),
    subtitle = paste0(
      length(value), " of ", length(x$weights),
      " donors carry weight; the rest are zero"
    ),
    centre_zero = FALSE, border = border, extent = extent
  )
}

#' @rdname lamp_map
#' @export
lamp_map.lamp_estimate <- function(x, ...) {
  lamp_abort(
    c(
      paste(
        "{.cls {class(x)[1]}} estimates one effect for the whole sample, so",
        "there is nothing to map by area."
      ),
      "i" = paste(
        "{.fn lamp_elasticity} with {.code method = \"cce_mg\"} fits an area at",
        "a time, and {.fn lamp_synth} weights donors; both have",
        "{.fn lamp_map} methods."
      ),
      "i" = "For a map of the data behind this estimate, pass the panel instead."
    ),
    "input"
  )
}

# Helpers ------------------------------------------------------------------------------

lamp_check_boundaries <- function(boundaries, call = rlang::caller_env()) {
  if (missing(boundaries) || !inherits(boundaries, "sf")) {
    lamp_abort(
      c(
        "{.arg boundaries} must be an {.cls sf} object.",
        "i" = "{.fn lamp_boundaries} fetches them; {.fn lamp_sample_boundaries} is bundled."
      ),
      "input",
      call = call
    )
  }
  if (!"area" %in% names(boundaries)) {
    lamp_abort(
      "{.arg boundaries} must have an {.field area} column to join on.",
      "input",
      call = call
    )
  }
  invisible(boundaries)
}

# One number per area, with NA where there is nothing to average.
lamp_map_values <- function(d, column, statistic, per) {
  v <- d[[column]]
  by <- d$area
  if (statistic == "rate") {
    if (!"population" %in% names(d)) {
      lamp_abort(
        c(
          "{.code statistic = \"rate\"} needs a {.field population} column.",
          "i" = "Build the panel with {.arg population} to get one."
        ),
        "input"
      )
    }
    total <- tapply(v, by, sum, na.rm = TRUE)
    months <- tapply(!is.na(v), by, sum)
    pop <- tapply(d$population, by, function(z) stats::median(z, na.rm = TRUE))
    out <- per * total / (pop * months)
    out[!is.finite(out) | months == 0L] <- NA_real_
    return(out)
  }
  fun <- if (statistic == "mean") mean else sum
  out <- tapply(v, by, function(z) {
    if (all(is.na(z))) NA_real_ else fun(z, na.rm = TRUE)
  })
  out
}

# Sequential and diverging scales from the package palette, so that a map
# belongs to the same family as the rest of the figures.
lamp_fill_scale <- function(values, legend, centre_zero) {
  col <- lamp_colours()
  if (centre_zero || (any(values < 0, na.rm = TRUE) && any(values > 0, na.rm = TRUE))) {
    limit <- max(abs(values), na.rm = TRUE)
    return(ggplot2::scale_fill_gradient2(
      name = legend,
      low = col[["contrast"]], mid = col[["shade"]], high = col[["series"]],
      midpoint = 0, limits = c(-limit, limit),
      labels = lamp_label_number, na.value = col[["neutral"]]
    ))
  }
  ggplot2::scale_fill_gradient(
    name = legend,
    low = col[["shade"]], high = col[["series"]],
    labels = lamp_label_number, na.value = col[["neutral"]]
  )
}

lamp_draw_map <- function(boundaries, value, legend, title, subtitle,
                          centre_zero, border, extent = "panel") {
  col <- lamp_colours()
  g <- boundaries
  # An area the panel never covered is a different thing from an area whose
  # files were missing, and reporting them together would be a lie about
  # coverage. By default the map is drawn over the areas the data speaks to;
  # `extent = "all"` keeps every boundary, and then the two are counted apart.
  outside <- !g$area %in% names(value)
  n_outside <- sum(outside)
  if (identical(extent, "panel")) {
    g <- g[!outside, , drop = FALSE]
  }
  g$.value <- unname(value[match(g$area, names(value))])

  n_no_value <- sum(is.na(g$.value) & g$area %in% names(value))
  only_in_data <- setdiff(names(value), boundaries$area)
  caption <- character()
  if (n_no_value > 0L) {
    caption <- c(caption, sprintf(
      "%s of %s areas have no usable data: drawn as missing, not as zero",
      lamp_label_number(n_no_value), lamp_label_number(length(value))
    ))
  }
  if (identical(extent, "all") && n_outside > 0L) {
    caption <- c(caption, sprintf(
      "%s area%s lie outside the panel and carry no value",
      lamp_label_number(n_outside), if (n_outside == 1L) "" else "s"
    ))
  }
  if (length(only_in_data) > 0L) {
    caption <- c(caption, sprintf(
      "%s area%s in the data have no boundary and cannot be drawn",
      lamp_label_number(length(only_in_data)),
      if (length(only_in_data) == 1L) "" else "s"
    ))
  }

  p <- ggplot2::ggplot(g) +
    ggplot2::geom_sf(
      ggplot2::aes(fill = .data$.value),
      colour = border, linewidth = if (is.na(border)) 0 else 0.1
    ) +
    lamp_fill_scale(g$.value, legend, centre_zero) +
    ggplot2::coord_sf(datum = NA, expand = FALSE) +
    ggplot2::labs(
      title = title,
      subtitle = lamp_wrap_subtitle(subtitle),
      caption = if (length(caption)) paste(caption, collapse = "; ")
    ) +
    lamp_theme() +
    ggplot2::theme(
      axis.title = ggplot2::element_blank(),
      axis.text = ggplot2::element_blank(),
      panel.grid = ggplot2::element_blank(),
      legend.position = "right",
      legend.justification = c(0, 1),
      legend.key.height = grid::unit(28, "pt"),
      legend.key.width = grid::unit(10, "pt")
    )
  if (n_no_value > 0L) {
    # the missing fill comes from na.value, which no legend reports, so it is
    # named here instead
    p <- p + ggplot2::guides(fill = ggplot2::guide_colourbar(order = 1))
  }
  p
}

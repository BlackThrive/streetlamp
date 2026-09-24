# The visual system shared by every plot the package draws: one palette, one
# theme, and the small helpers that turn column names, force identifiers and
# model terms into labels a reader would use.

#' The colours streetlamp draws with
#'
#' A named vector of the colours every `plot()` method in the package uses,
#' so that figures drawn outside the package can match them. The series
#' colours were chosen and checked as a set for separation under the common
#' forms of colour vision deficiency; the coverage statuses are drawn from
#' the same set so that a status never impersonates a series.
#'
#' @return A named character vector of hex colours. `series` is the main data
#'   colour, `contrast` the second series where a plot has two, `accent` the
#'   colour for the one mark the reader is meant to compare against (the
#'   actual estimate in a placebo distribution), and `neutral` the fill for
#'   marks that carry no identity. The `ink`, `secondary`, `muted`, `grid`,
#'   `baseline`, `surface` and `shade` entries are the text and chrome
#'   colours. The remaining entries are named for coverage statuses.
#' @family presentation
#' @export
#' @examples
#' lamp_colours()[c("series", "contrast", "accent")]
lamp_colours <- function() {
  c(
    series = "#2a78d6",
    contrast = "#eb6834",
    accent = "#d03b3b",
    neutral = "#c3c2b7",
    ink = "#0b0b0b",
    secondary = "#52514e",
    muted = "#898781",
    grid = "#e1e0d9",
    baseline = "#c3c2b7",
    surface = "#fcfcfb",
    shade = "#f1f0ec",
    submitted = "#2a78d6",
    refreshed = "#1baf7a",
    partial_suspected = "#eda100",
    not_read = "#c3c2b7",
    missing = "#d03b3b"
  )
}

#' The ggplot2 theme streetlamp plots use
#'
#' A quiet theme built on [ggplot2::theme_minimal()]: recessive hairline
#' grid, no minor grid or tick marks, left-aligned titles, muted axis text,
#' and the legend above the plot. Every `plot()` method in the package
#' applies it, and it can be added to any other ggplot.
#'
#' @param base_size Base font size in points.
#' @return A ggplot2 theme object.
#' @family presentation
#' @export
#' @examples
#' library(ggplot2)
#' ggplot(mtcars, aes(wt, mpg)) +
#'   geom_point(colour = lamp_colours()[["series"]]) +
#'   labs(title = "Weight and fuel economy") +
#'   lamp_theme()
lamp_theme <- function(base_size = 11) {
  col <- lamp_colours()
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      text = ggplot2::element_text(colour = col[["ink"]]),
      plot.background = ggplot2::element_rect(fill = col[["surface"]], colour = NA),
      panel.background = ggplot2::element_rect(fill = col[["surface"]], colour = NA),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = col[["grid"]], linewidth = 0.3),
      axis.ticks = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(colour = col[["muted"]], size = ggplot2::rel(0.85)),
      axis.title = ggplot2::element_text(colour = col[["secondary"]], size = ggplot2::rel(0.9)),
      axis.title.x = ggplot2::element_text(margin = ggplot2::margin(t = 8), hjust = 0),
      axis.title.y = ggplot2::element_text(margin = ggplot2::margin(r = 8), hjust = 1),
      plot.title = ggplot2::element_text(
        colour = col[["ink"]], face = "bold", size = ggplot2::rel(1.2),
        margin = ggplot2::margin(b = 4)
      ),
      plot.subtitle = ggplot2::element_text(
        colour = col[["secondary"]], size = ggplot2::rel(0.95),
        margin = ggplot2::margin(b = 12), lineheight = 1.1
      ),
      plot.caption = ggplot2::element_text(
        colour = col[["muted"]], size = ggplot2::rel(0.8), hjust = 0,
        margin = ggplot2::margin(t = 10)
      ),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      strip.text = ggplot2::element_text(
        colour = col[["secondary"]], face = "bold", hjust = 0, size = ggplot2::rel(0.9),
        margin = ggplot2::margin(b = 6)
      ),
      legend.position = "top",
      legend.justification = c(0, 1),
      legend.location = "plot",
      legend.title = ggplot2::element_text(colour = col[["secondary"]], size = ggplot2::rel(0.85)),
      legend.text = ggplot2::element_text(colour = col[["secondary"]], size = ggplot2::rel(0.85)),
      legend.key.size = grid::unit(10, "pt"),
      legend.margin = ggplot2::margin(0, 0, 6, 0),
      panel.spacing = grid::unit(16, "pt"),
      plot.margin = ggplot2::margin(12, 18, 10, 12)
    )
}

# Labels ------------------------------------------------------------------------------

# "crime_total" -> "Crime total"; "violence_and_sexual_offences" -> "Violence
# and sexual offences"; "stop-and-search" -> "Stop and search".
lamp_pretty_name <- function(x) {
  x <- gsub("[_-]+", " ", x)
  paste0(toupper(substr(x, 1, 1)), substr(x, 2, nchar(x)))
}

# A force identifier as the reader knows it: the published name with its
# organisational suffix removed, falling back to the identifier in words.
lamp_force_label <- function(force_id) {
  forces <- rlang::try_fetch(lamp_forces(), error = function(e) NULL)
  out <- lamp_pretty_name(force_id)
  if (!is.null(forces)) {
    hit <- match(force_id, forces$force_id)
    name <- forces$name[hit]
    name <- sub(" (Police Service|Constabulary|Police)$", "", name)
    out <- ifelse(is.na(name), out, name)
  }
  out
}

# The file types as the coverage audit names them.
lamp_file_type_label <- function(x) {
  known <- c(
    street = "Street crime files",
    outcomes = "Outcome files",
    `stop-and-search` = "Stop and search files"
  )
  ifelse(x %in% names(known), known[x], lamp_pretty_name(x))
}

lamp_status_levels <- function() {
  c("submitted", "refreshed", "partial_suspected", "not_read", "missing")
}

lamp_status_label <- function(x) {
  known <- c(
    submitted = "Submitted",
    refreshed = "Refreshed",
    partial_suspected = "Partial (suspected)",
    not_read = "Not read",
    missing = "Missing"
  )
  ifelse(x %in% names(known), known[x], lamp_pretty_name(x))
}

# Model terms as a reader would name them. Anything the package did not
# generate is returned unchanged.
lamp_pretty_term <- function(term) {
  out <- term
  out[term == "treat"] <- "Treated \u00d7 after"
  lag <- grepl("^\\.log_s_lag[0-9]+$", term)
  out[lag] <- paste("Log stops, lag", sub("^\\.log_s_lag", "", term[lag]))
  out <- sub("^own area$", "Own area", out)
  out <- sub("^neighbours, ring ([0-9]+)$", "Neighbours, ring \\1", out)
  out
}

# What the y axis of an effect plot measures, by outcome family.
lamp_effect_label <- function(x) {
  outcome <- lamp_pretty_name(x$meta$outcome)
  if (identical(x$meta$treatment_type, "continuous")) {
    return(sprintf("Elasticity of %s to stops", tolower(outcome)))
  }
  family <- x$meta$family %||% "poisson"
  if (identical(family, "identity")) {
    sprintf("Effect on %s", tolower(outcome))
  } else {
    sprintf("Effect on %s (log points)", tolower(outcome))
  }
}

# Axis labels with thousands separators and no scientific notation.
lamp_label_number <- function(x) {
  out <- format(x, big.mark = ",", scientific = FALSE, trim = TRUE, drop0trailing = TRUE)
  out[is.na(x)] <- ""
  out
}

# Whole-number breaks for a relative-time axis.
lamp_integer_breaks <- function(limits) {
  lo <- ceiling(limits[1])
  hi <- floor(limits[2])
  span <- hi - lo
  by <- if (span <= 12) 1L else if (span <= 30) 3L else 6L
  # multiples of the step, anchored at zero, so that the event month is a break
  seq(ceiling(lo / by) * by, floor(hi / by) * by, by = by)
}

# Wrap a long assumption so that it fits under a plot title instead of
# running off the right edge of the panel.
lamp_wrap_subtitle <- function(x, width = 90L) {
  paste(strwrap(x, width = width), collapse = "\n")
}

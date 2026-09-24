# Reporting ---------------------------------------------------------------------------

#' Build a report on a panel and the estimates made from it
#'
#' Renders a document that puts a set of estimates next to the things that
#' decide whether they mean anything: the coverage of the panel they came
#' from, the identifying assumption of each estimator, the pre-trend and
#' placebo diagnostics, and the allocation model. The report is deliberately
#' hard to read as a simple verdict, because the underlying question does not
#' have one.
#'
#' @param panel A `lamp_panel`.
#' @param estimates A named list of `lamp_estimate` objects, or a single
#'   estimate. Names become section headings.
#' @param file Output file. The extension decides the format: `.html` or
#'   `.md`. `NULL` writes an HTML file to a temporary location.
#' @param title Report title.
#' @param diagnostics Include the pre-trend and placebo sections where the
#'   estimates support them.
#' @param figures Draw each estimate's `plot()` as a PNG into a `_figures`
#'   directory beside the report and include it. `NULL`, the default, draws
#'   figures for an HTML report (where they are also embedded in the page, so
#'   the file stands alone) and not for a Markdown one. A figure that cannot
#'   be drawn is skipped, never an error.
#' @param quiet Suppress rendering output.
#'
#' @return The path to the written file, invisibly.
#' @family reporting
#' @export
#' @examples
#' sim <- lamp_simulate(n_areas = 20, n_months = 20, design = "event", seed = 1)
#' truth <- attr(sim, "truth")
#' tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
#' out <- lamp_report(
#'   sim,
#'   list("Two-way fixed effects" = lamp_twfe(sim, "crime_total", tr)),
#'   file = tempfile(fileext = ".md"), quiet = TRUE
#' )
#' file.exists(out)
lamp_report <- function(panel, estimates, file = NULL, title = "streetlamp report",
                        diagnostics = TRUE, figures = NULL, quiet = FALSE) {
  lamp_check_panel(panel)
  check_string(title)
  check_bool(diagnostics)
  check_bool(quiet)
  if (inherits(estimates, "lamp_estimate")) {
    estimates <- list(estimates)
  }
  if (!is.list(estimates) || length(estimates) == 0L) {
    lamp_abort("{.arg estimates} must be a {.cls lamp_estimate} or a list of them.", "input")
  }
  bad <- !vapply(estimates, inherits, logical(1), "lamp_estimate")
  if (any(bad)) {
    lamp_abort("Element{?s} {which(bad)} of {.arg estimates} {?is/are} not estimates.", "input")
  }
  if (is.null(names(estimates))) {
    names(estimates) <- vapply(estimates, function(e) e$estimator, character(1))
  }
  file <- file %||% tempfile(fileext = ".html")
  fmt <- tolower(tools::file_ext(file))
  if (!fmt %in% c("html", "md")) {
    lamp_abort("{.arg file} must end in {.val .html} or {.val .md}.", "input")
  }

  figures <- figures %||% (fmt == "html")
  check_bool(figures)
  figure_dir <- NULL
  if (figures) {
    figure_dir <- lamp_report_figures(estimates, file, quiet = quiet)
  }

  md <- lamp_report_markdown(panel, estimates, title, diagnostics, figure_dir = figure_dir)
  if (fmt == "md") {
    writeLines(md, file)
    if (!quiet) lamp_inform("Report written to {.path {file}}.", class = "report")
    return(invisible(file))
  }
  if (!requireNamespace("rmarkdown", quietly = TRUE)) {
    lamp_abort(
      c(
        "An HTML report needs the {.pkg rmarkdown} package.",
        "i" = "Install it, or write a Markdown file by giving {.arg file} a {.val .md} extension."
      ),
      "input"
    )
  }
  # The rendered page carries the title in its <title>; the Markdown H1 is
  # the visible heading, so the title is not passed as a metadata block too.
  out_dir <- dirname(normalizePath(file, mustWork = FALSE))
  tmp <- file.path(out_dir, basename(tempfile(fileext = ".md")))
  writeLines(md, tmp)
  on.exit(unlink(tmp), add = TRUE)
  format <- rmarkdown::html_document(
    theme = NULL, highlight = NULL, mathjax = NULL,
    css = system.file("templates", "report.css", package = "streetlamp"),
    self_contained = TRUE,
    pandoc_args = rmarkdown::pandoc_metadata_arg("pagetitle", title)
  )
  rlang::try_fetch(
    rmarkdown::render(
      tmp,
      output_format = format, output_file = normalizePath(file, mustWork = FALSE), quiet = TRUE
    ),
    error = function(e) {
      lamp_abort(
        c(
          "The report could not be rendered to HTML.",
          "i" = "Pandoc may be unavailable; a {.val .md} file needs no renderer."
        ),
        "input",
        parent = e
      )
    }
  )
  if (!quiet) lamp_inform("Report written to {.path {file}}.", class = "report")
  invisible(file)
}

# Draw each estimate's plot into a directory beside the report and return the
# directory, or NULL when nothing could be drawn. Figures are a courtesy: a
# device that cannot open never stops the report.
lamp_report_figures <- function(estimates, file, quiet = FALSE) {
  # not "_files": rmarkdown treats a directory of that name beside the output
  # as its own intermediate and deletes it after a self-contained render
  dir <- paste0(tools::file_path_sans_ext(file), "_figures")
  dir.create(dir, showWarnings = FALSE, recursive = TRUE)
  drawn <- 0L
  for (i in seq_along(estimates)) {
    path <- file.path(dir, sprintf("estimate-%02d.png", i))
    ok <- rlang::try_fetch(
      {
        grDevices::png(path, width = 7.5, height = 4.5, units = "in", res = 150)
        on.exit(grDevices::dev.off(), add = TRUE)
        print(plot(estimates[[i]]))
        grDevices::dev.off()
        on.exit()
        TRUE
      },
      error = function(e) FALSE
    )
    if (isTRUE(ok) && file.exists(path)) drawn <- drawn + 1L else unlink(path)
  }
  if (drawn == 0L) {
    unlink(dir, recursive = TRUE)
    if (!quiet) lamp_inform("No figures could be drawn; the report is text only.", class = "report")
    return(NULL)
  }
  dir
}

lamp_report_markdown <- function(panel, estimates, title, diagnostics, figure_dir = NULL) {
  contract <- lamp_contract(panel)
  out <- c(
    sprintf("# %s", title),
    "",
    sprintf(
      "Built %s with streetlamp %s.",
      format(Sys.time(), "%Y-%m-%d %H:%M"),
      as.character(utils::packageVersion("streetlamp"))
    ),
    "",
    "## The panel",
    "",
    sprintf(
      "%s areas by %s months (%s rows), area level `%s`.",
      length(unique(panel$area)), length(unique(panel$month)), nrow(panel),
      contract$geography$area %||% "unknown"
    ),
    ""
  )

  cov <- rlang::try_fetch(lamp_coverage(panel), error = function(e) NULL)
  if (!is.null(cov)) {
    out <- c(
      out, "### Coverage", "",
      "Force-months by file type and status. A month a force did not submit is",
      "not a month with no crime, and every estimate below excludes those rows.",
      "", lamp_md_table(lamp_table(cov)), ""
    )
    n_mismatch <- sum(cov$mismatch %in% TRUE)
    if (n_mismatch > 0L) {
      out <- c(
        out,
        sprintf(
          paste(
            "%d force-month(s) have a crime file without a stop-and-search file",
            "or the reverse, which breaks the link between treatment and outcome",
            "in those months."
          ),
          n_mismatch
        ),
        ""
      )
    }
  }

  if (!is.null(contract$snapshots) && nrow(contract$snapshots) > 0L) {
    out <- c(
      out, "### Provenance", "",
      sprintf("Archive snapshots: %s.", paste(contract$snapshots$archive, collapse = ", ")),
      ""
    )
  }
  if (!is.null(contract$population)) {
    p <- contract$population
    out <- c(out, sprintf("Population: %s.", if (is.list(p)) p$source else p), "")
  }

  out <- c(out, "## Estimates", "")
  for (i in seq_along(estimates)) {
    nm <- names(estimates)[i]
    e <- estimates[[i]]
    used <- e$sample[nrow(e$sample), ]
    out <- c(
      out,
      sprintf("### %s", nm), "",
      sprintf("- Estimator: `%s`", e$estimator),
      sprintf("- Outcome: `%s`, modelled as %s", e$meta$outcome, lamp_family_label(e$meta$family)),
      sprintf("- Clustered by: %s", e$meta$cluster),
      sprintf(
        "- Sample: %s area-months in %s areas",
        lamp_label_number(used$n_rows), lamp_label_number(used$n_areas)
      ),
      sprintf("- Force-months dropped for coverage: %s", e$diagnostics$n_dropped_coverage %||% 0L),
      "",
      sprintf("**Identifying assumption.** %s", e$assumption),
      ""
    )
    figure <- if (!is.null(figure_dir)) file.path(figure_dir, sprintf("estimate-%02d.png", i))
    if (!is.null(figure) && file.exists(figure)) {
      rel <- file.path(basename(figure_dir), basename(figure))
      out <- c(out, sprintf("![%s](%s)", nm, rel), "")
    }
    out <- c(out, lamp_md_table(lamp_table(e)), "")
    ov <- e$diagnostics$overall
    if (!is.null(ov)) {
      out <- c(out, sprintf(
        "Overall effect: %s (standard error %s).",
        lamp_fmt_num(ov$estimate), lamp_fmt_num(ov$std_error)
      ), "")
    }
    net <- e$diagnostics$net
    if (!is.null(net)) {
      out <- c(out, sprintf(
        "Net effect including neighbours: %s %s.",
        lamp_fmt_num(net$estimate), lamp_fmt_interval(net$conf_low, net$conf_high)
      ), "")
    }
    if (!is.null(e$diagnostics$dispersion) && !is.na(e$diagnostics$dispersion)) {
      out <- c(out, sprintf("Dispersion: %s.", lamp_fmt_num(e$diagnostics$dispersion)), "")
    }
    m <- e$diagnostics$moran
    if (!is.null(m)) {
      out <- c(out, sprintf(
        "Moran's I of residuals: %s (p = %s). %s",
        lamp_fmt_num(m$statistic), lamp_fmt_p(m$p_value), m$note
      ), "")
    }
    if (diagnostics && inherits(e, "lamp_event_study")) {
      pt <- rlang::try_fetch(lamp_pretrends(e), error = function(err) NULL)
      if (!is.null(pt)) {
        out <- c(
          out, "**Pre-trends.**", "",
          sprintf(
            "Joint test of %s pre-period coefficients: p = %s.",
            pt$test$df, lamp_fmt_p(pt$test$p_value)
          ), ""
        )
        if (!is.null(pt$power)) {
          out <- c(out, lamp_md_table(lamp_table(pt)), "")
        }
        out <- c(out, pt$interpretation, "")
      }
    }
  }

  out <- c(
    out, "## How to read this", "",
    paste(
      "- Every estimate above rests on the assumption printed with it.",
      "None of them is established by the data."
    ),
    paste(
      "- Recorded crime is what the police wrote down. A change in recording",
      "practice moves these numbers exactly as a change in crime does."
    ),
    paste(
      "- Crime locations are snapped to anonymised points, so area assignment",
      "is approximate near boundaries."
    ),
    paste(
      "- Anti-social behaviour is excluded from crime totals: it has no crime",
      "identifier and no outcome, and is not a crime."
    ),
    paste(
      "- Police send officers where crime has risen. Unless that channel is",
      "measured and argued away, an association between searching and crime is",
      "not the effect of searching."
    ),
    ""
  )
  out
}

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
                        diagnostics = TRUE, quiet = FALSE) {
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

  md <- lamp_report_markdown(panel, estimates, title, diagnostics)
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
  tmp <- tempfile(fileext = ".md")
  writeLines(md, tmp)
  rlang::try_fetch(
    rmarkdown::render(tmp, output_file = normalizePath(file, mustWork = FALSE), quiet = TRUE),
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

lamp_report_markdown <- function(panel, estimates, title, diagnostics) {
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
    tab <- table(cov$file_type, cov$status)
    out <- c(
      out, "### Coverage", "",
      "Force-months by file type and status. A month a force did not submit is",
      "not a month with no crime, and every estimate below excludes those rows.",
      "", lamp_md_table(as.data.frame.matrix(tab), rownames_to = "file_type"), ""
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
  for (nm in names(estimates)) {
    e <- estimates[[nm]]
    used <- e$sample[nrow(e$sample), ]
    out <- c(
      out,
      sprintf("### %s", nm), "",
      sprintf("- Estimator: `%s`", e$estimator),
      sprintf("- Outcome: `%s`, modelled as %s", e$meta$outcome, lamp_family_label(e$meta$family)),
      sprintf("- Clustered by: %s", e$meta$cluster),
      sprintf("- Sample: %s area-months in %s areas", used$n_rows, used$n_areas),
      sprintf("- Force-months dropped for coverage: %s", e$diagnostics$n_dropped_coverage %||% 0L),
      "",
      sprintf("**Identifying assumption.** %s", e$assumption),
      "",
      lamp_md_table(as.data.frame(e$coefficients)),
      ""
    )
    ov <- e$diagnostics$overall
    if (!is.null(ov)) {
      out <- c(out, sprintf(
        "Overall effect: %s (standard error %s).",
        signif(ov$estimate, 3), signif(ov$std_error, 3)
      ), "")
    }
    net <- e$diagnostics$net
    if (!is.null(net)) {
      out <- c(out, sprintf(
        "Net effect including neighbours: %s [%s, %s].",
        signif(net$estimate, 3), signif(net$conf_low, 3), signif(net$conf_high, 3)
      ), "")
    }
    if (!is.null(e$diagnostics$dispersion) && !is.na(e$diagnostics$dispersion)) {
      out <- c(out, sprintf("Dispersion: %s.", signif(e$diagnostics$dispersion, 3)), "")
    }
    m <- e$diagnostics$moran
    if (!is.null(m)) {
      out <- c(out, sprintf(
        "Moran's I of residuals: %s (p = %s). %s",
        signif(m$statistic, 3), signif(m$p_value, 3), m$note
      ), "")
    }
    if (diagnostics && inherits(e, "lamp_event_study")) {
      pt <- rlang::try_fetch(lamp_pretrends(e), error = function(err) NULL)
      if (!is.null(pt)) {
        out <- c(
          out, "**Pre-trends.**", "",
          sprintf(
            "Joint test of %s pre-period coefficients: p = %s.",
            pt$test$df, signif(pt$test$p_value, 3)
          ), ""
        )
        if (!is.null(pt$power)) {
          out <- c(out, lamp_md_table(as.data.frame(pt$power)), "")
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

# A small Markdown table, so that reports need no extra package.
lamp_md_table <- function(df, rownames_to = NULL) {
  if (!is.null(rownames_to)) {
    df <- cbind(stats::setNames(data.frame(rownames(df)), rownames_to), df)
  }
  fmt <- function(x) {
    if (is.numeric(x)) {
      formatC(signif(x, 4), format = "g")
    } else {
      as.character(x)
    }
  }
  cells <- lapply(df, fmt)
  header <- paste("|", paste(names(df), collapse = " | "), "|")
  rule <- paste("|", paste(rep("---", length(df)), collapse = " | "), "|")
  rows <- vapply(seq_len(nrow(df)), function(i) {
    paste("|", paste(vapply(cells, function(col) col[i], character(1)), collapse = " | "), "|")
  }, character(1))
  c(header, rule, rows)
}

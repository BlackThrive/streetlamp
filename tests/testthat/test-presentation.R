# The theme, the palette and the presentation tables.

presentation_fixture <- function() {
  sim <- lamp_simulate(n_areas = 24, n_months = 20, design = "event", effect = -0.25, seed = 7)
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  list(sim = sim, tr = tr, fit = lamp_twfe(sim, "crime_total", tr))
}

test_that("the palette and theme are what the plots use", {
  col <- lamp_colours()
  expect_true(all(grepl("^#[0-9a-f]{6}$", col)))
  expect_true(all(c("series", "contrast", "accent", "neutral", "surface") %in% names(col)))
  expect_true(all(lamp_status_levels() %in% names(col)))
  expect_s3_class(lamp_theme(), "theme")

  f <- presentation_fixture()
  p <- plot(f$fit)
  expect_s3_class(p, "ggplot")
  # the theme is applied: no minor grid, title flush with the plot
  expect_s3_class(p$theme$panel.grid.minor, "element_blank")
  expect_equal(p$theme$plot.title.position, "plot")
})

test_that("labels are words a reader would use", {
  expect_equal(lamp_pretty_name("crime_total"), "Crime total")
  expect_equal(lamp_pretty_name("stop-and-search"), "Stop and search")
  expect_equal(
    lamp_pretty_term(c("treat", ".log_s_lag2", "own area", "x")),
    c("Treated \u00d7 after", "Log stops, lag 2", "Own area", "x")
  )
  expect_equal(
    lamp_force_label(c("west-yorkshire", "dyfed-powys", "made-up")),
    c("West Yorkshire", "Dyfed-Powys", "Made up")
  )
  expect_equal(lamp_label_number(c(1500, 20, NA)), c("1,500", "20", ""))
  expect_equal(lamp_status_label("partial_suspected"), "Partial (suspected)")
})

test_that("numbers are formatted the way a reader expects", {
  minus <- if (lamp_utf8()) "\u2212" else "-"
  expect_equal(
    lamp_fmt_num(c(-0.22641, 0.0386, 12.3456, NA)),
    c(paste0(minus, "0.226"), "0.0386", "12.3", "")
  )
  expect_equal(lamp_fmt_p(c(8.4e-65, 0.0784, 0.5, NA)), c("<0.001", "0.078", "0.500", ""))
  expect_equal(lamp_fmt_p_phrase(c(8.4e-65, 0.0784)), c("p < 0.001", "p = 0.078"))
  expect_equal(
    lamp_fmt_interval(-0.318, -0.166),
    sprintf("[%s0.318, %s0.166]", minus, minus)
  )
  expect_equal(lamp_fmt_interval(NA, 1), "")
})

test_that("lamp_table formats estimates, diagnostics and coverage", {
  f <- presentation_fixture()

  tb <- lamp_table(f$fit)
  expect_s3_class(tb, "tbl_df")
  expect_equal(names(tb), c("Term", "Estimate", "Std. error", "95% CI", "p"))
  expect_equal(tb$Term, "Treated \u00d7 after")
  expect_true(all(vapply(tb, is.character, logical(1))))
  expect_match(tb$`95% CI`, "^\\[.*, .*\\]$")

  es <- lamp_event_study(f$sim, "crime_total", f$tr, window = c(-4, 4))
  te <- lamp_table(es)
  expect_equal(names(te)[1], "Months since event")
  expect_true("-1 (reference)" %in% te[[1]])
  expect_equal(nrow(te), nrow(es$coefficients))

  pt <- lamp_table(lamp_pretrends(es))
  expect_equal(names(pt)[1], "Power")
  expect_equal(nrow(pt), 2L)

  cv <- lamp_table(lamp_coverage(f$sim))
  expect_equal(names(cv)[1], "File type")
  expect_true("Submitted" %in% names(cv))
  expect_false("Not read" %in% names(cv))

  # the console and Markdown renderings carry the same cells
  out <- capture.output(lamp_print_table(tb))
  expect_match(out[1], "Term")
  expect_match(out[3], "Treated")
  md <- lamp_md_table(tb)
  expect_match(md[2], "^\\| --- \\| ---: ")
  expect_length(md, 3L)
})

test_that("the staggered and synthetic tables work", {
  sim <- lamp_simulate(n_areas = 24, n_months = 18, design = "staggered", effect = -0.3, seed = 1)
  ad <- attr(sim, "truth")$adoption
  tr <- lamp_treatment(sim, "staggered", adoption = ad[!is.na(ad$adoption_month), ])
  fit <- suppressWarnings(lamp_did_staggered(sim, "crime_total", tr))
  tb <- lamp_table(fit)
  expect_equal(names(tb)[1], "Months since adoption")
  expect_true(any(grepl("reference", tb[[1]])))

  ev <- lamp_simulate(n_areas = 20, n_months = 30, design = "event", effect = -0.4, seed = 1)
  truth <- attr(ev, "truth")
  sc <- lamp_synth(
    ev, "crime_total",
    treated_unit = truth$treated_areas[1], treatment_start = truth$event_date,
    donors = setdiff(unique(ev$area), truth$treated_areas), placebo = FALSE
  )
  tw <- lamp_table(sc)
  expect_equal(names(tw), c("Donor", "Weight"))
  expect_gt(nrow(tw), 0L)
})

test_that("a report can carry figures beside it", {
  skip_if_not(capabilities("png"))
  f <- presentation_fixture()
  file <- withr::local_tempfile(fileext = ".md")
  lamp_report(f$sim, list("TWFE" = f$fit), file = file, figures = TRUE, quiet = TRUE)
  md <- paste(readLines(file), collapse = "\n")
  dir <- paste0(tools::file_path_sans_ext(file), "_figures")
  withr::defer(unlink(dir, recursive = TRUE))
  expect_true(file.exists(file.path(dir, "estimate-01.png")))
  expect_match(md, "estimate-01.png", fixed = TRUE)
  # and the coefficient table is the presentation table
  expect_match(md, "| Term | Estimate | Std. error | 95% CI | p |", fixed = TRUE)
})

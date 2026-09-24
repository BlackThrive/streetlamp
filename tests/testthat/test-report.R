report_fixture <- function(envir = parent.frame()) {
  sim <- lamp_simulate(n_areas = 20, n_months = 20, design = "event", effect = -0.3, seed = 1)
  truth <- attr(sim, "truth")
  tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
  list(
    panel = sim,
    twfe = lamp_twfe(sim, "crime_total", tr),
    event_study = lamp_event_study(sim, "crime_total", tr, window = c(-4, 4))
  )
}

test_that("a Markdown report contains the panel, the estimates and the caveats", {
  fx <- report_fixture()
  file <- withr::local_tempfile(fileext = ".md")
  out <- lamp_report(
    fx$panel,
    list("Two-way fixed effects" = fx$twfe, "Event study" = fx$event_study),
    file = file, quiet = TRUE
  )
  expect_equal(out, file)
  expect_true(file.exists(file))
  md <- paste(readLines(file), collapse = "\n")

  expect_match(md, "# streetlamp report", fixed = TRUE)
  expect_match(md, "## The panel", fixed = TRUE)
  expect_match(md, "### Coverage", fixed = TRUE)
  expect_match(md, "## Estimates", fixed = TRUE)
  expect_match(md, "### Two-way fixed effects", fixed = TRUE)
  expect_match(md, "### Event study", fixed = TRUE)

  # every estimate carries its identifying assumption
  expect_equal(length(gregexpr("Identifying assumption", md)[[1]]), 2L)
  expect_match(md, "Parallel trends")
  # and the count of force-months dropped for coverage
  expect_match(md, "Force-months dropped for coverage")
  # the pre-trend diagnostic appears for the event study
  expect_match(md, "Pre-trends", fixed = TRUE)
  # and the standing caveats
  expect_match(md, "## How to read this", fixed = TRUE)
  expect_match(md, "recording practice")
  expect_match(md, "Anti-social behaviour is excluded")
  expect_match(md, "where crime has risen")
})

test_that("a single estimate and unnamed lists both work", {
  fx <- report_fixture()
  file <- withr::local_tempfile(fileext = ".md")
  lamp_report(fx$panel, fx$twfe, file = file, quiet = TRUE)
  md <- paste(readLines(file), collapse = "\n")
  expect_match(md, "### lamp_twfe", fixed = TRUE)

  file2 <- withr::local_tempfile(fileext = ".md")
  lamp_report(fx$panel, list(fx$twfe, fx$event_study), file = file2, quiet = TRUE)
  md2 <- paste(readLines(file2), collapse = "\n")
  expect_match(md2, "### lamp_event_study", fixed = TRUE)
})

test_that("the report runs on the bundled sample panel without network", {
  withr::local_envvar(STREETLAMP_OFFLINE = "true")
  panel <- lamp_sample_panel()
  tr <- lamp_treatment(panel, "continuous", measure = "stop_rate", transform = "ihs")
  fit <- lamp_twfe(panel, "crime_total", tr)
  allocation <- lamp_allocation(panel, crime_lags = 1:2)
  file <- withr::local_tempfile(fileext = ".md")

  expect_message(
    lamp_report(
      panel,
      list("Stop intensity" = fit, "How searching follows crime" = allocation),
      file = file, title = "Sample panel"
    ),
    class = "streetlamp_message_report"
  )
  md <- paste(readLines(file), collapse = "\n")
  expect_match(md, "# Sample panel", fixed = TRUE)
  expect_match(md, "Archive snapshots: 2026-07", fixed = TRUE)
  expect_match(md, "NOMIS", fixed = TRUE)
  # the mismatch between crime and stop files is reported
  expect_match(md, "crime file without a stop-and-search file")
  # Moran's I appears because the sample panel carries adjacency
  expect_match(md, "Moran's I", fixed = TRUE)
})

test_that("the report validates its arguments", {
  fx <- report_fixture()
  expect_error(lamp_report(fx$panel, list()), class = "streetlamp_error_input")
  expect_error(lamp_report(fx$panel, list(fx$twfe, "nope")), class = "streetlamp_error_input")
  expect_error(lamp_report(tibble::tibble(a = 1), fx$twfe), class = "streetlamp_error_input")
  expect_error(
    lamp_report(fx$panel, fx$twfe, file = withr::local_tempfile(fileext = ".pdf")),
    class = "streetlamp_error_input"
  )
})

test_that("the Markdown table helper right-aligns every column after the first", {
  df <- data.frame(a = c("x", "y"), b = c("1.23", "2"), c = c("[1, 2]", NA), stringsAsFactors = FALSE)
  tbl <- streetlamp:::lamp_md_table(df)
  expect_length(tbl, 4L)
  expect_equal(tbl[1], "| a | b | c |")
  expect_equal(tbl[2], "| --- | ---: | ---: |")
  expect_equal(tbl[3], "| x | 1.23 | [1, 2] |")
  expect_equal(tbl[4], "| y | 2 |  |")

  # a pipe inside a cell is escaped rather than splitting the row
  piped <- streetlamp:::lamp_md_table(data.frame(a = "p|q", stringsAsFactors = FALSE))
  expect_match(piped[3], "p\\|q", fixed = TRUE)
})

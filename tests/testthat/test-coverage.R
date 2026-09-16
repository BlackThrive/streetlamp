fixture_changelog_html <- function() {
  readLines(test_path("fixtures", "changelog.html"), warn = FALSE) |>
    paste(collapse = "\n")
}

test_that("the changelog parser extracts refresh and gap entries", {
  cl <- lamp_parse_changelog(fixture_changelog_html())
  expect_s3_class(cl, "tbl_df")
  expect_named(cl, c("entry_month", "force_name", "force_id", "file_type", "action", "from", "to", "text"))

  gmp <- cl[cl$force_id %in% "greater-manchester" & cl$action %in% "not_provided", ]
  expect_equal(nrow(gmp), 1L)
  expect_equal(gmp$file_type, "street")
  expect_equal(gmp$from, as.Date("2026-07-01"))
  expect_equal(gmp$to, as.Date("2026-07-01"))
  expect_equal(gmp$entry_month, as.Date("2026-07-01"))

  wilts <- cl[cl$force_id %in% "wiltshire", ]
  expect_equal(wilts$file_type, "stop-and-search")
  expect_equal(wilts$action, "refresh")
  expect_equal(c(wilts$from, wilts$to), as.Date(c("2023-06-01", "2025-12-01")))

  btp <- cl[cl$force_id %in% "btp", ]
  all_months <- btp[is.na(btp$from), ]
  expect_equal(nrow(all_months), 1L)
  expect_equal(all_months$file_type, "street")
  multi <- btp[btp$entry_month == as.Date("2022-09-01"), ]
  expect_equal(nrow(multi), 3L)
  expect_equal(multi$from, as.Date(c("2020-09-01", "2021-01-01", "2022-01-01")))
  expect_equal(multi$to, as.Date(c("2020-12-01", "2021-12-01", "2022-07-01")))

  col <- cl[cl$force_id %in% "city-of-london", ]
  expect_equal(col$file_type, "street;outcomes")
  expect_equal(col$from, as.Date("2013-05-01"))
  notts <- cl[cl$force_id %in% "nottinghamshire", ]
  expect_equal(nrow(notts), 2L)
  expect_equal(notts$file_type, c("outcomes", "outcomes"))
  expect_equal(notts$from, as.Date(c("2012-03-01", "2012-12-01")))
  expect_equal(notts$to, as.Date(c("2012-09-01", "2013-05-01")))

  # force lines that are neither refreshes nor gaps are kept without an action;
  # lines without a force prefix are not entries
  other <- cl[is.na(cl$action), ]
  expect_true(any(grepl("Currently no crime", other$text)))
  expect_equal(unique(other$force_id), "greater-manchester")
  expect_false(any(grepl("LSOA data", cl$text)))
  expect_error(lamp_parse_changelog("<html></html>"), class = "streetlamp_error_network")
})

test_that("lamp_changelog() caches and works offline from the cache", {
  dir <- withr::local_tempdir()
  html <- fixture_changelog_html()
  cl <- with_mocked_bindings(
    lamp_changelog(dir = dir),
    lamp_http_get_text = function(url, call = NULL) html
  )
  expect_gt(nrow(cl), 5L)
  withr::local_envvar(STREETLAMP_OFFLINE = "true")
  expect_equal(nrow(lamp_changelog(dir = dir)), nrow(cl))
  expect_warning(lamp_changelog(refresh = TRUE, dir = dir), class = "streetlamp_warning_network")
  expect_error(lamp_changelog(dir = withr::local_tempdir()), class = "streetlamp_error_network")
})

synthetic_grid <- function(force, months, file_type, status = "submitted", n = 1000L) {
  tibble::tibble(
    force_id = force, month = lamp_as_months(months), file_type = file_type,
    status = status, archive = "2026-07", n_records = n, n_versions = 1L,
    versions_differ = FALSE
  )
}

test_that("partial submissions are flagged against the trailing median", {
  months <- format(seq(as.Date("2025-01-01"), by = "month", length.out = 18), "%Y-%m")
  n <- rep(1000L, 18)
  n[15] <- 100L # far below the trailing median
  n[3] <- 50L # too early: fewer than three prior months
  street <- synthetic_grid("west-yorkshire", months, "street", n = n)
  cov <- lamp_coverage_table(street)
  expect_s3_class(cov, "lamp_coverage")
  expect_equal(cov$status[15], "partial_suspected")
  expect_equal(cov$status[3], "submitted")
  expect_true(all(cov$status[-15] == "submitted"))
  expect_true(all(is.na(cov$mismatch)))
})

test_that("mismatched file types are flagged when both are audited", {
  months <- c("2026-05", "2026-06", "2026-07")
  street <- synthetic_grid("dyfed-powys", months, "street")
  stops <- synthetic_grid("dyfed-powys", months, "stop-and-search", status = c("submitted", "missing", "missing"))
  cov <- lamp_coverage_table(street, stops = stops)
  expect_equal(cov$mismatch[cov$file_type == "street"], c(FALSE, TRUE, TRUE))
  expect_equal(cov$mismatch[cov$file_type == "stop-and-search"], c(FALSE, TRUE, TRUE))
  expect_message(print(cov), "mismatched")
  p <- plot(cov)
  expect_s3_class(p, "ggplot")
})

test_that("changelog notes mark refreshed months", {
  months <- c("2021-01", "2021-06", "2023-05", "2023-06")
  street <- synthetic_grid("cheshire", months, "street")
  stops <- synthetic_grid("cheshire", months, "stop-and-search")
  cl <- lamp_parse_changelog(fixture_changelog_html())
  cov <- lamp_coverage_table(street, stops = stops, changelog = cl)
  ss <- cov[cov$file_type == "stop-and-search", ]
  expect_equal(ss$status, c("refreshed", "refreshed", "submitted", "submitted"))
  expect_true(all(!is.na(ss$note[1:2])))
  expect_true(all(cov$status[cov$file_type == "street"] == "submitted"))
})

test_that("coverage from records and comparability between periods", {
  dir <- local_fixture_cache()
  stops <- lamp_read_stop_counts(dir, forces = c("west-yorkshire", "dyfed-powys"))
  cov <- lamp_coverage(stops)
  expect_s3_class(cov, "lamp_coverage")
  expect_equal(sum(cov$status == "missing"), 3L)
  cmp <- lamp_coverage_compare(cov, c("2026-05", "2026-05"), c("2026-06", "2026-07"), file_type = "stop-and-search")
  expect_named(cmp, c(
    "force_id", "n_months_a", "n_usable_a", "n_months_b", "n_usable_b",
    "n_partial_a", "n_partial_b", "n_refreshed_a", "n_refreshed_b",
    "n_mismatch_a", "n_mismatch_b", "comparable"
  ))
  expect_equal(cmp$n_months_b, c(2L, 2L))
  expect_equal(cmp$comparable[cmp$force_id == "west-yorkshire"], TRUE)
  expect_equal(cmp$comparable[cmp$force_id == "dyfed-powys"], FALSE)
  expect_equal(cmp$n_usable_b[cmp$force_id == "dyfed-powys"], 0L)
  expect_error(lamp_coverage_compare(cov, "2026-05", c("2026-06", "2026-07")), class = "streetlamp_error_input")
  expect_error(lamp_coverage_compare(cov, c("2026-05", "2026-05"), c("2026-06", "2026-07"), file_type = "street"), class = "streetlamp_error_input")
  expect_error(lamp_coverage_compare(stops, c("2026-05", "2026-05"), c("2026-06", "2026-07")), class = "streetlamp_error_input")
})

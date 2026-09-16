test_that("shocks table loads with the documented schema", {
  s <- lamp_shocks()
  expect_s3_class(s, "tbl_df")
  expect_named(
    s,
    c(
      "name", "label", "kind", "start", "end", "scope", "forces",
      "source_url", "notes", "verified"
    )
  )
  expect_gt(nrow(s), 20L)
  expect_false(anyDuplicated(s$name) > 0L)
  expect_true(all(grepl("^[a-z0-9_]+$", s$name)))
  expect_s3_class(s$start, "Date")
  expect_s3_class(s$end, "Date")
  expect_s3_class(s$verified, "Date")
  expect_false(anyNA(s$start))
  expect_false(anyNA(s$verified))
  expect_true(all(is.na(s$end) | s$end >= s$start))
  expect_true(all(s$kind %in% c(
    "stop_search_policy", "crime_policy", "covid", "recording_practice",
    "disorder"
  )))
  expect_true(all(s$scope %in% c("national", "england", "wales", "forces")))
  expect_true(all(!is.na(s$forces[s$scope == "forces"])))
  expect_true(all(is.na(s$forces[s$scope != "forces"])))
  expect_true(all(grepl("^https://", s$source_url)))
  expect_false(anyNA(s$notes))
})

test_that("shocks table contains the events named in the specification", {
  s <- lamp_shocks()
  expect_true(all(c(
    "buss_launch", "s60_pilot_seven_forces", "s60_relaxation_all_forces",
    "covid_england_lockdown_1", "covid_england_lockdown_2",
    "covid_england_lockdown_3", "covid_wales_firebreak"
  ) %in% s$name))
  expect_equal(s$start[s$name == "buss_launch"], as.Date("2014-08-26"))
  expect_equal(
    s$start[s$name == "s60_relaxation_all_forces"],
    as.Date("2019-08-11")
  )
  expect_equal(
    s$start[s$name == "covid_england_lockdown_1"],
    as.Date("2020-03-23")
  )
  expect_equal(s$scope[s$name == "svro_pilot"], "forces")
  expect_true(!is.unsorted(s$start))
})

test_that("force lists use police.uk style identifiers", {
  s <- lamp_shocks()
  f <- unlist(strsplit(s$forces[!is.na(s$forces)], ";", fixed = TRUE))
  expect_true(all(grepl("^[a-z]+(-[a-z]+)*$", f)))
  expect_true("metropolitan" %in% f)
})

test_that("bank holidays cover December 2010 onwards without duplicates", {
  bh <- lamp_bank_holidays()
  expect_s3_class(bh, "tbl_df")
  expect_named(bh, c(
    "date", "title", "notes", "bunting", "source",
    "source_url"
  ))
  expect_s3_class(bh$date, "Date")
  expect_false(anyDuplicated(bh$date) > 0L)
  expect_true(!is.unsorted(bh$date))
  expect_lte(min(bh$date), as.Date("2010-12-01"))
  expect_gte(max(bh$date), as.Date("2026-12-31"))
  years <- table(format(bh$date, "%Y"))
  expect_true(all(years[as.character(2010:2026)] >= 8L))
  expect_true(all(c(
    "2011-04-29", "2012-06-05", "2022-06-03", "2022-09-19", "2023-05-08",
    "2020-12-28"
  ) %in% as.character(bh$date)))
  expect_false(anyNA(bh$title))
  expect_false(any(grepl(intToUtf8(8217L), bh$title, fixed = TRUE)))
  expect_true(all(grepl("^https://", bh$source_url)))
})

test_that("LSOA lookup and code lists are complete and internally consistent", {
  lk <- lamp_lsoa_lookup()
  expect_s3_class(lk, "tbl_df")
  expect_named(lk, c(
    "lsoa11", "lsoa11_name", "lsoa21", "lsoa21_name",
    "change", "lad22", "lad22_name", "best_fit"
  ))
  expect_s3_class(lk$change, "factor")
  expect_equal(levels(lk$change), c("U", "S", "M", "X"))
  expect_false(anyNA(lk$change))
  expect_type(lk$best_fit, "logical")

  c11 <- lamp_lsoa_codes("lsoa11")
  c21 <- lamp_lsoa_codes("lsoa21")
  expect_length(c11, 34753L)
  expect_length(c21, 35672L)
  expect_true(all(grepl("^[EW]01[0-9]{6}$", c11)))
  expect_true(all(grepl("^[EW]01[0-9]{6}$", c21)))
  expect_true(!is.unsorted(c11))
  expect_true(!is.unsorted(c21))
  expect_equal(sum(startsWith(c21, "W")), 1917L)
  expect_equal(sum(startsWith(c11, "W")), 1909L)

  # every 2011 LSOA has exactly one best-fit 2021 LSOA
  bf <- tapply(lk$best_fit, lk$lsoa11, sum)
  expect_true(all(bf == 1L))
  # unchanged LSOAs keep their code
  expect_true(all(lk$lsoa11[lk$change == "U"] == lk$lsoa21[lk$change == "U"]))
  # codes present in only one vintage exist, which is what vintage detection
  # relies on
  expect_gt(length(setdiff(c11, c21)), 0L)
  expect_gt(length(setdiff(c21, c11)), 0L)
})

test_that("default vintage for lamp_lsoa_codes() is lsoa21", {
  expect_identical(lamp_lsoa_codes(), lamp_lsoa_codes("lsoa21"))
  expect_error(lamp_lsoa_codes("lsoa01"), class = "rlang_error")
})

test_that("bundled tables are read once and memoised", {
  the <- streetlamp:::the
  the$bundled_shocks <- NULL
  s1 <- lamp_shocks()
  expect_false(is.null(the$bundled_shocks))
  s2 <- lamp_shocks()
  expect_identical(s1, s2)
})

test_that("a missing bundled file raises a classed error", {
  expect_error(
    streetlamp:::lamp_extdata("does-not-exist.csv"),
    class = "streetlamp_error_bundled"
  )
})

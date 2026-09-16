test_that("street files read into the fixed schema with a contract", {
  dir <- local_fixture_cache()
  crime <- lamp_read_crime(dir)
  expect_s3_class(crime, "lamp_records")
  expect_s3_class(crime, "tbl_df")
  expect_named(crime, c(
    "crime_id", "month", "reported_by", "falls_within", "force_id", "longitude",
    "latitude", "location", "lsoa_code", "lsoa_name", "lsoa_vintage",
    "crime_type", "crime_type_raw", "is_asb", "last_outcome_category",
    "context", "archive", "file"
  ))
  expect_s3_class(crime$month, "Date")
  expect_true(all(format(crime$month, "%d") == "01"))
  expect_type(crime$longitude, "double")
  expect_s3_class(crime$crime_type, "factor")
  expect_equal(nlevels(crime$crime_type), 15L)
  expect_true("Public disorder and weapons" %in% levels(crime$crime_type))
  expect_setequal(unique(crime$force_id), c("west-yorkshire", "dyfed-powys"))
  expect_setequal(as.character(unique(crime$month)), c("2026-05-01", "2026-06-01", "2026-07-01"))
  expect_true(all(crime$lsoa_vintage == "lsoa21"))
  expect_equal(unique(crime$archive), "2026-07")
})

test_that("anti-social behaviour rows carry no crime id and are flagged", {
  dir <- local_fixture_cache()
  crime <- lamp_read_crime(dir, forces = "dyfed-powys", months = "2026-07")
  expect_gt(sum(crime$is_asb), 0L)
  expect_true(all(is.na(crime$crime_id[crime$is_asb])))
  expect_true(all(!is.na(crime$crime_id[!crime$is_asb])))
  expect_true(all(crime$crime_type[crime$is_asb] == "Anti-social behaviour"))
  expect_true(all(is.na(crime$last_outcome_category[crime$is_asb])))
  d <- lamp_contract(crime)$crime_scope$diagnostics
  expect_equal(d$n_asb, sum(crime$is_asb))
  expect_equal(d$n_asb_with_id, 0L)
  expect_equal(d$category_set, "fourteen")
})

test_that("rows without coordinates are retained as NA", {
  dir <- local_fixture_cache()
  crime <- lamp_read_crime(dir, forces = "west-yorkshire", months = "2026-07")
  expect_gt(sum(is.na(crime$latitude)), 0L)
  expect_equal(sum(is.na(crime$latitude)), sum(is.na(crime$lsoa_code)))
  expect_equal(lamp_contract(crime)$crime_scope$diagnostics$n_missing_location, sum(is.na(crime$latitude)))
})

test_that("the coverage grid marks force-months without a file as missing", {
  dir <- local_fixture_cache()
  crime <- lamp_read_crime(dir)
  cov <- lamp_contract(crime)$coverage
  expect_named(cov, c("force_id", "month", "file_type", "status", "archive", "n_records", "n_versions", "versions_differ"))
  expect_equal(nrow(cov), 6L)
  expect_true(all(cov$status == "submitted"))
  expect_true(all(cov$n_records > 0L))
  expect_true(all(cov$n_versions[cov$month < as.Date("2026-07-01")] == 2L))

  wider <- lamp_read_crime(dir, months = c("2026-04", "2026-05"), forces = c("dyfed-powys", "gwent"))
  cov2 <- lamp_contract(wider)$coverage
  expect_equal(nrow(cov2), 4L)
  expect_equal(cov2$status[cov2$force_id == "gwent"], c("missing", "missing"))
  expect_equal(cov2$status[cov2$force_id == "dyfed-powys" & cov2$month == as.Date("2026-04-01")], "missing")
  expect_true(all(is.na(cov2$n_records[cov2$status == "missing"])))
  expect_equal(cov2$n_versions[cov2$status == "missing"], c(0L, 0L, 0L))
  expect_error(lamp_read_crime(dir, forces = "gwent"), class = "streetlamp_error_input")
})

test_that("legacy crime type labels are harmonised and unknown ones flagged", {
  raw <- synthetic_street(c(
    "Violent crime", "Public disorder and weapons", "Other theft", "Burglary",
    "Anti-social behaviour"
  ), month = "2013-04")
  parsed <- lamp_parse_street(raw, "test-force", "2013-04", "2013-04/2013-04-test-force-street.csv", as.Date("2013-04-01"))
  ct <- as.character(parsed$data$crime_type)
  expect_equal(ct[1], "Violence and sexual offences")
  expect_equal(ct[2], "Public disorder and weapons")
  expect_equal(parsed$data$crime_type_raw[1], "Violent crime")
  expect_equal(parsed$diagnostics$category_set, "eleven")
  expect_equal(parsed$diagnostics$lsoa_vintage, "lsoa11")
  expect_equal(parsed$diagnostics$vintage_basis, "month")

  six <- synthetic_street(c("Violent crime", "Other crime", "Burglary"), month = "2011-03")
  p6 <- lamp_parse_street(six, "test-force", "2013-12", "2011-03/2011-03-test-force-street.csv", as.Date("2011-03-01"))
  expect_equal(p6$diagnostics$category_set, "six")

  bad <- synthetic_street(c("Burglary", "Bogus category"), month = "2026-07")
  expect_warning(
    pb <- lamp_parse_street(bad, "test-force", "2026-07", "2026-07/2026-07-test-force-street.csv", as.Date("2026-07-01")),
    class = "streetlamp_warning_input"
  )
  expect_true(is.na(pb$data$crime_type[2]))
  expect_equal(pb$data$crime_type_raw[2], "Bogus category")
  expect_equal(pb$diagnostics$category_set, "fourteen")
})

test_that("a file with missing columns is refused", {
  raw <- synthetic_street("Burglary", month = "2026-07")
  raw[["Crime type"]] <- NULL
  expect_error(
    lamp_parse_street(raw, "f", "2026-07", "2026-07/2026-07-f-street.csv", as.Date("2026-07-01")),
    class = "streetlamp_error_input"
  )
})

test_that("rows dated outside the file month raise a warning but are kept", {
  raw <- synthetic_street(c("Burglary", "Drugs"), month = "2026-07")
  raw$Month <- c("2026-07", "2026-06")
  expect_warning(
    p <- lamp_parse_street(raw, "f", "2026-07", "2026-07/2026-07-f-street.csv", as.Date("2026-07-01")),
    class = "streetlamp_warning_input"
  )
  expect_equal(p$data$month, as.Date(c("2026-07-01", "2026-06-01")))
})

test_that("outcomes files read with classified outcomes", {
  dir <- local_fixture_cache()
  out <- lamp_read_outcomes(dir, forces = "dyfed-powys", months = "2026-07")
  expect_s3_class(out, "lamp_records")
  expect_named(out, c(
    "crime_id", "month", "reported_by", "falls_within", "force_id", "longitude",
    "latitude", "location", "lsoa_code", "lsoa_name", "lsoa_vintage",
    "outcome_type", "outcome_type_raw", "outcome_group", "archive", "file"
  ))
  expect_s3_class(out$outcome_type, "factor")
  expect_equal(levels(out$outcome_type), lamp_outcome_types()$outcome_type)
  expect_s3_class(out$outcome_group, "factor")
  expect_equal(levels(out$outcome_group), lamp_outcome_groups())
  expect_false(anyNA(out$outcome_group))
  expect_true(all(out$lsoa_vintage == "lsoa21"))
  cov <- lamp_contract(out)$coverage
  expect_equal(nrow(cov), 1L)
  expect_equal(cov$status, "submitted")
  expect_equal(cov$n_records, nrow(out))
})

test_that("unknown outcome labels are flagged", {
  raw <- data.frame(
    "Crime ID" = c("a", "b"), "Month" = "2026-07", "Reported by" = "F", "Falls within" = "F",
    "Longitude" = "-1", "Latitude" = "53", "Location" = "x", "LSOA code" = "E01000001",
    "LSOA name" = "n", "Outcome type" = c("Suspect charged", "Something new"),
    check.names = FALSE, stringsAsFactors = FALSE
  )
  expect_warning(
    p <- lamp_parse_outcomes(raw, "f", "2026-07", "2026-07/2026-07-f-outcomes.csv", as.Date("2026-07-01")),
    class = "streetlamp_warning_input"
  )
  expect_true(is.na(p$data$outcome_type[2]))
  expect_true(is.na(p$data$outcome_group[2]))
  expect_equal(as.character(p$data$outcome_group[1]), "charged_or_summonsed")
})

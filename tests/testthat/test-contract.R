test_that("contracts are built with every field and validated", {
  con <- new_lamp_contract()
  expect_s3_class(con, "lamp_contract")
  expect_named(con, lamp_contract_fields())
  expect_equal(con$source, "data.police.uk archive")
  expect_null(con$treatment)
  expect_equal(con$created$package_version, as.character(utils::packageVersion("streetlamp")))
  expect_identical(lamp_contract(con), con)

  broken <- con
  broken$coverage <- NULL
  expect_error(validate_lamp_contract(broken), class = "streetlamp_error_contract")
  expect_error(lamp_contract(unclass(con)), class = "streetlamp_error_contract")
  expect_error(lamp_contract(tibble::tibble(a = 1)), class = "streetlamp_error_contract")
  nocreated <- con
  nocreated$created <- list()
  expect_error(validate_lamp_contract(nocreated), class = "streetlamp_error_contract")
})

test_that("contracts print a summary", {
  dir <- local_fixture_cache()
  crime <- lamp_read_crime(dir, forces = "dyfed-powys", months = "2026-07")
  con <- lamp_contract(crime)
  expect_message(print(con), "contract")
  expect_message(summary(con), "Coverage")
  expect_message(print(crime), "streetlamp records")
})

test_that("contracts survive subsetting and dplyr verbs", {
  dir <- local_fixture_cache()
  crime <- lamp_read_crime(dir, forces = "dyfed-powys", months = "2026-07")
  con <- lamp_contract(crime)

  rows <- crime[crime$is_asb, ]
  expect_s3_class(rows, "lamp_records")
  expect_identical(lamp_contract(rows), con)
  cols <- crime[, c("crime_id", "month")]
  expect_s3_class(cols, "lamp_records")
  expect_identical(lamp_contract(cols), con)
  expect_type(crime[["crime_id"]], "character")
  head5 <- head(crime, 5)
  expect_identical(lamp_contract(head5), con)

  filtered <- dplyr::filter(crime, !is_asb)
  expect_identical(lamp_contract(filtered), con)
  mutated <- dplyr::mutate(crime, year = format(month, "%Y"))
  expect_identical(lamp_contract(mutated), con)
  selected <- dplyr::select(crime, crime_id, crime_type)
  expect_identical(lamp_contract(selected), con)
  arranged <- dplyr::arrange(crime, crime_type)
  expect_identical(lamp_contract(arranged), con)
  sliced <- dplyr::slice(crime, 1:10)
  expect_identical(lamp_contract(sliced), con)
  expect_s3_class(sliced, "lamp_records")
})

test_that("records tables report their versions and snapshots in the contract", {
  dir <- local_fixture_cache()
  crime <- lamp_read_crime(dir, forces = "west-yorkshire", months = "2026-05")
  con <- lamp_contract(crime)
  expect_s3_class(con$versions, "lamp_selection")
  expect_equal(con$versions$archive, "2026-07")
  expect_equal(con$versions$n_versions, 2L)
  expect_equal(con$snapshots$archive, "2026-07")
  expect_equal(con$geography$lsoa_vintage, "lsoa21")
  expect_equal(nrow(con$geography$files), 1L)
  expect_equal(con$crime_scope$category_sets$category_set, "fourteen")
  expect_true("Public disorder and weapons" %in% con$crime_scope$crime_types)
})

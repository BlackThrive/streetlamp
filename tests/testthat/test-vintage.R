test_that("vintage is decided by codes that exist in only one vintage", {
  sets <- lamp_vintage_sets()
  expect_gt(length(sets$only11), 0L)
  expect_gt(length(sets$only21), 0L)
  both <- setdiff(lamp_lsoa_codes("lsoa21"), sets$only21)[1:5]

  v11 <- lamp_lsoa_vintage(c(both, sets$only11[1]))
  expect_equal(v11$vintage, "lsoa11")
  expect_equal(v11$basis, "codes")
  expect_equal(v11$n_only_2011, 1L)
  v21 <- lamp_lsoa_vintage(c(both, sets$only21[1:2]))
  expect_equal(v21$vintage, "lsoa21")
  expect_equal(v21$n_only_2021, 2L)
  mixed <- lamp_lsoa_vintage(c(sets$only11[1], sets$only21[1]))
  expect_equal(mixed$vintage, "mixed")
  amb <- lamp_lsoa_vintage(both)
  expect_equal(amb$vintage, "ambiguous")
  expect_equal(amb$n_both, 5L)
  unknown <- lamp_lsoa_vintage(c(both, "S01000001", NA))
  expect_equal(unknown$n_unknown, 1L)
  expect_equal(unknown$n_codes, 6L)
})

test_that("ambiguous codes fall back to the publication month", {
  sets <- lamp_vintage_sets()
  both <- setdiff(lamp_lsoa_codes("lsoa21"), sets$only21)[1:3]
  before <- lamp_lsoa_vintage(both, month = "2023-05")
  expect_equal(before$vintage, "lsoa11")
  expect_equal(before$basis, "month")
  after <- lamp_lsoa_vintage(both, month = "2023-06")
  expect_equal(after$vintage, "lsoa21")
  expect_equal(after$basis, "month")
  decisive <- lamp_lsoa_vintage(c(both, sets$only11[1]), month = "2024-01")
  expect_equal(decisive$vintage, "lsoa11")
  expect_equal(decisive$basis, "codes")
})

test_that("records are assessed file by file", {
  dir <- local_fixture_cache()
  crime <- lamp_read_crime(dir)
  v <- lamp_lsoa_vintage(crime)
  expect_equal(nrow(v), 6L)
  expect_named(v, c(
    "archive", "file", "force_id", "month", "vintage", "basis", "n_codes",
    "n_only_2011", "n_only_2021", "n_both", "n_unknown"
  ))
  expect_true(all(v$vintage == "lsoa21"))
  expect_error(lamp_lsoa_vintage(tibble::tibble(x = 1)), class = "streetlamp_error_input")
  expect_error(lamp_lsoa_vintage(1:3), class = "streetlamp_error_input")
})

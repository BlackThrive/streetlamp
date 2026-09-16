test_that("the bundled sample panel is a complete, contract-bearing LSOA panel", {
  p <- lamp_sample_panel()
  expect_s3_class(p, "lamp_panel")
  lk <- lamp_area_lookup()
  n_areas <- sum(lk$force_id %in% c("west-yorkshire", "dyfed-powys"))
  expect_equal(nrow(p), n_areas * 24L)
  expect_equal(range(p$month), as.Date(c("2024-08-01", "2026-07-01")))
  expect_true(all(c(
    "area", "month", "force_id", "burglary", "violence_and_sexual_offences",
    "crime_total", "asb", "stops", "stops_s60", "population", "stop_rate",
    "imd_decile", "imd_decile_crime", "imd_index", "coverage_status", "stops_status"
  ) %in% names(p)))
  expect_setequal(unique(p$force_id), c("west-yorkshire", "dyfed-powys"))
  expect_false(anyNA(p$population))
  expect_false(anyNA(p$imd_decile))
  expect_true(all(p$coverage_status %in% c("submitted", "refreshed", "partial_suspected")))
  expect_false(anyNA(p$crime_total))

  con <- lamp_contract(p)
  expect_equal(con$geography$area, "lsoa21")
  expect_equal(con$geography$lsoa_vintage, "lsoa21")
  expect_s3_class(con$geography$adjacency, "lamp_adjacency")
  expect_equal(con$stops$origin, "streetlamp")
  expect_equal(con$population$dataset, "NM_2021_1")
  expect_equal(con$snapshots$archive, "2026-07")

  # Dyfed-Powys stopped submitting stop-and-search files after November 2025
  dp_late <- p[p$force_id == "dyfed-powys" & p$month >= as.Date("2025-12-01"), ]
  expect_true(all(is.na(dp_late$stops)))
  expect_true(all(dp_late$stops_status == "missing"))
  dp_early <- p[p$force_id == "dyfed-powys" & p$month < as.Date("2025-12-01"), ]
  expect_false(anyNA(dp_early$stops))
  wy <- p[p$force_id == "west-yorkshire", ]
  expect_false(anyNA(wy$stops))
  expect_gt(sum(wy$stops), 0L)

  cov <- lamp_coverage(p)
  expect_true(any(cov$mismatch %in% TRUE))
  expect_equal(nrow(cov), 2L * 24L * 2L)
  cmp <- lamp_coverage_compare(cov, c("2024-08", "2025-07"), c("2025-08", "2026-07"), file_type = "stop-and-search")
  expect_equal(cmp$comparable[cmp$force_id == "dyfed-powys"], FALSE)
  expect_equal(cmp$comparable[cmp$force_id == "west-yorkshire"], TRUE)
  expect_s3_class(plot(p), "ggplot")
  expect_s3_class(plot(cov), "ggplot")
})

test_that("the bundled sample boundaries match the panel areas", {
  bnd <- lamp_sample_boundaries()
  p <- lamp_sample_panel()
  expect_s3_class(bnd, "sf")
  expect_named(bnd, c("area", "name", "geometry"))
  expect_setequal(bnd$area, unique(p$area))
  expect_equal(sf::st_crs(bnd)$epsg, 27700L)
  expect_true(all(sf::st_is_valid(bnd)))
  expect_equal(attr(bnd, "vintage"), "lsoa21-bgc")
  adj <- lamp_adjacency(bnd)
  expect_equal(length(adj$areas), nrow(bnd))
  expect_lt(adj$n_islands, 5L)
})

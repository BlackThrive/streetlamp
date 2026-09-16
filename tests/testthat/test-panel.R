fixture_panel_inputs <- function(envir = parent.frame()) {
  dir <- local_fixture_cache(envir)
  crime <- lamp_read_crime(dir)
  list(
    dir = dir,
    crime = crime,
    areas = sort(unique(crime$lsoa_code[!is.na(crime$lsoa_code)]))
  )
}

test_that("an LSOA panel is balanced, zero-filled only where submitted, and carries a contract", {
  inp <- fixture_panel_inputs()
  panel <- lamp_panel(inp$crime, areas = inp$areas)
  expect_s3_class(panel, "lamp_panel")
  expect_s3_class(panel, "tbl_df")
  ct <- lamp_crime_types()
  type_keys <- setdiff(ct$key, "anti_social_behaviour")
  expect_named(panel, c(
    "area", "month", "force_id", type_keys, "crime_total", "asb", "stops", "stops_s60",
    "population", "stop_rate", "coverage_status", "stops_status"
  ))
  expect_equal(nrow(panel), length(inp$areas) * 3L)
  expect_setequal(unique(panel$area), inp$areas)
  expect_equal(sort(unique(panel$month)), as.Date(c("2026-05-01", "2026-06-01", "2026-07-01")))
  expect_true(all(panel$coverage_status == "submitted"))
  expect_false(anyNA(panel$crime_total))
  expect_equal(panel$crime_total, as.integer(rowSums(panel[, type_keys])))
  expect_true(all(is.na(panel$stops)))
  expect_true(all(is.na(panel$population)))
  # every placed record is counted exactly once
  placed <- inp$crime[!is.na(inp$crime$lsoa_code), ]
  expect_equal(sum(panel$crime_total) + sum(panel$asb), nrow(placed))
  expect_equal(sum(panel$asb), sum(placed$is_asb))
  # force of each area comes from geography
  expect_setequal(unique(panel$force_id), c("west-yorkshire", "dyfed-powys"))
  expect_true(all(panel$force_id[startsWith(panel$area, "W")] == "dyfed-powys"))

  con <- lamp_contract(panel)
  expect_equal(con$geography$area, "lsoa21")
  expect_equal(con$geography$n_areas, length(inp$areas))
  expect_equal(con$geography$placement$n_no_lsoa, sum(is.na(inp$crime$lsoa_code)))
  expect_equal(con$geography$placement$n_outside_universe, 0L)
  expect_equal(con$crime_scope$include_asb, FALSE)
  expect_equal(con$crime_scope$attribution, "falls_within")
  expect_s3_class(con$coverage, "lamp_coverage")
  expect_null(con$stops)
  expect_null(con$population)
  expect_message(print(panel), "streetlamp panel")
})

test_that("the panel universe covers whole police force areas when unrestricted", {
  inp <- fixture_panel_inputs()
  lad <- lamp_panel(inp$crime, area = "lad")
  lk <- lamp_area_lookup()
  expect_equal(nrow(lad), 9L * 3L)
  expect_setequal(unique(lad$area), unique(lk$lad22[lk$force_id %in% c("west-yorkshire", "dyfed-powys")]))
  expect_true(all(lad$coverage_status == "submitted"))
  # districts without any bundled records are zero, not NA, because the force submitted
  expect_false(anyNA(lad$crime_total))
  expect_true(any(lad$crime_total == 0L))
  expect_equal(sum(lad$crime_total) + sum(lad$asb), sum(!is.na(inp$crime$lsoa_code)))

  # at force level records are counted by the attributed force, so records
  # without a location are included
  pfa <- lamp_panel(inp$crime, area = "pfa")
  expect_equal(nrow(pfa), 2L * 3L)
  expect_setequal(unique(pfa$area), c("E23000010", "W15000004"))
  expect_equal(sum(pfa$crime_total) + sum(pfa$asb), nrow(inp$crime))

  msoa <- lamp_panel(inp$crime, area = "msoa21", areas = unique(lamp_map_area(inp$areas, "msoa21")))
  expect_equal(nrow(msoa), length(unique(lamp_map_area(inp$areas, "msoa21"))) * 3L)
  expect_equal(sum(msoa$crime_total), sum(lad$crime_total))
})

test_that("missing force-months are NA, not zero", {
  dir <- local_fixture_cache()
  crime <- lamp_read_crime(dir, months = c("2026-04", "2026-05"), forces = c("dyfed-powys", "west-yorkshire"))
  areas <- sort(unique(crime$lsoa_code[!is.na(crime$lsoa_code)]))
  panel <- lamp_panel(crime, areas = areas)
  expect_equal(sort(unique(panel$month)), as.Date(c("2026-04-01", "2026-05-01")))
  april <- panel[panel$month == as.Date("2026-04-01"), ]
  may <- panel[panel$month == as.Date("2026-05-01"), ]
  expect_true(all(april$coverage_status == "missing"))
  expect_true(all(is.na(april$crime_total)))
  expect_true(all(is.na(april$asb)))
  expect_true(all(is.na(april$burglary)))
  expect_true(all(may$coverage_status == "submitted"))
  expect_false(anyNA(may$crime_total))
  cov <- lamp_coverage(panel)
  expect_equal(cov$status[cov$month == as.Date("2026-04-01")], c("missing", "missing"))
})

test_that("stops join at the right level and stay NA where the force did not submit", {
  inp <- fixture_panel_inputs()
  force_stops <- lamp_read_stop_counts(inp$dir, forces = c("west-yorkshire", "dyfed-powys"))
  expect_error(lamp_panel(inp$crime, stops = force_stops, areas = inp$areas), class = "streetlamp_error_input")

  pfa <- lamp_panel(inp$crime, stops = force_stops, area = "pfa")
  wy <- pfa[pfa$force_id == "west-yorkshire", ]
  dp <- pfa[pfa$force_id == "dyfed-powys", ]
  expect_equal(wy$stops, force_stops$stops[order(force_stops$month)])
  expect_true(all(wy$stops_status == "submitted"))
  expect_true(all(is.na(dp$stops)))
  expect_true(all(dp$stops_status == "missing"))
  con <- lamp_contract(pfa)
  expect_equal(con$stops$origin, "streetlamp")
  expect_equal(con$stops$rate, "stops per 1,000 residents")
  cov <- lamp_coverage(pfa)
  expect_true(all(cov$mismatch[cov$force_id == "dyfed-powys"]))
  expect_false(any(cov$mismatch[cov$force_id == "west-yorkshire"]))

  user <- tibble::tibble(
    area = inp$areas[1:2], month = as.Date("2026-06-01"), stops = c(3L, 5L), stops_s60 = c(1L, 0L)
  )
  up <- lamp_panel(inp$crime, stops = user, areas = inp$areas)
  expect_equal(up$stops[up$area == inp$areas[1] & up$month == as.Date("2026-06-01")], 3L)
  expect_equal(up$stops_s60[up$area == inp$areas[2] & up$month == as.Date("2026-06-01")], 0L)
  expect_true(is.na(up$stops[up$area == inp$areas[1] & up$month == as.Date("2026-05-01")]))
  expect_equal(lamp_contract(up)$stops$origin, "user_supplied")
  expect_error(lamp_panel(inp$crime, stops = data.frame(x = 1), areas = inp$areas), class = "streetlamp_error_input")
})

test_that("population gives a stop rate per 1,000 residents", {
  inp <- fixture_panel_inputs()
  pop <- tibble::tibble(area = inp$areas, population = 1500)
  user <- tibble::tibble(area = inp$areas, month = as.Date("2026-07-01"), stops = 3L)
  panel <- lamp_panel(inp$crime, stops = user, population = pop, areas = inp$areas)
  july <- panel[panel$month == as.Date("2026-07-01"), ]
  expect_equal(unique(july$population), 1500)
  expect_equal(unique(july$stop_rate), 2)
  expect_true(all(is.na(panel$stop_rate[panel$month != as.Date("2026-07-01")])))
  expect_equal(lamp_contract(panel)$population, "user_supplied")
  attr(pop, "area") <- "lad"
  expect_error(lamp_panel(inp$crime, population = pop, areas = inp$areas), class = "streetlamp_error_input")
  expect_error(lamp_panel(inp$crime, population = data.frame(area = "a"), areas = inp$areas), class = "streetlamp_error_input")
})

test_that("ASB, outcomes and covariates are handled as documented", {
  inp <- fixture_panel_inputs()
  with_asb <- lamp_panel(inp$crime, include_asb = TRUE, areas = inp$areas)
  without <- lamp_panel(inp$crime, areas = inp$areas)
  expect_equal(with_asb$crime_total, without$crime_total + without$asb)
  expect_true("asb" %in% lamp_contract(with_asb)$crime_scope$crime_total)

  outcomes <- lamp_read_outcomes(inp$dir)
  po <- lamp_panel(inp$crime, outcomes = outcomes, areas = inp$areas)
  ocols <- paste0("outcome_", lamp_outcome_groups())
  expect_true(all(c("outcomes_total", ocols) %in% names(po)))
  expect_false(anyNA(po$outcomes_total))
  expect_equal(po$outcomes_total, as.integer(rowSums(po[, ocols])))
  expect_gt(sum(po$outcomes_total), 0L)

  cov <- tibble::tibble(area = inp$areas, imd_decile = 5L)
  pc <- lamp_panel(inp$crime, covariates = cov, areas = inp$areas)
  expect_true(all(pc$imd_decile == 5L))
  expect_error(lamp_panel(inp$crime, covariates = tibble::tibble(area = inp$areas, asb = 1), areas = inp$areas), class = "streetlamp_error_input")
})

test_that("records published with 2011 codes are re-vintaged and documented", {
  inp <- fixture_panel_inputs()
  crime <- inp$crime
  lk <- lamp_lsoa_lookup()
  parent <- lk$lsoa11[lk$change == "S" & startsWith(lk$lsoa11, "E01011")][1]
  skip_if(is.na(parent))
  first_file <- crime$file == crime$file[1]
  crime$lsoa_code[first_file] <- parent
  crime$lsoa_vintage[first_file] <- "lsoa11"
  target <- lk$lsoa21[lk$best_fit & lk$lsoa11 == parent]
  panel <- lamp_panel(crime, areas = c(inp$areas, target))
  rv <- lamp_contract(panel)$geography$revintage
  expect_named(rv, "lsoa11")
  expect_equal(rv$lsoa11$n_records, sum(first_file))
  expect_equal(rv$lsoa11$areas_split, 1L)
  expect_equal(rv$lsoa11$share_split_or_merged, 1)
  expect_equal(lamp_contract(panel)$geography$lookup, "ONS LSOA 2011 to 2021 exact-fit lookup V3 with best-fit V2 flag")
  moved <- panel[panel$area == target & panel$month == crime$month[1], ]
  expect_equal(moved$crime_total + moved$asb, sum(first_file))
})

test_that("panels keep their contract through subsetting, dplyr verbs and plot", {
  inp <- fixture_panel_inputs()
  panel <- lamp_panel(inp$crime, areas = inp$areas)
  con <- lamp_contract(panel)
  expect_identical(lamp_contract(panel[1:10, ]), con)
  expect_identical(lamp_contract(dplyr::filter(panel, month == as.Date("2026-06-01"))), con)
  expect_s3_class(dplyr::mutate(panel, x = 1), "lamp_panel")
  p <- plot(panel)
  expect_s3_class(p, "ggplot")
  expect_error(plot(panel, outcome = "nope"), class = "streetlamp_error_input")
  expect_error(lamp_panel(inp$crime, areas = "E01000001"), class = "streetlamp_error_input")
  expect_error(lamp_panel(inp$crime, areas = 1), class = "streetlamp_error_input")
  expect_error(lamp_panel(tibble::tibble(a = 1)), class = "streetlamp_error_input")
})

test_that("stop counts per force-month read from the fixture", {
  dir <- local_fixture_cache()
  stops <- lamp_read_stop_counts(dir, forces = c("west-yorkshire", "dyfed-powys"))
  expect_s3_class(stops, "lamp_records")
  expect_named(stops, c(
    "area", "force_id", "month", "archive", "stops", "stops_s60",
    "stops_no_location", "stops_no_legislation"
  ))
  expect_equal(unique(stops$force_id), "west-yorkshire")
  expect_equal(stops$area, stops$force_id)
  expect_equal(nrow(stops), 3L)
  expect_true(all(stops$stops > 0L))
  expect_true(all(stops$stops_s60 >= 0L))
  expect_gt(sum(stops$stops_no_location), 0L)
  con <- lamp_contract(stops)
  expect_equal(con$stops$origin, "streetlamp")
  expect_equal(con$stops$definition, "raw count")
  expect_equal(con$stops$area, "force")
  expect_equal(con$stops$s60_legislation, lamp_s60_legislation())
  cov <- con$coverage
  expect_equal(nrow(cov), 6L)
  expect_equal(cov$status[cov$force_id == "dyfed-powys"], rep("missing", 3L))
  expect_equal(cov$status[cov$force_id == "west-yorkshire"], rep("submitted", 3L))
  expect_equal(cov$n_records[cov$force_id == "west-yorkshire"], stops$stops)
})

test_that("only the four needed columns are read from a stop-and-search file", {
  dir <- local_fixture_cache()
  snap <- lamp_archive_snapshot(dir)
  m <- snap$members[which(snap$members$file_type == "stop-and-search")[1], ]
  path <- lamp_member_path(snap, m$archive, m$member)
  x <- lamp_read_stop_file(path, m$member)
  expect_named(x, c("Date", "Latitude", "Longitude", "Legislation"))
  header <- names(utils::read.csv(path, nrows = 1, check.names = FALSE))
  expect_gt(length(header), 4L)
})

test_that("the Section 60 flag uses the exact legislation string", {
  raw <- synthetic_stops(c(
    lamp_s60_legislation(),
    "Police and Criminal Evidence Act 1984 (section 1)",
    "Misuse of Drugs Act 1971 (section 23)",
    NA
  ))
  raw$Latitude[3] <- NA
  raw$Longitude[3] <- NA
  p <- lamp_parse_stops(raw, "f", "2026-07", "2026-07/2026-07-f-stop-and-search.csv", as.Date("2026-07-01"))
  expect_equal(p$data$is_s60, c(TRUE, FALSE, FALSE, FALSE))
  expect_equal(p$data$no_legislation, c(FALSE, FALSE, FALSE, TRUE))
  expect_equal(p$data$no_location, c(FALSE, FALSE, TRUE, FALSE))
  expect_equal(p$data$month, rep(as.Date("2026-07-01"), 4L))
  expect_equal(p$diagnostics$n_s60, 1L)
  expect_equal(p$diagnostics$n_no_location, 1L)
  expect_equal(p$diagnostics$n_no_legislation, 1L)
})

test_that("stops are dated by the file month and boundary rows are counted", {
  raw <- synthetic_stops(c("a", "b"), date = c("2026-07-02T10:00:00+00:00", "2026-06-30T23:10:00+00:00"))
  p <- lamp_parse_stops(raw, "f", "2026-07", "2026-07/2026-07-f-stop-and-search.csv", as.Date("2026-07-01"))
  expect_equal(p$data$month, rep(as.Date("2026-07-01"), 2L))
  expect_equal(p$diagnostics$n_outside_month, 1L)
  dir <- local_fixture_cache()
  stops <- lamp_read_stop_counts(dir, forces = "west-yorkshire")
  d <- lamp_contract(stops)$stops$diagnostics
  expect_true("n_outside_month" %in% names(d))
  expect_equal(nrow(stops), 3L)
})

test_that("points are assigned to polygons in British National Grid", {
  square <- function(x0, y0, id) {
    sf::st_sf(
      area = id,
      geometry = sf::st_sfc(sf::st_polygon(list(rbind(
        c(x0, y0), c(x0 + 1, y0), c(x0 + 1, y0 + 1), c(x0, y0 + 1), c(x0, y0)
      ))), crs = 4326)
    )
  }
  boundaries <- rbind(square(-2, 53, "A"), square(-1, 53, "B"))
  points <- tibble::tibble(
    longitude = c(-1.5, -0.5, -1.5, 5, NA),
    latitude = c(53.5, 53.5, 53.9, 53.5, NA),
    no_location = c(FALSE, FALSE, FALSE, FALSE, TRUE)
  )
  area <- lamp_assign_area(points, boundaries)
  expect_equal(area, c("A", "B", "A", NA, NA))
  expect_error(lamp_assign_area(points, data.frame(area = "A")), class = "streetlamp_error_input")
})

test_that("area counts need boundaries and produce area-month rows", {
  dir <- local_fixture_cache()
  expect_error(lamp_read_stop_counts(dir, area = "lsoa21"), class = "streetlamp_error_input")
  snap <- lamp_archive_snapshot(dir)
  crime <- lamp_read_crime(snap, forces = "west-yorkshire", months = "2026-07")
  lon <- range(crime$longitude, na.rm = TRUE)
  lat <- range(crime$latitude, na.rm = TRUE)
  mid <- mean(lon)
  box <- function(x0, x1, id) {
    sf::st_sf(
      area = id,
      geometry = sf::st_sfc(sf::st_polygon(list(rbind(
        c(x0, lat[1] - 0.01), c(x1, lat[1] - 0.01), c(x1, lat[2] + 0.01),
        c(x0, lat[2] + 0.01), c(x0, lat[1] - 0.01)
      ))), crs = 4326)
    )
  }
  boundaries <- rbind(box(lon[1] - 0.01, mid, "west"), box(mid, lon[2] + 0.01, "east"))
  stops <- lamp_read_stop_counts(snap,
    area = "custom", boundaries = boundaries,
    forces = "west-yorkshire", months = "2026-07"
  )
  expect_named(stops, c("area", "month", "force_id", "archive", "stops", "stops_s60"))
  expect_setequal(stops$area, c("west", "east"))
  force_total <- lamp_read_stop_counts(snap, forces = "west-yorkshire", months = "2026-07")
  con <- lamp_contract(stops)
  expect_equal(sum(stops$stops) + con$stops$n_unassigned + force_total$stops_no_location, force_total$stops)
  expect_equal(con$stops$area, "custom")
})

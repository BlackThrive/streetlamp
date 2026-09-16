# A fake NOMIS server: every 2021 LSOA with population 1000 + row index, served
# in pages of `page` rows in the same CSV layout as the API.
fake_nomis <- function(page = 20000L) {
  codes <- lamp_lsoa_codes("lsoa21")
  pop <- 1000 + seq_along(codes)
  handler <- function(url, call = NULL) {
    offset <- as.integer(sub(".*RecordOffset=([0-9]+).*", "\\1", url))
    limit <- as.integer(sub(".*RecordLimit=([0-9]+).*", "\\1", url))
    idx <- seq_len(length(codes))
    idx <- idx[idx > offset & idx <= offset + min(limit, page)]
    body <- data.frame(
      GEOGRAPHY_CODE = codes[idx], GEOGRAPHY_NAME = paste("Area", idx),
      OBS_VALUE = pop[idx], RECORD_OFFSET = idx - 1L, RECORD_COUNT = length(codes)
    )
    paste(c(
      "GEOGRAPHY_CODE,GEOGRAPHY_NAME,OBS_VALUE,RECORD_OFFSET,RECORD_COUNT",
      apply(body, 1, paste, collapse = ",")
    ), collapse = "\n")
  }
  list(codes = codes, pop = pop, handler = handler)
}

# Populate a cache directory through the fake server and return the table.
fetch_fake_population <- function(dir, fake) {
  with_mocked_bindings(
    lamp_population("lsoa21", dir = dir),
    lamp_http_get_text = fake$handler
  )
}

test_that("population is fetched in pages, cached and aggregated", {
  dir <- withr::local_tempdir()
  fake <- fake_nomis(page = 20000L)
  pop <- fetch_fake_population(dir, fake)
  expect_named(pop, c("area", "name", "population"))
  expect_equal(nrow(pop), length(fake$codes))
  expect_equal(pop$area, fake$codes)
  expect_equal(pop$population, fake$pop)
  expect_equal(attr(pop, "area"), "lsoa21")
  src <- attr(pop, "source")
  expect_equal(src$dataset, "NM_2021_1")
  expect_equal(src$census, "2021")
  expect_s3_class(src$retrieved, "POSIXct")
  expect_true(file.exists(lamp_population_cache(dir)))

  # further levels come from the cache without any network access
  withr::local_envvar(STREETLAMP_OFFLINE = "true")
  lk <- lamp_area_lookup()
  msoa <- lamp_population("msoa21", dir = dir)
  expect_equal(nrow(msoa), length(unique(lk$msoa21)))
  expect_equal(sum(msoa$population), sum(pop$population))
  expect_true(all(is.na(msoa$name)))
  one <- lk$msoa21[1]
  expect_equal(
    msoa$population[msoa$area == one],
    sum(pop$population[pop$area %in% lk$lsoa21[lk$msoa21 == one]])
  )
  pfa <- lamp_population("pfa", dir = dir)
  expect_equal(nrow(pfa), length(unique(lk$pfa)))
  expect_equal(sum(pfa$population), sum(pop$population))
  lad <- lamp_population("lad", dir = dir)
  expect_equal(nrow(lad), length(unique(lk$lad22)))
  old <- lamp_population("lsoa11", dir = dir)
  expect_equal(nrow(old), length(lamp_lsoa_codes("lsoa11")))
  expect_equal(sum(old$population), sum(pop$population))
  expect_match(attr(old, "source")$aggregation, "lsoa11")
  expect_equal(nrow(lamp_population("lsoa21", dir = dir)), length(fake$codes))
})

test_that("population falls back to the cache offline and fails without one", {
  dir <- withr::local_tempdir()
  fake <- fake_nomis()
  fetch_fake_population(dir, fake)
  withr::local_envvar(STREETLAMP_OFFLINE = "true")
  expect_warning(
    again <- lamp_population("lsoa21", dir = dir, refresh = TRUE),
    class = "streetlamp_warning_network"
  )
  expect_equal(nrow(again), length(fake$codes))
  expect_error(lamp_population("lsoa21", dir = withr::local_tempdir()), class = "streetlamp_error_network")
})

test_that("population feeds the panel's stop rate", {
  dir <- withr::local_tempdir()
  pop <- fetch_fake_population(dir, fake_nomis())
  cache <- local_fixture_cache()
  crime <- lamp_read_crime(cache, forces = "dyfed-powys", months = "2026-07")
  areas <- sort(unique(crime$lsoa_code[!is.na(crime$lsoa_code)]))
  user <- tibble::tibble(area = areas, month = as.Date("2026-07-01"), stops = 10L)
  panel <- lamp_panel(crime, stops = user, population = pop, areas = areas)
  expect_false(anyNA(panel$population))
  expect_equal(panel$stop_rate, 1000 * 10 / panel$population)
  expect_equal(lamp_contract(panel)$population$dataset, "NM_2021_1")
  expect_error(lamp_panel(crime, population = lamp_population("lad", dir = dir), areas = areas), class = "streetlamp_error_input")
})

test_that("malformed NOMIS responses are reported", {
  dir <- withr::local_tempdir()
  expect_error(
    with_mocked_bindings(
      lamp_population("lsoa21", dir = dir),
      lamp_http_get_text = function(url, call = NULL) "A,B\n1,2"
    ),
    class = "streetlamp_error_network"
  )
  expect_error(
    with_mocked_bindings(
      lamp_population("lsoa21", dir = dir),
      lamp_http_get_text = function(url, call = NULL) {
        "GEOGRAPHY_CODE,GEOGRAPHY_NAME,OBS_VALUE,RECORD_OFFSET,RECORD_COUNT\nE01000001,A,5,0,3"
      }
    ),
    class = "streetlamp_error_network"
  )
})

test_that("member names parse into month, force and file type", {
  p <- lamp_parse_members(c(
    "2026-07/2026-07-west-yorkshire-street.csv",
    "2026-05/2026-05-dyfed-powys-stop-and-search.csv",
    "2026-07/2026-07-city-of-london-outcomes.csv",
    "README.txt",
    "2026-07/2026-06-west-yorkshire-street.csv"
  ))
  expect_equal(p$month, as.Date(c("2026-07-01", "2026-05-01", "2026-07-01", NA, NA)))
  expect_equal(p$force_id, c("west-yorkshire", "dyfed-powys", "city-of-london", NA, NA))
  expect_equal(p$file_type, c("street", "stop-and-search", "outcomes", NA, NA))
})

test_that("month arguments are normalised", {
  expect_equal(lamp_as_months(c("2026-05", "2026-06-15")), as.Date(c("2026-05-01", "2026-06-01")))
  expect_equal(lamp_as_months(as.Date("2026-05-20")), as.Date("2026-05-01"))
  expect_null(lamp_as_months(NULL))
  expect_error(lamp_as_months("May 2026"), class = "streetlamp_error_input")
  expect_equal(lamp_parse_month_label(c("Aug 2023", "Dec 2010", "bad")), as.Date(c("2023-08-01", "2010-12-01", NA)))
})

test_that("the archive index page is parsed", {
  idx <- lamp_parse_archive_index(fixture_index_html())
  expect_s3_class(idx, "lamp_archive_index")
  expect_named(idx, c("archive", "label", "url", "from", "to", "n_months", "size_gb", "md5"))
  expect_equal(idx$archive, c("2026-07", "2026-06", "2017-04", "2013-12"))
  expect_equal(idx$from[1], as.Date("2023-08-01"))
  expect_equal(idx$to[1], as.Date("2026-07-01"))
  expect_equal(idx$n_months, c(36L, 36L, 77L, 37L))
  expect_equal(idx$size_gb, c(1.6, 1.6, 2.4, 0.884))
  expect_equal(idx$md5[1], "295d5eef6b58f28da80205235ba54745")
  expect_equal(idx$url[1], "https://data.police.uk/data/archive/2026-07.zip")
  expect_error(lamp_parse_archive_index("<html></html>"), class = "streetlamp_error_network")
})

test_that("lamp_archive_index() caches and falls back to the cache offline", {
  dir <- withr::local_tempdir()
  html <- fixture_index_html()
  idx <- with_mocked_bindings(
    lamp_archive_index(dir = dir),
    lamp_http_get_text = function(url, call = NULL) html
  )
  expect_equal(nrow(idx), 4L)
  expect_true(file.exists(file.path(dir, "archive", "index.rds")))
  expect_s3_class(attr(idx, "fetched_at"), "POSIXct")

  withr::local_envvar(STREETLAMP_OFFLINE = "true")
  expect_equal(lamp_archive_index(dir = dir)$archive, idx$archive)
  expect_warning(
    again <- lamp_archive_index(refresh = TRUE, dir = dir),
    class = "streetlamp_warning_network"
  )
  expect_equal(again$archive, idx$archive)
  empty <- withr::local_tempdir()
  expect_error(lamp_archive_index(dir = empty), class = "streetlamp_error_network")
})

test_that("network helpers fail gracefully when offline", {
  withr::local_envvar(STREETLAMP_OFFLINE = "true")
  expect_error(lamp_http_get_text("https://data.police.uk/data/archive/"), class = "streetlamp_error_network")
  expect_error(lamp_http_head("https://data.police.uk/data/archive/2026-07.zip"), class = "streetlamp_error_network")
  expect_error(lamp_http_range("https://data.police.uk/data/archive/2026-07.zip", 0, 3), class = "streetlamp_error_network")
  expect_error(lamp_zip_source("https://data.police.uk/data/archive/2026-07.zip"), class = "streetlamp_error_network")
})

test_that("network helpers fail gracefully without internet", {
  skip_if_not_installed("httptest2")
  withr::local_envvar(STREETLAMP_OFFLINE = "false")
  httptest2::without_internet({
    expect_error(lamp_http_get_text("https://data.police.uk/data/archive/"), class = "streetlamp_error_network")
    expect_error(lamp_http_head("https://data.police.uk/data/archive/2026-07.zip"), class = "streetlamp_error_network")
    dir <- withr::local_tempdir()
    expect_error(lamp_archive_index(dir = dir), class = "streetlamp_error_network")
    expect_error(lamp_archive_download("2026-07", dir = dir), class = "streetlamp_error_network")
  })
})

test_that("registered zips produce a snapshot with every member available", {
  dir <- local_fixture_cache()
  snap <- lamp_archive_snapshot(dir)
  expect_s3_class(snap, "lamp_snapshot")
  expect_equal(snap$archives$archive, c("2026-06", "2026-07"))
  expect_equal(snap$archives$kind, c("local", "local"))
  m <- snap$members
  expect_true(all(m$available))
  expect_true(all(is.na(m$path)))
  expect_setequal(unique(m$force_id), c("west-yorkshire", "dyfed-powys"))
  expect_setequal(unique(m$file_type), c("street", "outcomes", "stop-and-search"))
  expect_equal(range(m$month), as.Date(c("2026-05-01", "2026-07-01")))
  expect_message(print(snap), "archive")
})

test_that("registering a badly named zip is refused", {
  dir <- withr::local_tempdir()
  bad <- file.path(dir, "archive.zip")
  file.copy(fixture_zips()[1], bad)
  expect_error(lamp_archive_register(bad, dir = dir), class = "streetlamp_error_input")
  expect_message(lamp_archive_register(fixture_zips()[1], dir = dir), class = "streetlamp_message_archive")
})

test_that("an empty cache gives an empty snapshot and readers explain", {
  dir <- withr::local_tempdir()
  snap <- lamp_archive_snapshot(dir)
  expect_equal(nrow(snap$archives), 0L)
  expect_equal(nrow(snap$members), 0L)
  expect_message(print(snap), "No archives")
  expect_error(lamp_read_crime(dir), class = "streetlamp_error_input")
})

test_that("selective download fetches only the wanted files and records them", {
  local_mock_archive_network()
  dir <- withr::local_tempdir()
  idx <- lamp_parse_archive_index(fixture_index_html())
  expect_message(
    snap <- lamp_archive_download(
      archives = "2026-07", months = "2026-07", forces = "dyfed-powys",
      dir = dir, index = idx
    ),
    class = "streetlamp_message_archive"
  )
  expect_s3_class(snap, "lamp_snapshot")
  expect_equal(snap$archives$kind, "remote")
  expect_equal(snap$archives$md5, idx$md5[idx$archive == "2026-07"])
  m <- snap$members
  fetched <- m[m$available, ]
  expect_equal(unique(fetched$force_id), "dyfed-powys")
  expect_equal(unique(fetched$month), as.Date("2026-07-01"))
  expect_setequal(fetched$file_type, c("street", "outcomes"))
  expect_true(all(file.exists(fetched$path)))
  expect_true(all(grepl("^[0-9a-f]{64}$", fetched$sha256)))
  expect_true(any(!m$available))
  manifest <- lamp_read_manifest(file.path(dir, "archive"), "2026-07")
  expect_equal(nrow(manifest), 2L)

  # a second call finds everything cached and fetches nothing
  expect_message(
    lamp_archive_download(archives = "2026-07", months = "2026-07", forces = "dyfed-powys", dir = dir, index = idx),
    "already cached"
  )
  # files not fetched are skipped with a message, refused when nothing is
  # available, and fetched on demand with fetch = TRUE
  expect_message(
    partial <- lamp_read_crime(dir, months = "2026-07"),
    class = "streetlamp_message_archive"
  )
  expect_equal(unique(partial$force_id), "dyfed-powys")
  expect_error(
    lamp_read_crime(dir, forces = "west-yorkshire", months = "2026-07"),
    class = "streetlamp_error_input"
  )
  crime <- lamp_read_crime(dir, forces = "west-yorkshire", months = "2026-07", fetch = TRUE)
  expect_gt(nrow(crime), 0L)
  expect_true(lamp_archive_snapshot(dir)$members$available[
    lamp_archive_snapshot(dir)$members$member == "2026-07/2026-07-west-yorkshire-street.csv"
  ])
})

test_that("download resolves 'latest' from the index and validates arguments", {
  local_mock_archive_network()
  dir <- withr::local_tempdir()
  idx <- lamp_parse_archive_index(fixture_index_html())
  snap <- suppressMessages(lamp_archive_download(
    archives = "latest", months = "2026-07", forces = "dyfed-powys",
    file_types = "street", dir = dir, index = idx
  ))
  expect_equal(snap$archives$archive, "2026-07")
  expect_equal(unique(snap$members$file_type[snap$members$available]), "street")
  expect_error(lamp_archive_download(archives = "July 2026", dir = dir), class = "streetlamp_error_input")
  expect_error(lamp_archive_download(archives = "2026-07", forces = 1, dir = dir), class = "streetlamp_error_input")
  expect_error(lamp_archive_download(archives = "2026-07", file_types = "stops", dir = dir), class = "rlang_error")
})

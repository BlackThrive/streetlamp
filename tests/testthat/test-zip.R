test_that("the central directory reader agrees with unzip on a local zip", {
  zip <- fixture_zips()[1]
  src <- lamp_zip_source(zip)
  expect_equal(src$kind, "local")
  dir <- lamp_zip_directory(src)
  expect_s3_class(dir, "tbl_df")
  expect_named(dir, c("member", "method", "crc32", "csize", "usize", "offset", "mtime"))
  ref <- utils::unzip(zip, list = TRUE)
  expect_setequal(dir$member, ref$Name)
  expect_equal(dir$usize[match(ref$Name, dir$member)], ref$Length)
  expect_true(all(dir$method == 8))
  expect_true(all(grepl("^[0-9a-f]{8}$", dir$crc32)))
  expect_s3_class(dir$mtime, "POSIXct")
})

test_that("member extraction reproduces the bytes unzip produces", {
  zip <- fixture_zips()[1]
  src <- lamp_zip_source(zip)
  dir <- lamp_zip_directory(src)
  entry <- dir[grepl("dyfed-powys-street", dir$member), ][1, ]
  bytes <- lamp_zip_extract(src, entry)
  tmp <- withr::local_tempdir()
  utils::unzip(zip, files = entry$member, exdir = tmp)
  ref <- readBin(file.path(tmp, entry$member), what = "raw", n = entry$usize + 10)
  expect_identical(bytes, ref)
})

test_that("a tampered checksum is detected on extraction", {
  zip <- fixture_zips()[1]
  src <- lamp_zip_source(zip)
  dir <- lamp_zip_directory(src)
  entry <- dir[1, ]
  entry$crc32 <- "00000000"
  expect_error(lamp_zip_extract(src, entry), class = "streetlamp_error_input")
})

test_that("non-zip input is rejected", {
  tmp <- withr::local_tempfile(fileext = ".zip")
  writeBin(as.raw(rep(0L, 5000)), tmp)
  expect_error(lamp_zip_directory(lamp_zip_source(tmp)), class = "streetlamp_error_input")
  expect_error(lamp_zip_source(file.path(tempdir(), "nope.zip")), class = "streetlamp_error_input")
})

test_that("a remote source read by byte ranges lists the same members", {
  local_mock_archive_network()
  zip <- fixture_zips()[1]
  url <- paste0("https://data.police.uk/data/archive/", basename(zip))
  remote <- lamp_zip_source(url)
  expect_equal(remote$kind, "remote")
  expect_equal(remote$size, file.size(zip))
  dir_remote <- lamp_zip_directory(remote)
  dir_local <- lamp_zip_directory(lamp_zip_source(zip))
  expect_equal(dir_remote, dir_local)
  entry <- dir_remote[1, ]
  expect_identical(lamp_zip_extract(remote, entry), lamp_zip_extract(lamp_zip_source(zip), entry))
})

test_that("byte helpers round-trip", {
  expect_equal(zip_hex32(0), "00000000")
  expect_equal(zip_hex32(4294967295), "ffffffff")
  expect_equal(zip_hex32(305419896), "12345678")
  expect_identical(zip_le_bytes(258, 4), as.raw(c(2, 1, 0, 0)))
  expect_equal(zip_u32(as.raw(c(0x78, 0x56, 0x34, 0x12)), 1), 305419896)
  expect_equal(zip_u16(as.raw(c(0x01, 0x02)), 1), 513)
  expect_equal(format(zip_dos_datetime(0x5B21, 0x7E5A), "%Y-%m-%d %H:%M:%S"), "2025-09-01 15:50:52")
})

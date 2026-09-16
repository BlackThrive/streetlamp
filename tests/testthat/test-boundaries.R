# A fake ONS FeatureServer: unit squares on a grid, served as GeoJSON pages in
# British National Grid.
fake_feature_server <- function(codes, code_field, name_field, page = 2L) {
  square <- function(i) {
    x0 <- 400000 + (i - 1) * 1000
    sprintf(
      "{\"type\":\"Feature\",\"properties\":{\"%s\":\"%s\",\"%s\":\"Area %d\"},\"geometry\":{\"type\":\"Polygon\",\"coordinates\":[[[%d,200000],[%d,200000],[%d,201000],[%d,201000],[%d,200000]]]}}",
      code_field, codes[i], name_field, i, x0, x0 + 1000, x0 + 1000, x0, x0
    )
  }
  function(url, call = NULL) {
    offset <- as.integer(sub(".*resultOffset=([0-9]+).*", "\\1", url))
    idx <- seq_along(codes)
    idx <- idx[idx > offset & idx <= offset + page]
    more <- if (length(idx) > 0L && max(idx) < length(codes)) {
      ",\"properties\":{\"exceededTransferLimit\":true}"
    } else {
      ""
    }
    paste0(
      "{\"type\":\"FeatureCollection\",\"crs\":{\"type\":\"name\",\"properties\":{\"name\":\"EPSG:27700\"}},\"features\":[",
      paste(vapply(idx, square, character(1)), collapse = ","),
      "]", more, "}"
    )
  }
}

test_that("boundaries are fetched page by page, cached and returned as sf", {
  dir <- withr::local_tempdir()
  codes <- c("E23000003", "E23000001", "E23000002", "W15000001", "E23000004")
  server <- fake_feature_server(codes, "PFA23CD", "PFA23NM", page = 2L)
  expect_warning(
    pfa <- with_mocked_bindings(lamp_boundaries("pfa", dir = dir), lamp_http_get_text = server),
    class = "streetlamp_warning_network"
  )
  expect_s3_class(pfa, "sf")
  expect_named(pfa, c("area", "name", "geometry"))
  expect_equal(pfa$area, sort(codes))
  expect_equal(sf::st_crs(pfa)$epsg, 27700L)
  expect_equal(as.numeric(sf::st_area(pfa)[1]), 1e6)
  expect_equal(attr(pfa, "vintage"), "pfa-bgc")
  expect_equal(attr(pfa, "product")$item, "4b6a51a4fc8a40ad89d24dd895808e89")
  expect_s3_class(attr(pfa, "retrieved"), "POSIXct")
  expect_true(file.exists(lamp_boundaries_cache(dir, "pfa")))

  # cached copy serves offline; refresh without network warns and uses it
  withr::local_envvar(STREETLAMP_OFFLINE = "true")
  again <- lamp_boundaries("pfa", dir = dir)
  expect_equal(again$area, sort(codes))
  expect_warning(lamp_boundaries("pfa", dir = dir, refresh = TRUE), class = "streetlamp_warning_network")
  expect_error(lamp_boundaries("pfa", dir = withr::local_tempdir()), class = "streetlamp_error_network")
  expect_error(lamp_boundaries("wards", dir = dir), class = "rlang_error")

  adj <- lamp_adjacency(again)
  expect_equal(adj$boundary_vintage, "pfa-bgc")
  expect_equal(adj$n_islands, 0L)
})

test_that("the boundary request asks for British National Grid GeoJSON pages", {
  p <- lamp_boundary_products()[["lsoa21"]]
  url <- lamp_boundary_url(p, 4000L)
  expect_match(url, "outSR=27700", fixed = TRUE)
  expect_match(url, "f=geojson", fixed = TRUE)
  expect_match(url, "resultOffset=4000", fixed = TRUE)
  expect_match(url, "resultRecordCount=2000", fixed = TRUE)
  expect_match(url, "outFields=LSOA21CD%2CLSOA21NM", fixed = TRUE)
  lad <- lamp_boundary_url(lamp_boundary_products()[["lad"]], 0L)
  expect_match(lad, "LIKE", fixed = TRUE)
  products <- lamp_boundary_products()
  expect_named(products, c("lsoa21", "lsoa11", "msoa21", "lad", "pfa"))
  expect_true(all(vapply(products, function(x) grepl("^https://services1\\.arcgis\\.com/", x$service), logical(1))))
})

test_that("bad pages and duplicated codes are reported", {
  dir <- withr::local_tempdir()
  expect_error(
    with_mocked_bindings(
      lamp_boundaries("pfa", dir = dir),
      lamp_http_get_text = function(url, call = NULL) "<html>not json</html>"
    ),
    class = "streetlamp_error_network"
  )
  dup <- fake_feature_server(c("E23000001", "E23000001"), "PFA23CD", "PFA23NM", page = 5L)
  expect_error(
    with_mocked_bindings(lamp_boundaries("pfa", dir = dir), lamp_http_get_text = dup),
    class = "streetlamp_error_network"
  )
  empty <- function(url, call = NULL) "{\"type\":\"FeatureCollection\",\"features\":[]}"
  expect_error(
    with_mocked_bindings(lamp_boundaries("pfa", dir = dir), lamp_http_get_text = empty),
    class = "streetlamp_error_network"
  )
})

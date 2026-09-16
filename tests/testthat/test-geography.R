test_that("re-vintaging maps 2011 codes to their best-fit 2021 LSOA", {
  lk <- lamp_lsoa_lookup()
  unchanged <- lk$lsoa11[lk$change == "U"][1:3]
  split_parent <- lk$lsoa11[lk$change == "S"][1]
  merged_parent <- lk$lsoa11[lk$change == "M"][1]
  r <- lamp_revintage(c(unchanged, split_parent, merged_parent, "E01999999", NA), from = "lsoa11", to = "lsoa21")
  expect_equal(r$codes[1:3], unchanged)
  expect_true(!is.na(r$codes[4]) && r$codes[4] %in% lk$lsoa21[lk$lsoa11 == split_parent])
  expect_true(!is.na(r$codes[5]))
  expect_true(is.na(r$codes[6]))
  expect_true(is.na(r$codes[7]))
  s <- r$summary
  expect_equal(s$n_records, 6L)
  expect_equal(s$n_records_mapped, 5L)
  expect_equal(s$n_areas, 6L)
  expect_equal(s$n_areas_unmatched, 1L)
  expect_equal(s$areas_unchanged, 3L)
  expect_equal(s$areas_split, 1L)
  expect_equal(s$areas_merged, 1L)
  expect_equal(s$share_split_or_merged, 2 / 6)
})

test_that("re-vintaging 2021 codes to 2011 uses one parent per code", {
  lk <- lamp_lsoa_lookup()
  child <- lk$lsoa21[lk$change == "S"][1]
  merged <- lk$lsoa21[lk$change == "M"][1]
  r <- lamp_revintage(c(child, merged), from = "lsoa21", to = "lsoa11")
  expect_equal(r$codes[1], lk$lsoa11[lk$lsoa21 == child])
  parents <- sort(lk$lsoa11[lk$lsoa21 == merged])
  expect_equal(r$codes[2], parents[1])
  expect_equal(r$summary$areas_merged, 1L)
  same <- lamp_revintage(c("E01000001"), from = "lsoa21", to = "lsoa21")
  expect_equal(same$codes, "E01000001")
  expect_null(same$summary)
  expect_error(lamp_revintage(1:3), class = "streetlamp_error_input")
})

test_that("queen, rook and knn adjacency are built from polygons", {
  square <- function(x0, y0, id) {
    sf::st_sf(
      area = id,
      geometry = sf::st_sfc(sf::st_polygon(list(rbind(
        c(x0, y0), c(x0 + 1, y0), c(x0 + 1, y0 + 1), c(x0, y0 + 1), c(x0, y0)
      ))), crs = 27700)
    )
  }
  # a: touches b along an edge and c at a corner; d is an island far away
  polys <- rbind(square(0, 0, "a"), square(1, 0, "b"), square(1, 1, "c"), square(10, 10, "d"))
  queen <- lamp_adjacency(polys)
  expect_s3_class(queen, "lamp_adjacency")
  expect_equal(queen$areas, c("a", "b", "c", "d"))
  expect_equal(queen$method, "queen")
  expect_equal(queen$n_islands, 1L)
  expect_setequal(queen$areas[queen$nb[[1]]], c("b", "c"))
  expect_s3_class(queen$listw, "listw")
  expect_message(print(queen), "queen")

  rook <- lamp_adjacency(polys, method = "rook")
  expect_equal(rook$areas[rook$nb[[1]]], "b")
  expect_equal(rook$n_islands, 1L)

  knn <- lamp_adjacency(polys, method = "knn", k = 1)
  expect_equal(knn$k, 1L)
  expect_equal(knn$n_islands, 0L)
  expect_true(all(spdep::card(knn$nb) >= 1L))

  attr(polys, "vintage") <- "lsoa21-bgc"
  expect_equal(lamp_adjacency(polys)$boundary_vintage, "lsoa21-bgc")
  expect_error(lamp_adjacency(data.frame(area = "a")), class = "streetlamp_error_input")
  expect_error(lamp_adjacency(polys, k = 0), class = "streetlamp_error_input")
  dup <- rbind(polys, square(3, 3, "a"))
  expect_error(lamp_adjacency(dup), class = "streetlamp_error_input")
})

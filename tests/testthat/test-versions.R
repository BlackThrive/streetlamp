test_that("versions are listed per force, month and file type", {
  dir <- local_fixture_cache()
  snap <- lamp_archive_snapshot(dir)
  v <- lamp_list_versions(snap)
  expect_s3_class(v, "lamp_versions")
  expect_named(v, c(
    "force_id", "month", "file_type", "n_versions", "archives", "crc32",
    "differs", "usize_min", "usize_max", "n_available"
  ))
  shared <- v[v$month < as.Date("2026-07-01"), ]
  expect_true(all(shared$n_versions == 2L))
  july <- v[v$month == as.Date("2026-07-01"), ]
  expect_true(all(july$n_versions == 1L))
  expect_true(all(july$archives == "2026-07"))
  expect_true(any(shared$differs))
  expect_true(all(v$n_available == v$n_versions))
  expect_true(all(vapply(v$archives, function(a) !is.unsorted(a), logical(1))))
  only_street <- lamp_list_versions(snap, file_types = "street")
  expect_equal(unique(only_street$file_type), "street")
  expect_error(lamp_list_versions(snap$members), class = "streetlamp_error_input")
})

test_that("one version is selected per file and alternatives are kept", {
  dir <- local_fixture_cache()
  v <- lamp_list_versions(lamp_archive_snapshot(dir))
  latest <- lamp_select_version(v)
  expect_s3_class(latest, "lamp_selection")
  expect_equal(nrow(latest), nrow(v))
  expect_true(all(latest$archive[latest$n_versions == 2L] == "2026-07"))
  expect_equal(unique(latest$rule), "latest")
  alt <- latest$alternatives[latest$n_versions == 2L][[1]]
  expect_named(alt, c("archive", "crc32"))
  expect_equal(alt$archive, "2026-06")
  expect_equal(nrow(latest$alternatives[latest$n_versions == 1L][[1]]), 0L)

  earliest <- lamp_select_version(v, rule = "earliest")
  expect_true(all(earliest$archive[earliest$n_versions == 2L] == "2026-06"))
  preferred <- lamp_select_version(v, prefer = "2026-06")
  expect_true(all(preferred$archive[preferred$n_versions == 2L] == "2026-06"))
  expect_true(all(preferred$archive[preferred$n_versions == 1L] == "2026-07"))
  expect_error(lamp_select_version(v, rule = "newest"), class = "rlang_error")
  expect_error(lamp_select_version(v$archives), class = "streetlamp_error_input")
})

test_that("a force-month with different counts across archives is reported", {
  dir <- local_fixture_cache()
  snap <- lamp_archive_snapshot(dir)
  d <- lamp_version_diff(snap, "west-yorkshire", "2026-05", "outcomes")
  expect_named(d, c("archive", "n_rows", "n_ids", "ids_not_in_others", "crc32"))
  expect_equal(d$archive, c("2026-06", "2026-07"))
  expect_gt(d$n_rows[1], d$n_rows[2])
  expect_gt(d$ids_not_in_others[1], 0L)
  expect_equal(d$ids_not_in_others[2], 0L)

  s <- lamp_version_diff(snap, "dyfed-powys", "2026-05", "street")
  expect_equal(s$n_rows[1], s$n_rows[2])
  expect_gt(attr(s, "outcome_changes"), 0L)

  st <- lamp_version_diff(snap, "west-yorkshire", "2026-06", "stop-and-search")
  expect_true(all(is.na(st$n_ids)))
  expect_error(lamp_version_diff(snap, "dyfed-powys", "2026-07", "stop-and-search"), class = "streetlamp_error_input")
})

test_that("readers honour an explicit version selection", {
  dir <- local_fixture_cache()
  snap <- lamp_archive_snapshot(dir)
  v <- lamp_list_versions(snap)
  old <- lamp_read_outcomes(snap,
    versions = lamp_select_version(v, rule = "earliest"),
    forces = "west-yorkshire", months = "2026-05"
  )
  new <- lamp_read_outcomes(snap, forces = "west-yorkshire", months = "2026-05")
  expect_equal(unique(old$archive), "2026-06")
  expect_equal(unique(new$archive), "2026-07")
  expect_gt(nrow(old), nrow(new))
  expect_equal(lamp_contract(old)$versions$rule, "earliest")
})

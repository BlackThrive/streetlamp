test_that("cache directory honours the option and can be cleared", {
  tmp <- withr::local_tempdir()
  target <- file.path(tmp, "opt")
  withr::local_options(streetlamp.cache_dir = target)

  expect_false(dir.exists(target))
  expect_equal(lamp_cache_dir(create = FALSE), target)
  expect_false(dir.exists(target))
  expect_equal(lamp_cache_dir(), target)
  expect_true(dir.exists(target))

  writeLines("x", file.path(target, "a.txt"))
  expect_message(lamp_cache_clear(), class = "streetlamp_message_cache")
  expect_false(dir.exists(target))
  expect_message(lamp_cache_clear(), "Nothing to clear")
})

test_that("cache directory honours the environment variable", {
  tmp <- withr::local_tempdir()
  target <- file.path(tmp, "env")
  withr::local_options(streetlamp.cache_dir = NULL)
  withr::local_envvar(STREETLAMP_CACHE_DIR = target)
  expect_equal(lamp_cache_dir(create = FALSE), target)
  expect_false(dir.exists(target))
})

test_that("default cache directory is the R user cache directory", {
  withr::local_options(streetlamp.cache_dir = NULL)
  withr::local_envvar(STREETLAMP_CACHE_DIR = NA)
  expect_equal(
    lamp_cache_dir(create = FALSE),
    tools::R_user_dir("streetlamp", which = "cache")
  )
})

test_that("a sub-directory of the cache can be cleared on its own", {
  tmp <- withr::local_tempdir()
  withr::local_options(streetlamp.cache_dir = tmp)
  dir.create(file.path(tmp, "archive"))
  dir.create(file.path(tmp, "boundaries"))
  writeLines("x", file.path(tmp, "archive", "a.zip"))
  expect_message(lamp_cache_clear("archive"), "1 file")
  expect_false(dir.exists(file.path(tmp, "archive")))
  expect_true(dir.exists(file.path(tmp, "boundaries")))
})

test_that("cache helpers validate their input", {
  expect_error(lamp_cache_dir(create = "yes"), class = "streetlamp_error_input")
  expect_error(lamp_cache_clear(subdir = 1), class = "streetlamp_error_input")
})

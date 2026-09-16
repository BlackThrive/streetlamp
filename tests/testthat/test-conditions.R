test_that("errors carry package and specific classes", {
  expect_error(lamp_abort("boom", "input"), class = "streetlamp_error_input")
  expect_error(lamp_abort("boom", "input"), class = "streetlamp_error")
  expect_error(lamp_abort("boom", "contract"), class = "streetlamp_error_contract")
  err <- tryCatch(lamp_abort("boom", "input", x = 1), error = identity)
  expect_s3_class(err, "rlang_error")
  expect_equal(err$x, 1)
})

test_that("warnings and messages carry package and specific classes", {
  expect_warning(lamp_warn("careful", "coverage"),
    class = "streetlamp_warning_coverage"
  )
  expect_warning(lamp_warn("careful", "coverage"), class = "streetlamp_warning")
  expect_message(lamp_inform("fyi"), class = "streetlamp_message")
  expect_message(lamp_inform("fyi", class = "cache"),
    class = "streetlamp_message_cache"
  )
})

test_that("argument checkers accept valid input and reject the rest", {
  expect_identical(check_string("a"), "a")
  expect_identical(check_bool(TRUE), TRUE)
  expect_error(check_string(1), class = "streetlamp_error_input")
  expect_error(check_string(c("a", "b")), class = "streetlamp_error_input")
  expect_error(check_string(NA_character_), class = "streetlamp_error_input")
  expect_error(check_bool("a"), class = "streetlamp_error_input")
  expect_error(check_bool(NA), class = "streetlamp_error_input")
  expect_error(check_bool(c(TRUE, FALSE)), class = "streetlamp_error_input")
})

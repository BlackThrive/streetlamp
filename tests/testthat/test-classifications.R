test_that("crime types are the fourteen data.police.uk categories", {
  ct <- lamp_crime_types()
  expect_s3_class(ct, "tbl_df")
  expect_named(
    ct,
    c(
      "crime_type", "key", "api_slug", "is_asb", "in_crime_total", "group",
      "broad_group"
    )
  )
  expect_equal(nrow(ct), 14L)
  expect_setequal(
    ct$crime_type,
    c(
      "Anti-social behaviour", "Bicycle theft", "Burglary",
      "Criminal damage and arson", "Drugs", "Other crime", "Other theft",
      "Possession of weapons", "Public order", "Robbery", "Shoplifting",
      "Theft from the person", "Vehicle crime",
      "Violence and sexual offences"
    )
  )
  expect_equal(sum(ct$is_asb), 1L)
  expect_equal(ct$crime_type[ct$is_asb], "Anti-social behaviour")
  expect_equal(ct$in_crime_total, !ct$is_asb)
})

test_that("crime type keys and slugs are unique and machine friendly", {
  ct <- lamp_crime_types()
  expect_true(all(grepl("^[a-z][a-z_]*$", ct$key)))
  expect_false(anyDuplicated(ct$key) > 0L)
  expect_true(all(grepl("^[a-z][a-z-]*$", ct$api_slug)))
  expect_false(anyDuplicated(ct$api_slug) > 0L)
  expect_equal(
    ct$api_slug[ct$crime_type == "Violence and sexual offences"],
    "violent-crime"
  )
})

test_that("crime type groupings are complete and consistent", {
  ct <- lamp_crime_types()
  expect_false(anyNA(ct$group))
  expect_setequal(
    unique(ct$broad_group),
    c("asb", "violent", "acquisitive", "drugs", "damage", "other")
  )
  expect_equal(ct$broad_group[ct$is_asb], "asb")
  expect_equal(ct$group[ct$is_asb], "asb")
  theft <- ct$crime_type[ct$group == "theft"]
  expect_setequal(
    theft,
    c(
      "Bicycle theft", "Burglary", "Other theft", "Shoplifting",
      "Theft from the person", "Vehicle crime"
    )
  )
  expect_true(all(ct$broad_group[ct$group == "theft"] == "acquisitive"))
})

test_that("legacy labels map to a current category or NA", {
  lg <- lamp_legacy_crime_types()
  expect_named(lg, c("legacy_label", "crime_type", "note"))
  mapped <- lg$crime_type[!is.na(lg$crime_type)]
  expect_true(all(mapped %in% lamp_crime_types()$crime_type))
  split_label <- lg$legacy_label == "Public disorder and weapons"
  expect_true(is.na(lg$crime_type[split_label]))
  expect_equal(
    lg$crime_type[lg$legacy_label == "Violent crime"],
    "Violence and sexual offences"
  )
})

test_that("outcome types cover the 28 police.uk categories with six groups", {
  ot <- lamp_outcome_types()
  expect_s3_class(ot, "tbl_df")
  expect_named(ot, c("outcome_type", "code", "group", "is_court_outcome"))
  expect_equal(nrow(ot), 28L)
  expect_false(anyDuplicated(ot$outcome_type) > 0L)
  expect_false(anyDuplicated(ot$code) > 0L)
  expect_s3_class(ot$group, "factor")
  expect_equal(levels(ot$group), lamp_outcome_groups())
  expect_false(anyNA(ot$group))
  expect_type(ot$is_court_outcome, "logical")
})

test_that("outcome grouping places key categories where documented", {
  ot <- lamp_outcome_types()
  grp <- function(x) as.character(ot$group[ot$outcome_type == x])
  expect_equal(grp("Suspect charged"), "charged_or_summonsed")
  expect_equal(grp("Offender given a caution"), "out_of_court")
  expect_equal(grp("Local resolution"), "out_of_court")
  expect_equal(
    grp("Investigation complete; no suspect identified"),
    "no_suspect"
  )
  expect_equal(grp("Unable to prosecute suspect"), "evidential_difficulties")
  expect_equal(grp("Under investigation"), "unknown")
  expect_equal(grp("Status update unavailable"), "unknown")
  expect_equal(grp("Formal action is not in the public interest"), "other")
  # every court-supplied outcome sits at the charge stage
  expect_true(all(ot$group[ot$is_court_outcome] == "charged_or_summonsed"))
  expect_true(all(lamp_outcome_groups() %in% ot$group))
})

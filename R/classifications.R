#' Crime type classification used by data.police.uk
#'
#' data.police.uk assigns every record in the street-level files to one of
#' fourteen categories: anti-social behaviour plus thirteen crime types. This
#' table gives the labels exactly as they appear in the `Crime type` column of
#' the archive CSV files, a snake_case key used for panel columns, the slug used
#' by the police.uk API, and two package-defined groupings.
#'
#' @details
#' Anti-social behaviour (ASB) is not a crime: ASB incidents carry no Crime ID
#' and no outcome, so `is_asb` is `TRUE` and `in_crime_total` is `FALSE` for
#' that row and `lamp_panel()` keeps ASB in its own series.
#'
#' The category set was verified against the police.uk API and archive files
#' on 2026-09-16. It has been stable since the May 2013 data, when
#' data.police.uk introduced bicycle theft and theft from the person
#' (previously within other theft), split public disorder and weapons into
#' possession of weapons and public order, and renamed violent crime to
#' violence and sexual offences. Files for September 2011 to April 2013 use
#' eleven categories and files for December 2010 to August 2011 only six, with
#' a very broad other crime. `since` gives the first data month of each
#' current category; [lamp_read_crime()] maps legacy labels where the mapping
#' is one to one and keeps `Public disorder and weapons` as its own level.
#'
#' `group` follows the Home Office offence groups with the six theft
#' categories combined; `broad_group` collapses further into `violent`,
#' `acquisitive`, `drugs`, `damage`, `other` and `asb`. Both groupings are the
#' package's own and are documented here so that results by offence group can
#' be reproduced.
#'
#' @return A tibble with one row per category and columns `crime_type`,
#'   `key`, `api_slug`, `is_asb`, `in_crime_total`, `group` and `broad_group`.
#' @family bundled data
#' @seealso [lamp_outcome_types()]
#' @export
#' @examples
#' lamp_crime_types()
lamp_crime_types <- function() {
  tibble::tibble(
    crime_type = c(
      "Anti-social behaviour", "Bicycle theft", "Burglary",
      "Criminal damage and arson", "Drugs", "Other crime", "Other theft",
      "Possession of weapons", "Public order", "Robbery", "Shoplifting",
      "Theft from the person", "Vehicle crime",
      "Violence and sexual offences"
    ),
    key = c(
      "anti_social_behaviour", "bicycle_theft", "burglary",
      "criminal_damage_and_arson", "drugs", "other_crime", "other_theft",
      "possession_of_weapons", "public_order", "robbery", "shoplifting",
      "theft_from_the_person", "vehicle_crime",
      "violence_and_sexual_offences"
    ),
    api_slug = c(
      "anti-social-behaviour", "bicycle-theft", "burglary",
      "criminal-damage-arson", "drugs", "other-crime", "other-theft",
      "possession-of-weapons", "public-order", "robbery", "shoplifting",
      "theft-from-the-person", "vehicle-crime", "violent-crime"
    ),
    is_asb = c(TRUE, rep(FALSE, 13L)),
    in_crime_total = c(FALSE, rep(TRUE, 13L)),
    group = c(
      "asb", "theft", "theft", "criminal_damage_and_arson", "drugs", "other",
      "theft", "possession_of_weapons", "public_order", "robbery", "theft",
      "theft", "theft", "violence_and_sexual_offences"
    ),
    broad_group = c(
      "asb", "acquisitive", "acquisitive", "damage", "drugs", "other",
      "acquisitive", "violent", "violent", "violent", "acquisitive",
      "acquisitive", "acquisitive", "violent"
    ),
    since = as.Date(c(
      "2010-12-01", "2013-05-01", "2010-12-01", "2011-09-01", "2011-09-01",
      "2010-12-01", "2011-09-01", "2013-05-01", "2013-05-01", "2010-12-01",
      "2011-09-01", "2013-05-01", "2010-12-01", "2013-05-01"
    ))
  )
}

# Legacy labels used in street files before the May 2013 category change,
# verified against archive files on 2026-09-16: six categories from December
# 2010 to August 2011, eleven from September 2011 to April 2013. One-to-one
# renames are resolved by the reader; NA marks a category that was later
# split and cannot be mapped forward.
lamp_legacy_crime_types <- function() {
  tibble::tibble(
    legacy_label = c(
      "Violent crime", "Public disorder and weapons", "Other theft", "Other crime"
    ),
    crime_type = c(
      "Violence and sexual offences", NA_character_, "Other theft", "Other crime"
    ),
    from = as.Date(c("2010-12-01", "2011-09-01", "2011-09-01", "2010-12-01")),
    to = as.Date(c("2013-04-01", "2013-04-01", "2013-04-01", "2011-08-01")),
    note = c(
      "renamed Violence and sexual offences in May 2013",
      "split into Possession of weapons and Public order in May 2013",
      "included Bicycle theft and Theft from the person until April 2013",
      paste(
        "until August 2011 also held Criminal damage and arson, Drugs,",
        "Other theft, Shoplifting, Public disorder and weapons"
      )
    )
  )
}

#' Outcome classification used by data.police.uk
#'
#' The outcome categories that appear in the `Outcome type` column of the
#' outcomes files and the `Last outcome category` column of the street files,
#' with the police.uk API code and a package-defined grouping into six classes.
#'
#' @details
#' The grouping is the package's own:
#' * `charged_or_summonsed`: the suspect was charged or summonsed, including
#'   every subsequent court outcome supplied by the Ministry of Justice and
#'   offences taken into consideration (`Suspect charged as part of another
#'   case`).
#' * `out_of_court`: cautions, drugs possession warnings, penalty notices and
#'   community (local) resolutions.
#' * `no_suspect`: investigation complete with no suspect identified.
#' * `evidential_difficulties`: a suspect was identified but the police were
#'   unable to prosecute.
#' * `other`: action not in the public interest or taken by another body.
#' * `unknown`: still under investigation or no status update available.
#'
#' `is_court_outcome` marks the categories that come from court records rather
#' than from the police. data.police.uk reports that court outcomes from June
#' 2019 onwards are unavailable, so these categories are sparse after that
#' date and `charged_or_summonsed` should be read as the charge stage.
#'
#' The category list was verified against the police.uk API documentation and
#' against archive files on 2026-09-16. `outcome_type` is the string written
#' in the archive CSV files; where the API documentation names a category
#' differently (`Offender given penalty notice` appears there as `Offender
#' given a penalty notice`) the API name is kept in `api_name` and
#' [lamp_read_outcomes()] accepts either.
#'
#' @return A tibble with columns `outcome_type`, `api_name`, `code`, `group`
#'   (factor with the six levels above) and `is_court_outcome`.
#' @family bundled data
#' @seealso [lamp_crime_types()]
#' @export
#' @examples
#' lamp_outcome_types()
lamp_outcome_types <- function() {
  x <- tibble::tribble(
    ~outcome_type, ~code, ~group, ~is_court_outcome,
    "Awaiting court outcome", "awaiting-court-result",
    "charged_or_summonsed", TRUE,
    "Court result unavailable", "court-result-unavailable",
    "charged_or_summonsed", TRUE,
    "Court case unable to proceed", "unable-to-proceed",
    "charged_or_summonsed", TRUE,
    "Local resolution", "local-resolution",
    "out_of_court", FALSE,
    "Investigation complete; no suspect identified", "no-further-action",
    "no_suspect", FALSE,
    "Offender deprived of property", "deprived-of-property",
    "charged_or_summonsed", TRUE,
    "Offender fined", "fined",
    "charged_or_summonsed", TRUE,
    "Offender given absolute discharge", "absolute-discharge",
    "charged_or_summonsed", TRUE,
    "Offender given a caution", "cautioned",
    "out_of_court", FALSE,
    "Offender given a drugs possession warning", "drugs-possession-warning",
    "out_of_court", FALSE,
    "Offender given penalty notice", "penalty-notice-issued",
    "out_of_court", FALSE,
    "Offender given community sentence", "community-penalty",
    "charged_or_summonsed", TRUE,
    "Offender given conditional discharge", "conditional-discharge",
    "charged_or_summonsed", TRUE,
    "Offender given suspended prison sentence", "suspended-sentence",
    "charged_or_summonsed", TRUE,
    "Offender sent to prison", "imprisoned",
    "charged_or_summonsed", TRUE,
    "Offender otherwise dealt with", "other-court-disposal",
    "charged_or_summonsed", TRUE,
    "Offender ordered to pay compensation", "compensation",
    "charged_or_summonsed", TRUE,
    "Suspect charged as part of another case", "sentenced-in-another-case",
    "charged_or_summonsed", FALSE,
    "Suspect charged", "charged",
    "charged_or_summonsed", FALSE,
    "Defendant found not guilty", "not-guilty",
    "charged_or_summonsed", TRUE,
    "Defendant sent to Crown Court", "sent-to-crown-court",
    "charged_or_summonsed", TRUE,
    "Unable to prosecute suspect", "unable-to-prosecute",
    "evidential_difficulties", FALSE,
    "Formal action is not in the public interest",
    "formal-action-not-in-public-interest", "other", FALSE,
    "Action to be taken by another organisation",
    "action-taken-by-another-organisation", "other", FALSE,
    "Further investigation is not in the public interest",
    "further-investigation-not-in-public-interest", "other", FALSE,
    "Further action is not in the public interest",
    "further-action-not-in-public-interest", "other", FALSE,
    "Under investigation", "under-investigation",
    "unknown", FALSE,
    "Status update unavailable", "status-update-unavailable",
    "unknown", FALSE
  )
  x$group <- factor(x$group, levels = lamp_outcome_groups())
  # Name used by the police.uk API documentation where it differs from the
  # string written in the archive CSV files (verified 2026-09-16).
  x$api_name <- x$outcome_type
  x$api_name[x$outcome_type == "Offender given penalty notice"] <- "Offender given a penalty notice"
  x[, c("outcome_type", "api_name", "code", "group", "is_court_outcome")]
}

lamp_outcome_groups <- function() {
  c(
    "charged_or_summonsed", "out_of_court", "no_suspect",
    "evidential_difficulties", "other", "unknown"
  )
}

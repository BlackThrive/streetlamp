#' Police forces in the data.police.uk archive
#'
#' The 45 forces whose files appear in the archive: the 43 territorial forces
#' of England and Wales, the Police Service of Northern Ireland and British
#' Transport Police, with the identifier used in archive file names, the force
#' name as published by the police.uk API, and the ONS police force area code
#' (December 2025) where one exists.
#'
#' @details
#' British Transport Police has no police force area; its records carry
#' `British Transport Police` in the `Falls within` column rather than the
#' territorial force in whose area the offence occurred. Greater Manchester
#' Police has submitted no data since 2019 and is absent from recent archive
#' snapshots.
#'
#' Sources: <https://data.police.uk/api/forces> and the ONS Police Force Areas
#' (December 2025) Names and Codes in the United Kingdom, both retrieved
#' 2026-09-16; Open Government Licence v3.0.
#'
#' @return A tibble with columns `force_id`, `name`, `pfa_code`, `pfa_name`,
#'   `country` (`england`, `wales`, `northern_ireland` or `NA`) and `notes`.
#' @family bundled data
#' @export
#' @examples
#' lamp_forces()
lamp_forces <- function() {
  lamp_bundled("forces", function() {
    lamp_read_bundled_csv("forces.csv")
  })
}

# Reduce a force name to a comparable stem: lower case, "&" to "and", no
# hyphens or punctuation, and no organisational suffix. "Devon and Cornwall
# Police", "Dyfed Powys Police" and "Metropolitan Police" then match the
# police.uk names.
lamp_force_stem <- function(x) {
  x <- tolower(x)
  x <- gsub("&", " and ", x, fixed = TRUE)
  x <- gsub("[-']", " ", x)
  x <- gsub("[^a-z ]", "", x)
  x <- gsub("\\b(police service|constabulary|police|service)\\b", " ", x)
  x <- gsub("\\s+", " ", x)
  trimws(x)
}

# Map force names as written in archive files or the changelog to police.uk
# identifiers; NA when no stem matches.
lamp_force_id_from_name <- function(x) {
  f <- lamp_forces()
  stems <- lamp_force_stem(f$name)
  stems[f$force_id == "metropolitan"] <- "metropolitan"
  f$force_id[match(lamp_force_stem(x), stems)]
}

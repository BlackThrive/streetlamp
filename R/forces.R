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

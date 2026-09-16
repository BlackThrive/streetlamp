#' streetlamp: Panel Econometrics for the Effect of Police Stop and Search on
#' Recorded Crime
#'
#' @description
#' `streetlamp` builds an area-by-month panel of recorded crime in England and
#' Wales from the data.police.uk bulk archive, attaches stop and search
#' intensity as a treatment variable, and provides estimators for evaluating
#' policing interventions. It is about what stops achieve, not who is stopped:
#' it never computes an ethnic disparity measure and reads stop and search
#' files only to count stops by area and month.
#'
#' @section Design principles:
#' * Every panel carries a **panel contract** recording provenance, coverage,
#'   LSOA vintage and treatment definition. Estimators read it and refuse or
#'   warn when their assumptions are violated.
#' * "Force did not submit" is never a zero.
#' * Anti-social behaviour is not a crime: it is kept in a separate series and
#'   excluded from crime totals by default.
#' * Treatment effects are reported with the identifying assumption named in
#'   the output, and every estimator ships with a placebo or pre-trend
#'   diagnostic.
#' * No network access during `R CMD check`, tests or examples.
#'
#' @section Data attribution:
#' Recorded crime, outcomes and stop and search counts derive from
#' data.police.uk, and geography from the Office for National Statistics Open
#' Geography Portal, both published under the Open Government Licence v3.0.
#' Bank holidays derive from GOV.UK. See `inst/NOTES/data_sources.md` in the
#' package sources for what was verified and when.
#'
#' @keywords internal
"_PACKAGE"

## usethis namespace: start
#' @importFrom rlang %||%
#' @importFrom rlang .data
## usethis namespace: end
#' @importFrom tibble tibble
#' @importFrom sf st_crs
NULL

# The tibble and sf imports above are deliberate: they load those namespaces
# with the package, so that the print methods of contract-bearing tibbles and
# of bundled sf layers dispatch to tibble and sf even in a fresh session that
# has not yet called either package.

# Package-level environment for lazily loaded bundled tables.
the <- new.env(parent = emptyenv())

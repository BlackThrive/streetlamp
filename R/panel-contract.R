# The panel contract ---------------------------------------------------------------
#
# Every table that streetlamp produces from the archive carries a contract:
# a record of where the data came from, which archive version supplied each
# force-month, what was missing, which LSOA vintage the codes are in, and (for
# panels) how crime totals and treatment are defined. Estimators read the
# contract and refuse or warn when their assumptions are violated.

lamp_contract_fields <- function() {
  c(
    "source", "snapshots", "versions", "coverage", "geography", "population",
    "crime_scope", "stops", "treatment", "created"
  )
}

new_lamp_contract <- function(source = "data.police.uk archive", snapshots = NULL,
                              versions = NULL, coverage = NULL, geography = NULL,
                              population = NULL, crime_scope = NULL, stops = NULL,
                              treatment = NULL) {
  structure(
    list(
      source = source,
      snapshots = snapshots,
      versions = versions,
      coverage = coverage,
      geography = geography,
      population = population,
      crime_scope = crime_scope,
      stops = stops,
      treatment = treatment,
      created = list(
        timestamp = Sys.time(),
        package_version = as.character(utils::packageVersion("streetlamp")),
        r_version = R.version.string
      )
    ),
    class = "lamp_contract"
  )
}

validate_lamp_contract <- function(x, arg = rlang::caller_arg(x), call = rlang::caller_env()) {
  if (!inherits(x, "lamp_contract") || !is.list(x)) {
    lamp_abort("{.arg {arg}} is not a {.cls lamp_contract}.", "contract", call = call)
  }
  missing <- setdiff(lamp_contract_fields(), names(x))
  if (length(missing) > 0L) {
    lamp_abort(
      "{.arg {arg}} lacks the contract field{?s} {.field {missing}}.",
      "contract",
      call = call
    )
  }
  needed <- c("timestamp", "package_version", "r_version")
  if (!is.list(x$created) || !all(needed %in% names(x$created))) {
    lamp_abort("{.arg {arg}} has a malformed {.field created} record.", "contract", call = call)
  }
  invisible(x)
}

#' The panel contract
#'
#' Every table streetlamp derives from the archive carries a contract as an
#' attribute: the archive snapshots and versions it was built from, the
#' coverage status of every force-month, the LSOA vintage, the crime scope, the
#' stop-count definition and the treatment definition. `lamp_contract()`
#' returns it; the contract survives subsetting with `[` and dplyr verbs.
#'
#' @param x A table produced by a `lamp_read_*()` function or by
#'   `lamp_panel()`, or a contract.
#'
#' @return A list of class `lamp_contract` with elements `source`,
#'   `snapshots`, `versions`, `coverage`, `geography`, `population`,
#'   `crime_scope`, `stops`, `treatment` and `created`. Elements not yet
#'   applicable are `NULL`.
#' @family contract
#' @export
#' @examples
#' cache <- tempfile("streetlamp-cache-")
#' zip <- system.file("extdata", "archive", "2026-07.zip", package = "streetlamp")
#' lamp_archive_register(zip, dir = cache)
#' crime <- lamp_read_crime(cache, forces = "dyfed-powys")
#' contract <- lamp_contract(crime)
#' contract
#' contract$coverage
lamp_contract <- function(x) {
  if (inherits(x, "lamp_contract")) {
    return(validate_lamp_contract(x))
  }
  contract <- attr(x, "contract", exact = TRUE)
  if (is.null(contract)) {
    lamp_abort(
      c(
        "{.arg x} carries no panel contract.",
        "i" = "Contracts are attached by the {.fn lamp_read_crime} family and {.fn lamp_panel}."
      ),
      "contract"
    )
  }
  validate_lamp_contract(contract, arg = "x")
}

#' @export
print.lamp_contract <- function(x, ...) {
  cli::cli_h3("streetlamp contract")
  cli::cli_text("Source: {x$source}")
  if (!is.null(x$snapshots) && nrow(x$snapshots) > 0L) {
    cli::cli_text("Archives: {.val {x$snapshots$archive}}")
  }
  if (!is.null(x$coverage) && nrow(x$coverage) > 0L) {
    st <- table(x$coverage$status)
    parts <- paste0(names(st), " ", as.integer(st))
    cli::cli_text("Coverage (force-month files): {paste(parts, collapse = ', ')}")
  }
  if (!is.null(x$geography)) {
    g <- x$geography
    if (!is.null(g$lsoa_vintage)) {
      cli::cli_text("LSOA vintage: {.val {unique(g$lsoa_vintage)}}")
    }
    if (!is.null(g$area)) {
      cli::cli_text("Area: {.val {g$area}}")
    }
  }
  if (!is.null(x$crime_scope)) {
    cs <- x$crime_scope
    if (!is.null(cs$category_sets)) {
      cli::cli_text("Crime category sets: {.val {unique(cs$category_sets$category_set)}}")
    }
    if (!is.null(cs$include_asb)) {
      cli::cli_text("ASB in crime total: {cs$include_asb}")
    }
  }
  if (!is.null(x$stops)) {
    cli::cli_text("Stops: {x$stops$origin}, {x$stops$definition}")
  }
  cli::cli_text("Treatment: {if (is.null(x$treatment)) 'not defined' else x$treatment$type}")
  cli::cli_text(
    "Created {format(x$created$timestamp, '%Y-%m-%d %H:%M')} with streetlamp ",
    "{x$created$package_version}"
  )
  invisible(x)
}

#' @export
summary.lamp_contract <- function(object, ...) {
  print(object, ...)
}

# Contract-bearing tibbles ---------------------------------------------------

new_lamp_records <- function(x, contract) {
  x <- tibble::as_tibble(x)
  attr(x, "contract") <- contract
  class(x) <- c("lamp_records", class(x))
  x
}

lamp_restore_records <- function(x, template) {
  contract <- attr(template, "contract", exact = TRUE)
  if (is.null(contract)) {
    return(x)
  }
  x <- tibble::as_tibble(x)
  attr(x, "contract") <- contract
  class(x) <- unique(c("lamp_records", class(x)))
  x
}

#' @export
`[.lamp_records` <- function(x, i, j, ..., drop = FALSE) {
  out <- NextMethod()
  if (is.data.frame(out)) lamp_restore_records(out, x) else out
}

#' @exportS3Method dplyr::dplyr_reconstruct
dplyr_reconstruct.lamp_records <- function(data, template) {
  lamp_restore_records(data, template)
}

#' @export
print.lamp_records <- function(x, ...) {
  contract <- attr(x, "contract", exact = TRUE)
  cli::cli_text("{.strong streetlamp records} with a contract; see {.fn lamp_contract}.")
  NextMethod()
}

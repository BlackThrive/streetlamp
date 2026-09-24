# Panel construction --------------------------------------------------------------

lamp_area_types <- function() c("lsoa21", "lsoa11", "msoa21", "lad", "pfa")

lamp_lookup_label <- function() {
  "ONS LSOA 2011 to 2021 exact-fit lookup V3 with best-fit V2 flag"
}

lamp_check_records <- function(x, what, columns, arg = rlang::caller_arg(x),
                               call = rlang::caller_env()) {
  if (!inherits(x, "lamp_records")) {
    lamp_abort(
      "{.arg {arg}} must be a records table from {.fn lamp_read_{what}}.",
      "input",
      call = call
    )
  }
  missing <- setdiff(columns, names(x))
  if (length(missing) > 0L) {
    lamp_abort(
      "{.arg {arg}} lacks the column{?s} {.field {missing}}.",
      "input",
      call = call
    )
  }
  lamp_contract(x)
}

# Assign every crime record to a target area: re-vintage LSOA codes where a
# file's vintage differs from the target, then map to the requested level.
lamp_place_records <- function(crime, area, call = rlang::caller_env()) {
  codes <- crime$lsoa_code
  vint <- crime$lsoa_vintage
  target <- if (area == "lsoa11") "lsoa11" else "lsoa21"
  mapped <- codes
  revintage <- list()
  sets <- lamp_vintage_sets()
  for (v in c("lsoa11", "lsoa21")) {
    if (v == target) next
    sel <- which(vint == v & !is.na(codes))
    # In a file of mixed vintage only the codes that exist solely in the other
    # vintage need mapping.
    other_only <- if (v == "lsoa11") sets$only11 else sets$only21
    sel <- c(sel, which(vint == "mixed" & !is.na(codes) & codes %in% other_only))
    if (length(sel) == 0L) next
    r <- lamp_revintage_codes(codes[sel], from = v, to = target)
    mapped[sel] <- r$codes
    revintage[[v]] <- r$summary
  }
  area_code <- if (target == "lsoa21") lamp_map_area(mapped, area) else mapped
  list(
    area = area_code,
    revintage = revintage,
    n_records = length(codes),
    n_no_lsoa = sum(is.na(codes)),
    n_unknown_code = sum(!is.na(mapped) & is.na(area_code))
  )
}

# The set of areas belonging to the police force areas of `forces`.
lamp_area_universe <- function(forces, area, call = rlang::caller_env()) {
  f <- lamp_forces()
  unknown <- setdiff(forces, f$force_id)
  if (length(unknown) > 0L) {
    lamp_abort("Unknown force identifier{?s} {.val {unknown}}.", "input", call = call)
  }
  pfa <- f$pfa_code[match(forces, f$force_id)]
  pfa <- pfa[!is.na(pfa)]
  lk <- lamp_area_lookup()
  rows <- lk[lk$pfa %in% pfa, ]
  if (area == "lsoa11") {
    l <- lamp_lsoa_lookup()
    hit <- l[l$lsoa21 %in% rows$lsoa21, c("lsoa11", "lsoa21")]
    hit$pfa <- rows$pfa[match(hit$lsoa21, rows$lsoa21)]
    hit <- hit[order(hit$lsoa11), ]
    hit <- hit[!duplicated(hit$lsoa11), ]
    return(tibble::tibble(
      area = hit$lsoa11,
      force_id = f$force_id[match(hit$pfa, f$pfa_code)]
    ))
  }
  col <- switch(area,
    lsoa21 = "lsoa21",
    msoa21 = "msoa21",
    lad = "lad22",
    pfa = "pfa"
  )
  u <- unique(rows[, c(col, "pfa")])
  u <- u[order(u[[col]]), ]
  tibble::tibble(area = u[[col]], force_id = f$force_id[match(u$pfa, f$pfa_code)])
}

lamp_key <- function(force_id, month) paste(force_id, lamp_month_id(month))

# Statuses for which zero counts are trustworthy (the force submitted).
lamp_filled_statuses <- function() c("submitted", "refreshed", "partial_suspected")

# Aggregate area-level stop counts (lsoa21) to a coarser level.
lamp_aggregate_stops <- function(stops, from, to, call = rlang::caller_env()) {
  if (from == to) {
    return(stops)
  }
  if (from != "lsoa21") {
    lamp_abort(
      c(
        "Stop counts at {.val {from}} level cannot be aggregated to {.val {to}}.",
        "i" = "Count stops at {.val lsoa21} or {.val {to}} level."
      ),
      "input",
      call = call
    )
  }
  stops$area <- lamp_map_area(stops$area, to)
  stops <- stops[!is.na(stops$area), ]
  stops |>
    dplyr::group_by(.data$area, .data$month) |>
    dplyr::summarise(
      stops = sum(.data$stops),
      stops_s60 = sum(.data$stops_s60),
      .groups = "drop"
    )
}

#' Build an area-by-month panel of crime and stops
#'
#' Turns crime records into a balanced area-by-month panel with one column per
#' crime type, a crime total, an anti-social behaviour series, stop counts,
#' population and a stop rate, and attaches a full panel contract. The panel
#' covers every area in the police force areas of the forces present in
#' `crime` (or the areas you name) and every month in the records.
#'
#' @details
#' Records are placed by their LSOA code. Files published with 2011 codes are
#' re-vintaged to 2021 with the bundled ONS lookup (or 2021 to 2011 when
#' `area = "lsoa11"`), and the contract's `geography$revintage` element
#' records how many records and areas were unchanged, split, merged or
#' complex. Coarser areas (`msoa21`, `lad`, `pfa`) are reached through
#' [lamp_area_lookup()].
#'
#' "Force did not submit" is never a zero: counts are zero-filled only in
#' force-months whose street file was submitted; force-months with no file
#' are `NA` and carry `coverage_status = "missing"`. Force-months whose record
#' count is suspiciously low are kept but flagged `partial_suspected`; see
#' [lamp_coverage()].
#'
#' Anti-social behaviour is not a crime: it goes to the `asb` column and is
#' excluded from `crime_total` unless `include_asb = TRUE`. The crime type
#' columns are the snake_case keys of [lamp_crime_types()]; the legacy
#' `public_disorder_and_weapons` column appears only when records from before
#' May 2013 are present.
#'
#' @param crime Records from [lamp_read_crime()].
#' @param outcomes Optional records from [lamp_read_outcomes()]; adds
#'   `outcomes_total` and one column per outcome group, counted by the month
#'   the outcome was recorded.
#' @param stops Optional stop counts from [lamp_read_stop_counts()] at the
#'   panel's area level (or at `lsoa21` level, which is aggregated), or a
#'   user-supplied tibble with columns `area`, `month`, `stops` and
#'   optionally `stops_s60` and `coverage_status`, which is tagged
#'   `user_supplied` in the contract and never zero-filled.
#' @param area The area level: `"lsoa21"` (default), `"lsoa11"`, `"msoa21"`,
#'   `"lad"` (2022 local authority districts) or `"pfa"` (police force
#'   areas).
#' @param population Optional population by area: the output of
#'   `lamp_population()` or a tibble with columns `area` and `population`.
#'   Needed for `stop_rate` (stops per 1,000 residents).
#' @param covariates Optional tibble with an `area` column (and optionally
#'   `month`) whose other columns are joined to the panel.
#' @param include_asb Include anti-social behaviour in `crime_total`?
#' @param attribution Which column names the force a record belongs to:
#'   `"falls_within"` (default) or `"reported_by"`. Areas are always placed by
#'   location; attribution only affects the diagnostics on records located
#'   outside their force's area and the `pfa` level, where records are counted
#'   by the attributed force.
#' @param areas Optional character vector restricting the panel to these
#'   areas (identifiers at the chosen level).
#' @param adjacency Optional [lamp_adjacency()] object for the panel's areas,
#'   stored in the contract for spatial estimators.
#' @param changelog Optional [lamp_changelog()] table used to mark
#'   force-months that the publisher's changelog says were refreshed.
#'
#' @return A tibble of class `lamp_panel` with columns `area`, `month`,
#'   `force_id`, one column per crime type, `crime_total`, `asb`, `stops`,
#'   `stops_s60`, `population`, `stop_rate`, `coverage_status`,
#'   `stops_status`, any outcome and covariate columns, and a contract
#'   retrievable with [lamp_contract()].
#' @family panel
#' @export
#' @examples
#' cache <- tempfile("streetlamp-cache-")
#' zip <- system.file("extdata", "archive", "2026-07.zip", package = "streetlamp")
#' lamp_archive_register(zip, dir = cache)
#' crime <- lamp_read_crime(cache, forces = "dyfed-powys", months = "2026-07")
#' panel <- lamp_panel(crime, area = "lad")
#' panel
#' lamp_contract(panel)$coverage
#'
#' # The bundled sample is a full two-force LSOA panel over 24 months
#' lamp_sample_panel()
lamp_panel <- function(crime, outcomes = NULL, stops = NULL,
                       area = c("lsoa21", "lsoa11", "msoa21", "lad", "pfa"),
                       population = NULL, covariates = NULL, include_asb = FALSE,
                       attribution = c("falls_within", "reported_by"), areas = NULL,
                       adjacency = NULL, changelog = NULL) {
  area <- rlang::arg_match(area)
  attribution <- rlang::arg_match(attribution)
  check_bool(include_asb)
  crime_contract <- lamp_check_records(
    crime, "crime",
    c("crime_id", "month", "force_id", "lsoa_code", "lsoa_vintage", "crime_type", "is_asb")
  )
  street_cov <- crime_contract$coverage
  if (is.null(street_cov) || !"street" %in% street_cov$file_type) {
    lamp_abort("{.arg crime} carries no street coverage in its contract.", "contract")
  }
  street_cov <- street_cov[street_cov$file_type == "street", ]
  forces <- sort(unique(street_cov$force_id))
  months <- seq(min(street_cov$month), max(street_cov$month), by = "month")

  # Coverage statuses, including partial and refreshed flags
  coverage <- lamp_coverage_table(
    street = street_cov,
    outcomes = if (!is.null(outcomes)) lamp_contract(outcomes)$coverage else NULL,
    stops = if (inherits(stops, "lamp_records")) lamp_contract(stops)$coverage else NULL,
    changelog = changelog
  )
  street_status <- coverage[coverage$file_type == "street", ]

  # Place records and count
  placed <- lamp_place_records(crime, area)
  universe <- if (is.null(areas)) {
    lamp_area_universe(forces, area)
  } else {
    if (!is.character(areas)) {
      lamp_abort("{.arg areas} must be a character vector of area identifiers.", "input")
    }
    u <- lamp_area_universe(forces, area)
    u <- u[u$area %in% areas, ]
    if (nrow(u) == 0L) {
      lamp_abort(
        "None of {.arg areas} lies in the police force areas of the crime records.",
        "input"
      )
    }
    u
  }
  attributed_force <- lamp_force_id_from_name(crime[[attribution]])
  if (area == "pfa") {
    # count by the attributed force's area
    f <- lamp_forces()
    record_area <- f$pfa_code[match(attributed_force, f$force_id)]
  } else {
    record_area <- placed$area
  }
  in_universe <- !is.na(record_area) & record_area %in% universe$area
  n_outside <- sum(!is.na(record_area) & !in_universe)
  area_force <- universe$force_id[match(record_area, universe$area)]
  cross <- in_universe & !is.na(attributed_force) & attributed_force != area_force
  n_cross_border <- sum(cross, na.rm = TRUE)

  ct <- lamp_crime_types()
  levels_all <- levels(crime$crime_type)
  legacy_level <- "Public disorder and weapons"
  key_of <- stats::setNames(ct$key, ct$crime_type)
  key_of[legacy_level] <- "public_disorder_and_weapons"
  rec <- tibble::tibble(
    area = record_area[in_universe],
    month = crime$month[in_universe],
    key = key_of[as.character(crime$crime_type[in_universe])]
  )
  rec <- rec[!is.na(rec$key), ]
  counts <- rec |>
    dplyr::count(.data$area, .data$month, .data$key, name = "n") |>
    tidyr::pivot_wider(names_from = "key", values_from = "n", values_fill = 0L)
  type_keys <- setdiff(ct$key, "anti_social_behaviour")
  has_legacy <- legacy_level %in% levels_all && any(crime$crime_type == legacy_level, na.rm = TRUE)
  if (has_legacy) {
    type_keys <- c(type_keys, "public_disorder_and_weapons")
  }
  count_cols <- c(type_keys, "anti_social_behaviour")
  for (k in setdiff(count_cols, names(counts))) counts[[k]] <- 0L

  # Balanced grid, zero-filled only where the force submitted
  grid <- tidyr::expand_grid(area = universe$area, month = months)
  grid$force_id <- universe$force_id[match(grid$area, universe$area)]
  grid <- dplyr::left_join(grid, counts[, c("area", "month", count_cols)], by = c("area", "month"))
  key_grid <- lamp_key(grid$force_id, grid$month)
  key_street <- lamp_key(street_status$force_id, street_status$month)
  status <- street_status$status[match(key_grid, key_street)]
  status[is.na(status)] <- "missing"
  filled <- status %in% lamp_filled_statuses()
  for (k in count_cols) {
    v <- grid[[k]]
    v[is.na(v) & filled] <- 0L
    v[!filled] <- NA_integer_
    grid[[k]] <- as.integer(v)
  }
  grid$asb <- grid$anti_social_behaviour
  grid$anti_social_behaviour <- NULL
  total_cols <- if (include_asb) c(type_keys, "asb") else type_keys
  grid$crime_total <- as.integer(rowSums(grid[, total_cols, drop = FALSE]))
  grid$coverage_status <- status

  # Stops
  stops_info <- lamp_panel_stops(stops, grid, area, universe, coverage)
  grid$stops <- stops_info$stops
  grid$stops_s60 <- stops_info$stops_s60
  grid$stops_status <- stops_info$status

  # Outcomes
  outcome_cols <- character()
  if (!is.null(outcomes)) {
    lamp_check_records(
      outcomes, "outcomes", c("month", "lsoa_code", "lsoa_vintage", "outcome_group")
    )
    placed_o <- lamp_place_records(outcomes, area)
    orec <- tibble::tibble(
      area = placed_o$area, month = outcomes$month,
      group = as.character(outcomes$outcome_group)
    )
    orec <- orec[!is.na(orec$area) & orec$area %in% universe$area & !is.na(orec$group), ]
    ocounts <- orec |>
      dplyr::count(.data$area, .data$month, .data$group, name = "n") |>
      tidyr::pivot_wider(
        names_from = "group", values_from = "n", values_fill = 0L, names_prefix = "outcome_"
      )
    outcome_cols <- paste0("outcome_", lamp_outcome_groups())
    for (k in setdiff(outcome_cols, names(ocounts))) ocounts[[k]] <- 0L
    grid <- dplyr::left_join(
      grid, ocounts[, c("area", "month", outcome_cols)],
      by = c("area", "month")
    )
    ostatus <- coverage[coverage$file_type == "outcomes", ]
    key_o <- lamp_key(ostatus$force_id, ostatus$month)
    o_ok <- ostatus$status[match(key_grid, key_o)] %in% lamp_filled_statuses()
    for (k in outcome_cols) {
      v <- grid[[k]]
      v[is.na(v) & o_ok] <- 0L
      v[!o_ok] <- NA_integer_
      grid[[k]] <- as.integer(v)
    }
    grid$outcomes_total <- as.integer(rowSums(grid[, outcome_cols, drop = FALSE]))
    outcome_cols <- c("outcomes_total", outcome_cols)
  }

  # Population and rate
  pop_info <- lamp_panel_population(population, grid, area)
  grid$population <- pop_info$population
  grid$stop_rate <- ifelse(
    is.na(grid$stops) | is.na(grid$population) | grid$population <= 0,
    NA_real_, 1000 * grid$stops / grid$population
  )

  # Covariates
  covariate_cols <- character()
  if (!is.null(covariates)) {
    if (!is.data.frame(covariates) || !"area" %in% names(covariates)) {
      lamp_abort("{.arg covariates} must be a data frame with an {.field area} column.", "input")
    }
    by <- intersect(c("area", "month"), names(covariates))
    covariate_cols <- setdiff(names(covariates), by)
    clash <- intersect(covariate_cols, names(grid))
    if (length(clash) > 0L) {
      lamp_abort("Covariate column{?s} {.field {clash}} clash with panel columns.", "input")
    }
    grid <- dplyr::left_join(grid, covariates, by = by)
  }

  # Adjacency
  if (!is.null(adjacency)) {
    if (!inherits(adjacency, "lamp_adjacency")) {
      lamp_abort("{.arg adjacency} must come from {.fn lamp_adjacency}.", "input")
    }
    missing_areas <- setdiff(universe$area, adjacency$areas)
    if (length(missing_areas) > 0L) {
      lamp_warn(
        "{length(missing_areas)} panel area{?s} {?is/are} absent from the adjacency object.",
        "input"
      )
    }
  }

  ordered <- c(
    "area", "month", "force_id", type_keys, "crime_total", "asb", "stops", "stops_s60",
    "population", "stop_rate", outcome_cols, covariate_cols, "coverage_status", "stops_status"
  )
  grid <- grid[order(grid$area, grid$month), ordered]

  vintages <- crime_contract$geography$lsoa_vintage
  contract <- new_lamp_contract(
    snapshots = crime_contract$snapshots,
    versions = crime_contract$versions,
    coverage = coverage,
    geography = list(
      area = area,
      lsoa_vintage = vintages,
      lookup = if (length(placed$revintage) > 0L) lamp_lookup_label() else NULL,
      revintage = placed$revintage,
      boundary_vintage = if (!is.null(adjacency)) adjacency$boundary_vintage else NULL,
      adjacency = adjacency,
      n_areas = nrow(universe),
      forces = forces,
      placement = list(
        n_records = placed$n_records, n_no_lsoa = placed$n_no_lsoa,
        n_unknown_code = placed$n_unknown_code, n_outside_universe = n_outside,
        n_cross_border = n_cross_border
      )
    ),
    population = pop_info$contract,
    crime_scope = list(
      crime_total = total_cols,
      include_asb = include_asb,
      attribution = attribution,
      category_sets = crime_contract$crime_scope$category_sets
    ),
    stops = stops_info$contract,
    treatment = NULL
  )
  new_lamp_panel(grid, contract)
}

lamp_panel_stops <- function(stops, grid, area, universe, coverage, call = rlang::caller_env()) {
  n <- nrow(grid)
  empty <- list(
    stops = rep(NA_integer_, n), stops_s60 = rep(NA_integer_, n),
    status = rep(NA_character_, n), contract = NULL
  )
  if (is.null(stops)) {
    return(empty)
  }
  key_g <- lamp_key(grid$force_id, grid$month)
  key_area <- paste(grid$area, lamp_month_id(grid$month))
  if (inherits(stops, "lamp_records")) {
    sc <- lamp_contract(stops)
    if (is.null(sc$stops)) {
      lamp_abort(
        "{.arg stops} must come from {.fn lamp_read_stop_counts} or be a plain tibble.",
        "input",
        call = call
      )
    }
    from <- sc$stops$area
    if (from == "force") {
      if (area != "pfa") {
        lamp_abort(
          c(
            "{.arg stops} are counted per force but the panel is at {.val {area}} level.",
            "i" = "Count stops with boundaries at {.val {area}} level, or build a {.val pfa} panel."
          ),
          "input",
          call = call
        )
      }
      f <- lamp_forces()
      n_stops <- as.integer(stops$stops)
      n_s60 <- as.integer(stops$stops_s60)
      counts <- tibble::tibble(
        area = f$pfa_code[match(stops$force_id, f$force_id)], month = stops$month,
        stops = n_stops, stops_s60 = n_s60
      )
    } else {
      counts <- lamp_aggregate_stops(
        stops[, c("area", "month", "stops", "stops_s60")], from, area,
        call = call
      )
    }
    ss <- coverage[coverage$file_type == "stop-and-search", ]
    status <- ss$status[match(key_g, lamp_key(ss$force_id, ss$month))]
    status[is.na(status)] <- "missing"
    contract <- c(sc$stops, list(definition = "raw count", rate = "stops per 1,000 residents"))
    zero_fill <- TRUE
  } else {
    if (!is.data.frame(stops) || !all(c("area", "month", "stops") %in% names(stops))) {
      lamp_abort(
        "{.arg stops} needs columns {.field area}, {.field month} and {.field stops}.",
        "input",
        call = call
      )
    }
    n_stops <- as.integer(stops$stops)
    n_s60 <- if ("stops_s60" %in% names(stops)) as.integer(stops$stops_s60) else NA_integer_
    counts <- tibble::tibble(
      area = as.character(stops$area), month = lamp_as_months(stops$month),
      stops = n_stops, stops_s60 = n_s60
    )
    if ("coverage_status" %in% names(stops)) {
      st_key <- paste(counts$area, lamp_month_id(counts$month))
      st_status <- as.character(stops$coverage_status)
      status <- st_status[match(key_area, st_key)]
    } else {
      status <- rep(NA_character_, n)
    }
    contract <- list(
      origin = "user_supplied", definition = "raw count",
      rate = "stops per 1,000 residents", area = area
    )
    zero_fill <- FALSE
  }
  idx <- match(key_area, paste(counts$area, lamp_month_id(counts$month)))
  s <- as.integer(counts$stops[idx])
  s60 <- as.integer(counts$stops_s60[idx])
  if (zero_fill) {
    ok <- status %in% lamp_filled_statuses()
    s[is.na(s) & ok] <- 0L
    s60[is.na(s60) & ok] <- 0L
    s[!ok] <- NA_integer_
    s60[!ok] <- NA_integer_
  }
  list(stops = s, stops_s60 = s60, status = status, contract = contract)
}

lamp_panel_population <- function(population, grid, area, call = rlang::caller_env()) {
  n <- nrow(grid)
  if (is.null(population)) {
    return(list(population = rep(NA_real_, n), contract = NULL))
  }
  if (!is.data.frame(population) || !all(c("area", "population") %in% names(population))) {
    lamp_abort(
      "{.arg population} must have columns {.field area} and {.field population}.",
      "input",
      call = call
    )
  }
  source <- attr(population, "source", exact = TRUE)
  pop_area <- attr(population, "area", exact = TRUE)
  if (!is.null(pop_area) && pop_area != area) {
    lamp_abort(
      "{.arg population} is at {.val {pop_area}} level but the panel is at {.val {area}} level.",
      "input",
      call = call
    )
  }
  idx <- match(grid$area, as.character(population$area))
  contract <- if (is.null(source)) "user_supplied" else source
  list(population = as.numeric(population$population[idx]), contract = contract)
}

#' @export
plot.lamp_panel <- function(x, y = NULL, outcome = "crime_total", ...) {
  check_string(outcome)
  if (!outcome %in% names(x)) {
    lamp_abort("{.arg outcome} must name a panel column.", "input")
  }
  by_force <- x |>
    dplyr::group_by(.data$force_id, .data$month) |>
    dplyr::summarise(
      value = if (all(is.na(.data[[outcome]]))) NA_real_ else sum(.data[[outcome]], na.rm = TRUE),
      missing = all(is.na(.data[[outcome]])),
      .groups = "drop"
    )
  col <- lamp_colours()
  by_force$force <- lamp_force_label(by_force$force_id)
  gaps <- by_force[by_force$missing, ]
  gaps$month_end <- as.Date(format(gaps$month + 32, "%Y-%m-01"))
  ends <- by_force[!by_force$missing, ]
  ends <- ends[ends$month == stats::ave(ends$month, ends$force, FUN = max), ]
  p <- ggplot2::ggplot(by_force, ggplot2::aes(x = .data$month, y = .data$value))
  if (nrow(gaps) > 0L) {
    p <- p + ggplot2::geom_rect(
      data = gaps,
      ggplot2::aes(xmin = .data$month, xmax = .data$month_end, ymin = -Inf, ymax = Inf),
      inherit.aes = FALSE, fill = col[["shade"]]
    )
  }
  p +
    ggplot2::geom_line(colour = col[["series"]], linewidth = 0.8, na.rm = TRUE) +
    ggplot2::geom_point(data = ends, colour = col[["series"]], size = 2.2) +
    ggplot2::facet_wrap(ggplot2::vars(.data$force), scales = "free_y") +
    ggplot2::scale_y_continuous(
      labels = lamp_label_number,
      expand = ggplot2::expansion(mult = c(0.08, 0.12))
    ) +
    ggplot2::labs(
      x = NULL, y = NULL,
      title = sprintf("%s by force and month", lamp_pretty_name(outcome)),
      subtitle = if (nrow(gaps) > 0L) "Shaded months have no submitted file" else NULL
    ) +
    lamp_theme()
}

# Build an area-by-month panel of crime and stops

Turns crime records into a balanced area-by-month panel with one column
per crime type, a crime total, an anti-social behaviour series, stop
counts, population and a stop rate, and attaches a full panel contract.
The panel covers every area in the police force areas of the forces
present in `crime` (or the areas you name) and every month in the
records.

## Usage

``` r
lamp_panel(
  crime,
  outcomes = NULL,
  stops = NULL,
  area = c("lsoa21", "lsoa11", "msoa21", "lad", "pfa"),
  population = NULL,
  covariates = NULL,
  include_asb = FALSE,
  attribution = c("falls_within", "reported_by"),
  areas = NULL,
  adjacency = NULL,
  changelog = NULL
)
```

## Arguments

- crime:

  Records from
  [`lamp_read_crime()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_crime.md).

- outcomes:

  Optional records from
  [`lamp_read_outcomes()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_outcomes.md);
  adds `outcomes_total` and one column per outcome group, counted by the
  month the outcome was recorded.

- stops:

  Optional stop counts from
  [`lamp_read_stop_counts()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_stop_counts.md)
  at the panel's area level (or at `lsoa21` level, which is aggregated),
  or a user-supplied tibble with columns `area`, `month`, `stops` and
  optionally `stops_s60` and `coverage_status`, which is tagged
  `user_supplied` in the contract and never zero-filled.

- area:

  The area level: `"lsoa21"` (default), `"lsoa11"`, `"msoa21"`, `"lad"`
  (2022 local authority districts) or `"pfa"` (police force areas).

- population:

  Optional population by area: the output of
  [`lamp_population()`](https://blackthrive.github.io/streetlamp/reference/lamp_population.md)
  or a tibble with columns `area` and `population`. Needed for
  `stop_rate` (stops per 1,000 residents).

- covariates:

  Optional tibble with an `area` column (and optionally `month`) whose
  other columns are joined to the panel.

- include_asb:

  Include anti-social behaviour in `crime_total`?

- attribution:

  Which column names the force a record belongs to: `"falls_within"`
  (default) or `"reported_by"`. Areas are always placed by location;
  attribution only affects the diagnostics on records located outside
  their force's area and the `pfa` level, where records are counted by
  the attributed force.

- areas:

  Optional character vector restricting the panel to these areas
  (identifiers at the chosen level).

- adjacency:

  Optional
  [`lamp_adjacency()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency.md)
  object for the panel's areas, stored in the contract for spatial
  estimators.

- changelog:

  Optional
  [`lamp_changelog()`](https://blackthrive.github.io/streetlamp/reference/lamp_changelog.md)
  table used to mark force-months that the publisher's changelog says
  were refreshed.

## Value

A tibble of class `lamp_panel` with columns `area`, `month`, `force_id`,
one column per crime type, `crime_total`, `asb`, `stops`, `stops_s60`,
`population`, `stop_rate`, `coverage_status`, `stops_status`, any
outcome and covariate columns, and a contract retrievable with
[`lamp_contract()`](https://blackthrive.github.io/streetlamp/reference/lamp_contract.md).

## Details

Records are placed by their LSOA code. Files published with 2011 codes
are re-vintaged to 2021 with the bundled ONS lookup (or 2021 to 2011
when `area = "lsoa11"`), and the contract's `geography$revintage`
element records how many records and areas were unchanged, split, merged
or complex. Coarser areas (`msoa21`, `lad`, `pfa`) are reached through
[`lamp_area_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_area_lookup.md).

"Force did not submit" is never a zero: counts are zero-filled only in
force-months whose street file was submitted; force-months with no file
are `NA` and carry `coverage_status = "missing"`. Force-months whose
record count is suspiciously low are kept but flagged
`partial_suspected`; see
[`lamp_coverage()`](https://blackthrive.github.io/streetlamp/reference/lamp_coverage.md).

Anti-social behaviour is not a crime: it goes to the `asb` column and is
excluded from `crime_total` unless `include_asb = TRUE`. The crime type
columns are the snake_case keys of
[`lamp_crime_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_crime_types.md);
the legacy `public_disorder_and_weapons` column appears only when
records from before May 2013 are present.

## See also

Other panel:
[`lamp_adjacency()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency.md),
[`lamp_adjacency_from_nb()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency_from_nb.md),
[`lamp_boundaries()`](https://blackthrive.github.io/streetlamp/reference/lamp_boundaries.md),
[`lamp_changelog()`](https://blackthrive.github.io/streetlamp/reference/lamp_changelog.md),
[`lamp_coverage()`](https://blackthrive.github.io/streetlamp/reference/lamp_coverage.md),
[`lamp_population()`](https://blackthrive.github.io/streetlamp/reference/lamp_population.md),
[`lamp_revintage()`](https://blackthrive.github.io/streetlamp/reference/lamp_revintage.md)

## Examples

``` r
cache <- tempfile("streetlamp-cache-")
zip <- system.file("extdata", "archive", "2026-07.zip", package = "streetlamp")
lamp_archive_register(zip, dir = cache)
#> Registered archive "2026-07" from
#> /home/runner/work/_temp/Library/streetlamp/extdata/archive/2026-07.zip.
crime <- lamp_read_crime(cache, forces = "dyfed-powys", months = "2026-07")
panel <- lamp_panel(crime, area = "lad")
panel
#> streetlamp panel: 4 lad area x 1 month; see `lamp_contract()` and
#> `lamp_coverage()`.
#> # A tibble: 4 × 24
#>   area   month      force_id bicycle_theft burglary criminal_damage_and_…¹ drugs
#>   <chr>  <date>     <chr>            <int>    <int>                  <int> <int>
#> 1 W0600… 2026-07-01 dyfed-p…             0        0                      0     0
#> 2 W0600… 2026-07-01 dyfed-p…             4        8                     40     5
#> 3 W0600… 2026-07-01 dyfed-p…             3       19                     41    18
#> 4 W0600… 2026-07-01 dyfed-p…             0        0                      0     0
#> # ℹ abbreviated name: ¹​criminal_damage_and_arson
#> # ℹ 17 more variables: other_crime <int>, other_theft <int>,
#> #   possession_of_weapons <int>, public_order <int>, robbery <int>,
#> #   shoplifting <int>, theft_from_the_person <int>, vehicle_crime <int>,
#> #   violence_and_sexual_offences <int>, crime_total <int>, asb <int>,
#> #   stops <int>, stops_s60 <int>, population <dbl>, stop_rate <dbl>,
#> #   coverage_status <chr>, stops_status <chr>
lamp_contract(panel)$coverage
#> streetlamp coverage: 1 force, 1 file type, 0 mismatched force-months.
#> # A tibble: 1 × 10
#>   force_id    month      file_type status    n_records archive n_versions
#>   <chr>       <date>     <chr>     <chr>         <int> <chr>        <int>
#> 1 dyfed-powys 2026-07-01 street    submitted       979 2026-07          1
#> # ℹ 3 more variables: versions_differ <lgl>, note <chr>, mismatch <lgl>

# The bundled sample is a full two-force LSOA panel over 24 months
lamp_sample_panel()
#> streetlamp panel: 1710 lsoa21 area x 24 months; see `lamp_contract()` and
#> `lamp_coverage()`.
#> # A tibble: 41,040 × 27
#>    area  month      force_id bicycle_theft burglary criminal_damage_and_…¹ drugs
#>    <chr> <date>     <chr>            <int>    <int>                  <int> <int>
#>  1 E010… 2024-08-01 west-yo…             0        0                      2     0
#>  2 E010… 2024-09-01 west-yo…             0        0                      0     0
#>  3 E010… 2024-10-01 west-yo…             0        0                      1     0
#>  4 E010… 2024-11-01 west-yo…             0        4                      2     0
#>  5 E010… 2024-12-01 west-yo…             0        0                      1     0
#>  6 E010… 2025-01-01 west-yo…             0        2                      1     0
#>  7 E010… 2025-02-01 west-yo…             0        1                      1     0
#>  8 E010… 2025-03-01 west-yo…             0        2                      0     0
#>  9 E010… 2025-04-01 west-yo…             0        2                      0     0
#> 10 E010… 2025-05-01 west-yo…             0        0                      0     0
#> # ℹ 41,030 more rows
#> # ℹ abbreviated name: ¹​criminal_damage_and_arson
#> # ℹ 20 more variables: other_crime <int>, other_theft <int>,
#> #   possession_of_weapons <int>, public_order <int>, robbery <int>,
#> #   shoplifting <int>, theft_from_the_person <int>, vehicle_crime <int>,
#> #   violence_and_sexual_offences <int>, crime_total <int>, asb <int>,
#> #   stops <int>, stops_s60 <int>, population <dbl>, stop_rate <dbl>, …
```

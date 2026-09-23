# Read street-level crime records from the archive

Reads the selected `street` files into one table with a fixed snake_case
schema, harmonises crime type labels across the three category sets that
data.police.uk has used since December 2010, flags anti-social
behaviour, detects the LSOA vintage of every file, and attaches a panel
contract.

## Usage

``` r
lamp_read_crime(
  dir = lamp_cache_dir(),
  versions = NULL,
  months = NULL,
  forces = NULL,
  fetch = FALSE
)
```

## Arguments

- dir:

  A cache directory (see
  [`lamp_cache_dir()`](https://blackthrive.github.io/streetlamp/reference/lamp_cache_dir.md))
  or a `lamp_snapshot` from
  [`lamp_archive_snapshot()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_snapshot.md).

- versions:

  A `lamp_selection` from
  [`lamp_select_version()`](https://blackthrive.github.io/streetlamp/reference/lamp_select_version.md);
  by default the newest archive version of each file is used.

- months, forces:

  Optional filters, as in
  [`lamp_archive_download()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_download.md).

- fetch:

  Fetch selected files that are listed in the snapshot but not held
  locally (needs network access). With the default `FALSE` only the
  files held locally are read, with a message saying how many were
  skipped, so a reader never starts a large download on its own.

## Value

A tibble of class `lamp_records` with columns `crime_id`, `month` (Date,
first of month), `reported_by`, `falls_within`, `force_id` (from the
file name), `longitude`, `latitude`, `location`, `lsoa_code`,
`lsoa_name`, `lsoa_vintage`, `crime_type` (factor), `crime_type_raw`,
`is_asb`, `last_outcome_category`, `context`, `archive` and `file`, and
a contract retrievable with
[`lamp_contract()`](https://blackthrive.github.io/streetlamp/reference/lamp_contract.md)
whose `coverage` element marks force-months with no file as `missing`.

## Details

Crime types are returned as a factor whose levels are the fourteen
current categories plus `Public disorder and weapons`, the legacy
category that was split in May 2013 and cannot be mapped forward.
`Violent crime`, the pre-2013 name of `Violence and sexual offences`, is
renamed. The raw label is kept in `crime_type_raw`, and the contract's
`crime_scope$category_sets` records which set each file uses (`six` for
December 2010 to August 2011, `eleven` to April 2013, `fourteen` since
May 2013).

Anti-social behaviour rows have no Crime ID and no outcome; they are
kept with `is_asb = TRUE` so that
[`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md)
can hold them in a separate series. Rows without coordinates or LSOA
code are kept as `NA`.

## See also

Other ingest:
[`lamp_archive_download()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_download.md),
[`lamp_archive_index()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_index.md),
[`lamp_archive_register()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_register.md),
[`lamp_archive_snapshot()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_snapshot.md),
[`lamp_list_versions()`](https://blackthrive.github.io/streetlamp/reference/lamp_list_versions.md),
[`lamp_lsoa_vintage()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_vintage.md),
[`lamp_read_outcomes()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_outcomes.md),
[`lamp_read_stop_counts()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_stop_counts.md),
[`lamp_s60_legislation()`](https://blackthrive.github.io/streetlamp/reference/lamp_s60_legislation.md),
[`lamp_select_version()`](https://blackthrive.github.io/streetlamp/reference/lamp_select_version.md),
[`lamp_version_diff()`](https://blackthrive.github.io/streetlamp/reference/lamp_version_diff.md)

## Examples

``` r
cache <- tempfile("streetlamp-cache-")
zip <- system.file("extdata", "archive", "2026-07.zip", package = "streetlamp")
lamp_archive_register(zip, dir = cache)
#> Registered archive "2026-07" from
#> /home/runner/work/_temp/Library/streetlamp/extdata/archive/2026-07.zip.
crime <- lamp_read_crime(cache, forces = "dyfed-powys")
crime
#> streetlamp records with a contract; see `lamp_contract()`.
#> # A tibble: 2,872 × 18
#>    crime_id      month      reported_by falls_within force_id longitude latitude
#>    <chr>         <date>     <chr>       <chr>        <chr>        <dbl>    <dbl>
#>  1 ce14ac1ee92b… 2026-05-01 Dyfed-Powy… Dyfed-Powys… dyfed-p…     -4.26     52.0
#>  2 b7b0a7355ff6… 2026-05-01 Dyfed-Powy… Dyfed-Powys… dyfed-p…     -4.27     52.0
#>  3 623a7bcbb78a… 2026-05-01 Dyfed-Powy… Dyfed-Powys… dyfed-p…     -4.27     52.0
#>  4 4c442de2c4fc… 2026-05-01 Dyfed-Powy… Dyfed-Powys… dyfed-p…     -4.26     52.0
#>  5 f43e8e6b428f… 2026-05-01 Dyfed-Powy… Dyfed-Powys… dyfed-p…     -4.26     52.0
#>  6 3239e6fe1ef4… 2026-05-01 Dyfed-Powy… Dyfed-Powys… dyfed-p…     -4.26     52.0
#>  7 580c7905ac2f… 2026-05-01 Dyfed-Powy… Dyfed-Powys… dyfed-p…     -4.26     52.0
#>  8 f9ff02800dfa… 2026-05-01 Dyfed-Powy… Dyfed-Powys… dyfed-p…     -4.27     52.0
#>  9 af3d36909f9b… 2026-05-01 Dyfed-Powy… Dyfed-Powys… dyfed-p…     -4.07     52.1
#> 10 5c947f9fbb43… 2026-05-01 Dyfed-Powy… Dyfed-Powys… dyfed-p…     -4.07     52.1
#> # ℹ 2,862 more rows
#> # ℹ 11 more variables: location <chr>, lsoa_code <chr>, lsoa_name <chr>,
#> #   lsoa_vintage <chr>, crime_type <fct>, crime_type_raw <chr>, is_asb <lgl>,
#> #   last_outcome_category <chr>, context <chr>, archive <chr>, file <chr>
table(crime$crime_type)
#> 
#>        Anti-social behaviour                Bicycle theft 
#>                          317                           16 
#>                     Burglary    Criminal damage and arson 
#>                           99                          286 
#>                        Drugs                  Other crime 
#>                           77                           71 
#>                  Other theft        Possession of weapons 
#>                          170                           29 
#>                 Public order                      Robbery 
#>                          227                            8 
#>                  Shoplifting        Theft from the person 
#>                          169                           14 
#>                Vehicle crime Violence and sexual offences 
#>                           47                         1342 
#>  Public disorder and weapons 
#>                            0 
lamp_contract(crime)$coverage
#> # A tibble: 3 × 8
#>   force_id    month      file_type status    archive n_records n_versions
#>   <chr>       <date>     <chr>     <chr>     <chr>       <int>      <int>
#> 1 dyfed-powys 2026-05-01 street    submitted 2026-07       968          1
#> 2 dyfed-powys 2026-06-01 street    submitted 2026-07       925          1
#> 3 dyfed-powys 2026-07-01 street    submitted 2026-07       979          1
#> # ℹ 1 more variable: versions_differ <lgl>
```

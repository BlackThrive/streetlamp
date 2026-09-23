# Read outcome records from the archive

Reads the selected `outcomes` files into one table with a fixed schema,
classifies outcomes with
[`lamp_outcome_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_outcome_types.md),
detects the LSOA vintage of every file, and attaches a panel contract.
An outcomes file for a month lists the outcomes recorded in that month,
whose crimes may date from earlier months, and a crime can have several
outcomes.

## Usage

``` r
lamp_read_outcomes(
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

A tibble of class `lamp_records` with columns `crime_id`, `month`,
`reported_by`, `falls_within`, `force_id`, `longitude`, `latitude`,
`location`, `lsoa_code`, `lsoa_name`, `lsoa_vintage`, `outcome_type`
(factor), `outcome_type_raw`, `outcome_group` (factor with the six
groups of
[`lamp_outcome_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_outcome_types.md)),
`archive` and `file`, plus a contract.

## See also

Other ingest:
[`lamp_archive_download()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_download.md),
[`lamp_archive_index()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_index.md),
[`lamp_archive_register()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_register.md),
[`lamp_archive_snapshot()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_snapshot.md),
[`lamp_list_versions()`](https://blackthrive.github.io/streetlamp/reference/lamp_list_versions.md),
[`lamp_lsoa_vintage()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_vintage.md),
[`lamp_read_crime()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_crime.md),
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
outcomes <- lamp_read_outcomes(cache, forces = "dyfed-powys", months = "2026-07")
table(outcomes$outcome_group)
#> 
#>    charged_or_summonsed            out_of_court              no_suspect 
#>                      79                      31                     212 
#> evidential_difficulties                   other                 unknown 
#>                     527                      47                       0 
```

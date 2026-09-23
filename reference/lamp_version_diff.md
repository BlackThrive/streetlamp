# Compare the archive versions of one force-month file

Reads every available version of a file and reports what differs: the
number of rows, and for street and outcomes files the crime identifiers
present in one version but not another. Street files routinely differ
between snapshots only in their `Last outcome category` column, which is
why row and identifier counts, not checksums, decide whether a force
re-supplied a month.

## Usage

``` r
lamp_version_diff(
  snapshot,
  force,
  month,
  file_type = c("street", "outcomes", "stop-and-search"),
  fetch = FALSE
)
```

## Arguments

- snapshot:

  A `lamp_snapshot` from
  [`lamp_archive_snapshot()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_snapshot.md).

- force:

  A police.uk force identifier.

- month:

  A month as `"YYYY-MM"` or a Date.

- file_type:

  One of `"street"`, `"outcomes"`, `"stop-and-search"`.

- fetch:

  Fetch versions that are listed but not held locally (needs network
  access).

## Value

A tibble with one row per version: `archive`, `n_rows`, `n_ids`
(distinct crime identifiers; `NA` for stop-and-search files),
`ids_not_in_others` (identifiers absent from every other version) and
`crc32`. The attribute `outcome_changes` gives, for street files, the
number of shared crimes whose last outcome category differs between the
oldest and newest versions.

## See also

Other ingest:
[`lamp_archive_download()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_download.md),
[`lamp_archive_index()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_index.md),
[`lamp_archive_register()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_register.md),
[`lamp_archive_snapshot()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_snapshot.md),
[`lamp_list_versions()`](https://blackthrive.github.io/streetlamp/reference/lamp_list_versions.md),
[`lamp_lsoa_vintage()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_vintage.md),
[`lamp_read_crime()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_crime.md),
[`lamp_read_outcomes()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_outcomes.md),
[`lamp_read_stop_counts()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_stop_counts.md),
[`lamp_s60_legislation()`](https://blackthrive.github.io/streetlamp/reference/lamp_s60_legislation.md),
[`lamp_select_version()`](https://blackthrive.github.io/streetlamp/reference/lamp_select_version.md)

## Examples

``` r
cache <- tempfile("streetlamp-cache-")
zips <- list.files(
  system.file("extdata", "archive", package = "streetlamp"),
  pattern = "zip$", full.names = TRUE
)
for (z in zips) lamp_archive_register(z, dir = cache)
#> Registered archive "2026-06" from
#> /home/runner/work/_temp/Library/streetlamp/extdata/archive/2026-06.zip.
#> Registered archive "2026-07" from
#> /home/runner/work/_temp/Library/streetlamp/extdata/archive/2026-07.zip.
snap <- lamp_archive_snapshot(cache)
lamp_version_diff(snap, "west-yorkshire", "2026-05", "outcomes")
#> # A tibble: 2 × 5
#>   archive n_rows n_ids ids_not_in_others crc32   
#>   <chr>    <int> <int>             <int> <chr>   
#> 1 2026-06   1761  1728                 3 efe93414
#> 2 2026-07   1756  1725                 0 34133345
```

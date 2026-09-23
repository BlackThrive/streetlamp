# List the archive versions of every force-month file

List the archive versions of every force-month file

## Usage

``` r
lamp_list_versions(snapshot, file_types = NULL)
```

## Arguments

- snapshot:

  A `lamp_snapshot` from
  [`lamp_archive_snapshot()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_snapshot.md).

- file_types:

  Restrict to some of `"street"`, `"outcomes"` and `"stop-and-search"`;
  `NULL` for all.

## Value

A tibble of class `lamp_versions` with one row per force, month and file
type: `n_versions`, `archives` (list-column of archive identifiers,
oldest first), `crc32` (list-column, aligned with `archives`), `differs`
(`TRUE` when the versions do not all share one checksum), `usize_min`,
`usize_max`, and `n_available` (versions readable locally).

## See also

Other ingest:
[`lamp_archive_download()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_download.md),
[`lamp_archive_index()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_index.md),
[`lamp_archive_register()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_register.md),
[`lamp_archive_snapshot()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_snapshot.md),
[`lamp_lsoa_vintage()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_vintage.md),
[`lamp_read_crime()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_crime.md),
[`lamp_read_outcomes()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_outcomes.md),
[`lamp_read_stop_counts()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_stop_counts.md),
[`lamp_s60_legislation()`](https://blackthrive.github.io/streetlamp/reference/lamp_s60_legislation.md),
[`lamp_select_version()`](https://blackthrive.github.io/streetlamp/reference/lamp_select_version.md),
[`lamp_version_diff()`](https://blackthrive.github.io/streetlamp/reference/lamp_version_diff.md)

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
v <- lamp_list_versions(lamp_archive_snapshot(cache))
v[v$n_versions > 1, c("force_id", "month", "file_type", "n_versions", "differs")]
#> # A tibble: 10 × 5
#>    force_id       month      file_type       n_versions differs
#>    <chr>          <date>     <chr>                <int> <lgl>  
#>  1 dyfed-powys    2026-05-01 outcomes                 2 TRUE   
#>  2 dyfed-powys    2026-05-01 street                   2 TRUE   
#>  3 dyfed-powys    2026-06-01 outcomes                 2 TRUE   
#>  4 dyfed-powys    2026-06-01 street                   2 TRUE   
#>  5 west-yorkshire 2026-05-01 outcomes                 2 TRUE   
#>  6 west-yorkshire 2026-05-01 stop-and-search          2 FALSE  
#>  7 west-yorkshire 2026-05-01 street                   2 TRUE   
#>  8 west-yorkshire 2026-06-01 outcomes                 2 FALSE  
#>  9 west-yorkshire 2026-06-01 stop-and-search          2 FALSE  
#> 10 west-yorkshire 2026-06-01 street                   2 TRUE   
```

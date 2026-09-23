# Select one archive version per force-month file

Select one archive version per force-month file

## Usage

``` r
lamp_select_version(versions, rule = c("latest", "earliest"), prefer = NULL)
```

## Arguments

- versions:

  Output of
  [`lamp_list_versions()`](https://blackthrive.github.io/streetlamp/reference/lamp_list_versions.md).

- rule:

  `"latest"` (default) takes the newest archive snapshot holding the
  file, on the grounds that later snapshots carry the most complete
  outcome information and any re-supplied data; `"earliest"` takes the
  oldest, which is the version closest to first publication.

- prefer:

  Optional archive identifiers to use whenever they hold the file,
  before applying `rule` to the rest.

## Value

A tibble of class `lamp_selection` with one row per force, month and
file type: the chosen `archive`, its `crc32` and `usize`, `n_versions`,
`differs`, `alternatives` (list-column of tibbles naming the other
archives with their checksums and sizes) and `rule`.

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
sel <- lamp_select_version(v, rule = "latest")
sel[, c("force_id", "month", "file_type", "archive", "n_versions")]
#> # A tibble: 15 × 5
#>    force_id       month      file_type       archive n_versions
#>    <chr>          <date>     <chr>           <chr>        <int>
#>  1 dyfed-powys    2026-05-01 outcomes        2026-07          2
#>  2 dyfed-powys    2026-05-01 street          2026-07          2
#>  3 dyfed-powys    2026-06-01 outcomes        2026-07          2
#>  4 dyfed-powys    2026-06-01 street          2026-07          2
#>  5 dyfed-powys    2026-07-01 outcomes        2026-07          1
#>  6 dyfed-powys    2026-07-01 street          2026-07          1
#>  7 west-yorkshire 2026-05-01 outcomes        2026-07          2
#>  8 west-yorkshire 2026-05-01 stop-and-search 2026-07          2
#>  9 west-yorkshire 2026-05-01 street          2026-07          2
#> 10 west-yorkshire 2026-06-01 outcomes        2026-07          2
#> 11 west-yorkshire 2026-06-01 stop-and-search 2026-07          2
#> 12 west-yorkshire 2026-06-01 street          2026-07          2
#> 13 west-yorkshire 2026-07-01 outcomes        2026-07          1
#> 14 west-yorkshire 2026-07-01 stop-and-search 2026-07          1
#> 15 west-yorkshire 2026-07-01 street          2026-07          1
```

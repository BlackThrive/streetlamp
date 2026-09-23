# Snapshot of the archive files held locally

Describes what the cache directory holds: which archive snapshots have
been listed, and for every force-month file in them whether its content
is available locally, either because it was fetched by
[`lamp_archive_download()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_download.md)
or because the whole zip was registered with
[`lamp_archive_register()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_register.md).
The snapshot is the starting point for
[`lamp_list_versions()`](https://blackthrive.github.io/streetlamp/reference/lamp_list_versions.md)
and the readers.

## Usage

``` r
lamp_archive_snapshot(dir = lamp_cache_dir())
```

## Arguments

- dir:

  Cache directory; see
  [`lamp_cache_dir()`](https://blackthrive.github.io/streetlamp/reference/lamp_cache_dir.md).

## Value

A list of class `lamp_snapshot` with elements `dir`, `archives` (one row
per archive: `archive`, `source`, `kind`, `size`, `etag`,
`last_modified`, `md5`, `n_members`, `listed_at`) and `members` (one row
per file: `archive`, `member`, `month`, `force_id`, `file_type`,
`crc32`, `csize`, `usize`, `available`, `path`, `sha256`, `fetched_at`).

## See also

Other ingest:
[`lamp_archive_download()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_download.md),
[`lamp_archive_index()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_index.md),
[`lamp_archive_register()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_register.md),
[`lamp_list_versions()`](https://blackthrive.github.io/streetlamp/reference/lamp_list_versions.md),
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
snap <- lamp_archive_snapshot(cache)
snap
#> 
#> ── streetlamp archive snapshot 
#> Cache: /tmp/RtmpCXBCb7/streetlamp-cache-1ddb3e721fe2
#> 2 archives: "2026-06" and "2026-07"
#> 25 force-month files covering 2 forces, 2026-05 to 2026-07; 25 available
#> locally.
#>   outcomes: 10 of 10 available
#>   stop-and-search: 5 of 5 available
#>   street: 10 of 10 available
table(snap$members$force_id, snap$members$file_type)
#>                 
#>                  outcomes stop-and-search street
#>   dyfed-powys           5               0      5
#>   west-yorkshire        5               5      5
```

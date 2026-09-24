# Register a locally downloaded archive zip

Makes a complete archive zip that was downloaded by other means (for
example in a browser) available to
[`lamp_archive_snapshot()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_snapshot.md)
without copying it: the zip is listed and every member becomes readable
in place.

## Usage

``` r
lamp_archive_register(path, dir = lamp_cache_dir(), md5 = NA_character_)
```

## Arguments

- path:

  Path to a zip named like the archive it came from, for example
  `2026-07.zip`; the name gives the archive identifier.

- dir:

  Cache directory; see
  [`lamp_cache_dir()`](https://blackthrive.github.io/streetlamp/reference/lamp_cache_dir.md).

- md5:

  Optional published checksum to record with the archive.

## Value

The archive identifier, invisibly.

## See also

Other ingest:
[`lamp_archive_download()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_download.md),
[`lamp_archive_index()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_index.md),
[`lamp_archive_snapshot()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_snapshot.md),
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
zip <- system.file("extdata", "archive", "2026-07.zip", package = "streetlamp")
lamp_archive_register(zip, dir = cache)
#> Registered archive "2026-07" from
#> /home/runner/work/_temp/Library/streetlamp/extdata/archive/2026-07.zip.
lamp_archive_snapshot(cache)
#> 
#> ── streetlamp archive snapshot 
#> Cache: /tmp/RtmpcntXqH/streetlamp-cache-1d9b7d494924
#> 1 archive: "2026-07"
#> 15 force-month files covering 2 forces, 2026-05 to 2026-07; 15 available
#> locally.
#>   outcomes: 6 of 6 available
#>   stop-and-search: 3 of 3 available
#>   street: 6 of 6 available
```

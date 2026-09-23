# Count stops by area and month

Reads the selected `stop-and-search` files and counts searches by area
and month, with a Section 60 flag. Only the `Date`, `Latitude`,
`Longitude` and `Legislation` columns are read; the package never parses
the ethnicity, object, outcome or other fields. Area assignment is by
point-in-polygon in British National Grid (EPSG:27700) against
boundaries you supply; without boundaries, counts are per force (the
force that submitted the file). Stops are dated by the month of the file
they were published in: the publisher stores local time as UTC, so a
handful of searches made after 23:00 on the first night of a summer-time
month carry the previous month's date, and the count of such rows is
reported per file as `n_outside_month`.

## Usage

``` r
lamp_read_stop_counts(
  dir = lamp_cache_dir(),
  versions = NULL,
  area = "force",
  boundaries = NULL,
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

- area:

  `"force"` (default) for force-month counts, or `"lsoa21"`, `"lsoa11"`
  or another label describing the polygons in `boundaries`.

- boundaries:

  An `sf` polygon layer with an `area` column giving the area
  identifier; required unless `area = "force"`.
  [`lamp_boundaries()`](https://blackthrive.github.io/streetlamp/reference/lamp_boundaries.md)
  provides ONS LSOA boundaries.

- months, forces:

  Optional filters, as in
  [`lamp_archive_download()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_download.md).

- fetch:

  Fetch selected files that are listed in the snapshot but not held
  locally (needs network access). With the default `FALSE` only the
  files held locally are read, with a message saying how many were
  skipped, so a reader never starts a large download on its own.

## Value

A tibble of class `lamp_records` with one row per area and month:
`area`, `month`, `force_id` (the submitting force), `stops`, `stops_s60`
and `archive`; for `area = "force"` also `stops_no_location` (searches
without coordinates, which cannot be placed in an area) and
`stops_no_legislation`. The contract's `stops` element records the
origin (`streetlamp`), the definition (`raw count`), the area type and
per-file diagnostics, and its `coverage` element marks force-months with
no stop-and-search file as `missing`.

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
stops <- lamp_read_stop_counts(cache, forces = c("west-yorkshire", "dyfed-powys"))
stops
#> streetlamp records with a contract; see `lamp_contract()`.
#> # A tibble: 3 × 8
#>   area           force_id   month      archive stops stops_s60 stops_no_location
#>   <chr>          <chr>      <date>     <chr>   <int>     <int>             <int>
#> 1 west-yorkshire west-york… 2026-05-01 2026-07  1254         0                10
#> 2 west-yorkshire west-york… 2026-06-01 2026-07  1095         0                10
#> 3 west-yorkshire west-york… 2026-07-01 2026-07  1130         0                10
#> # ℹ 1 more variable: stops_no_legislation <int>
lamp_contract(stops)$coverage
#> # A tibble: 6 × 8
#>   force_id       month      file_type       status  archive n_records n_versions
#>   <chr>          <date>     <chr>           <chr>   <chr>       <int>      <int>
#> 1 dyfed-powys    2026-05-01 stop-and-search missing NA             NA          0
#> 2 dyfed-powys    2026-06-01 stop-and-search missing NA             NA          0
#> 3 dyfed-powys    2026-07-01 stop-and-search missing NA             NA          0
#> 4 west-yorkshire 2026-05-01 stop-and-search submit… 2026-07      1254          1
#> 5 west-yorkshire 2026-06-01 stop-and-search submit… 2026-07      1095          1
#> 6 west-yorkshire 2026-07-01 stop-and-search submit… 2026-07      1130          1
#> # ℹ 1 more variable: versions_differ <lgl>
```

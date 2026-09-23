# Index of the data.police.uk archive

Lists the monthly archive snapshots published at
<https://data.police.uk/data/archive/>: one zip per month, each holding
the street, outcomes and stop-and-search CSV files for every force and,
since the May 2017 snapshot, a rolling window of the latest 36 months
(earlier snapshots hold every month back to December 2010). The index is
fetched once and cached; pass `refresh = TRUE` to fetch it again.
Without network access a cached index is returned with a warning, and an
error of class `streetlamp_error_network` is raised if there is no
cache.

## Usage

``` r
lamp_archive_index(refresh = FALSE, dir = lamp_cache_dir())
```

## Arguments

- refresh:

  Fetch the page again even if a cached copy exists.

- dir:

  Cache directory; see
  [`lamp_cache_dir()`](https://blackthrive.github.io/streetlamp/reference/lamp_cache_dir.md).

## Value

A tibble of class `lamp_archive_index` with one row per snapshot:
`archive` (identifier such as `"2026-07"`), `label`, `url`, `from` and
`to` (first and last data month in the zip), `n_months`, `size_gb` (as
shown on the page) and `md5` (the published checksum of the zip). The
attribute `fetched_at` records when the page was read.

## See also

Other ingest:
[`lamp_archive_download()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_download.md),
[`lamp_archive_register()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_register.md),
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
if (FALSE) {
# Requires network access
idx <- lamp_archive_index()
idx[idx$archive >= "2026-01", ]
}
```

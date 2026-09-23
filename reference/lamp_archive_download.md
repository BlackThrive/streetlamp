# Download force-month files from the data.police.uk archive

Fetches the street, outcomes and stop-and-search CSV files for chosen
months and forces from one or more archive snapshots, without
downloading the whole zip: the zip's table of contents is read with an
HTTP byte-range request and each wanted file is then fetched by range
and inflated locally. Files already present in the cache with a matching
checksum are skipped. Each fetched file is recorded with its CRC32 from
the archive, a SHA-256 of its content and the time of download, which is
what the panel contract reports as provenance.

## Usage

``` r
lamp_archive_download(
  archives = "latest",
  months = NULL,
  forces = NULL,
  file_types = c("street", "outcomes", "stop-and-search"),
  dir = lamp_cache_dir(),
  index = NULL,
  relist = FALSE
)
```

## Arguments

- archives:

  Archive identifiers such as `c("2026-06", "2026-07")`, or `"latest"`
  (the default) for the newest snapshot in
  [`lamp_archive_index()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_index.md).

- months:

  Months to fetch as `"YYYY-MM"` strings or Dates; `NULL` for every
  month in the archive.

- forces:

  police.uk force identifiers such as `"west-yorkshire"`; `NULL` for
  every force. See
  [`lamp_forces()`](https://blackthrive.github.io/streetlamp/reference/lamp_forces.md).

- file_types:

  Which of `"street"`, `"outcomes"` and `"stop-and-search"` to fetch.

- dir:

  Cache directory; see
  [`lamp_cache_dir()`](https://blackthrive.github.io/streetlamp/reference/lamp_cache_dir.md).

- index:

  An archive index from
  [`lamp_archive_index()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_index.md),
  to avoid fetching it again.

- relist:

  Read the archive's table of contents again even if it has been listed
  before.

## Value

A `lamp_snapshot` (see
[`lamp_archive_snapshot()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_snapshot.md))
for `dir`, invisibly.

## See also

Other ingest:
[`lamp_archive_index()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_index.md),
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
# Requires network access; fetches about 20 MB
snap <- lamp_archive_download(
  archives = "latest", months = c("2026-05", "2026-06", "2026-07"),
  forces = c("west-yorkshire", "dyfed-powys")
)
snap
}
```

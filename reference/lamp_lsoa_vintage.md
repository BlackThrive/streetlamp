# Detect whether LSOA codes are 2011 or 2021 vintage

Matches codes against the bundled ONS code lists
([`lamp_lsoa_codes()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_lookup.md)).
Codes that exist in only one vintage decide the answer; when a file has
none of those (possible for very small forces), the publication month
decides, because data.police.uk moved to 2021 codes with the June 2023
data.

## Usage

``` r
lamp_lsoa_vintage(x, month = NULL)
```

## Arguments

- x:

  A character vector of LSOA codes, or a records table from
  [`lamp_read_crime()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_crime.md)
  or
  [`lamp_read_outcomes()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_outcomes.md)
  (which is assessed one file at a time).

- month:

  Optional month (Date or `"YYYY-MM"`) used only when the codes are
  ambiguous and `x` is a character vector.

## Value

A tibble with one row per file (or one row for a vector) and columns
`vintage` (`"lsoa11"`, `"lsoa21"`, `"mixed"` or `"ambiguous"`), `basis`
(`"codes"` or `"month"`), `n_codes`, `n_only_2011`, `n_only_2021`,
`n_both` and `n_unknown`, preceded by `archive`, `file`, `force_id` and
`month` for records.

## See also

Other ingest:
[`lamp_archive_download()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_download.md),
[`lamp_archive_index()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_index.md),
[`lamp_archive_register()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_register.md),
[`lamp_archive_snapshot()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_snapshot.md),
[`lamp_list_versions()`](https://blackthrive.github.io/streetlamp/reference/lamp_list_versions.md),
[`lamp_read_crime()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_crime.md),
[`lamp_read_outcomes()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_outcomes.md),
[`lamp_read_stop_counts()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_stop_counts.md),
[`lamp_s60_legislation()`](https://blackthrive.github.io/streetlamp/reference/lamp_s60_legislation.md),
[`lamp_select_version()`](https://blackthrive.github.io/streetlamp/reference/lamp_select_version.md),
[`lamp_version_diff()`](https://blackthrive.github.io/streetlamp/reference/lamp_version_diff.md)

## Examples

``` r
lamp_lsoa_vintage(c("E01000001", "E01000002", "E01035000"))
#> # A tibble: 1 × 7
#>   vintage basis n_codes n_only_2011 n_only_2021 n_both n_unknown
#>   <chr>   <chr>   <int>       <int>       <int>  <int>     <int>
#> 1 lsoa21  codes       3           0           1      2         0
lamp_lsoa_vintage(c("E01000001", "E01000002"), month = "2024-01")
#> # A tibble: 1 × 7
#>   vintage basis n_codes n_only_2011 n_only_2021 n_both n_unknown
#>   <chr>   <chr>   <int>       <int>       <int>  <int>     <int>
#> 1 lsoa21  month       2           0           0      2         0
```

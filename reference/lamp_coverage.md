# Coverage audit: which force-months exist, and can be compared

`lamp_coverage()` returns the force by month by file-type grid behind a
panel or a records table, with one status per cell (`submitted`,
`missing`, `not_read`, `refreshed`, `partial_suspected`), the record
count, the archive version used, any changelog note, and a `mismatch`
flag for months where a stop-and-search file exists without a street
file or the reverse. Its
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) method draws
the grid as a heat map.

## Usage

``` r
lamp_coverage(x, changelog = NULL)

lamp_coverage_compare(coverage, period_a, period_b, file_type = "street")
```

## Arguments

- x:

  A `lamp_panel` from
  [`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md)
  or records from
  [`lamp_read_crime()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_crime.md),
  [`lamp_read_outcomes()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_outcomes.md)
  or
  [`lamp_read_stop_counts()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_stop_counts.md).

- changelog:

  Optional
  [`lamp_changelog()`](https://blackthrive.github.io/streetlamp/reference/lamp_changelog.md)
  table; entries saying a force re-supplied months mark those months
  `refreshed`.

- coverage:

  A `lamp_coverage` table.

- period_a, period_b:

  Two periods, each a length-two vector of months (`"YYYY-MM"` or Dates)
  giving the first and last month inclusive.

- file_type:

  Which file type to compare (default `"street"`).

## Value

`lamp_coverage()` returns a tibble of class `lamp_coverage` with columns
`force_id`, `month`, `file_type`, `status`, `n_records`, `archive`,
`n_versions`, `versions_differ`, `note` and `mismatch`.

`lamp_coverage_compare()` returns a tibble with one row per force:
`n_months_a`, `n_usable_a`, `n_months_b`, `n_usable_b` (months with
status `submitted` or `refreshed`), `n_partial_a`, `n_partial_b`,
`n_refreshed_a`, `n_refreshed_b`, `n_mismatch_a`, `n_mismatch_b` and
`comparable` (`TRUE` when every month in both periods is `submitted`,
with no mismatch).

## Details

`lamp_coverage_compare()` summarises comparability per force between two
periods: the share of months with usable files, and whether every month
in both periods was submitted without refreshes, partial submissions or
mismatches.

## See also

Other panel:
[`lamp_adjacency()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency.md),
[`lamp_adjacency_from_nb()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency_from_nb.md),
[`lamp_boundaries()`](https://blackthrive.github.io/streetlamp/reference/lamp_boundaries.md),
[`lamp_changelog()`](https://blackthrive.github.io/streetlamp/reference/lamp_changelog.md),
[`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md),
[`lamp_population()`](https://blackthrive.github.io/streetlamp/reference/lamp_population.md),
[`lamp_revintage()`](https://blackthrive.github.io/streetlamp/reference/lamp_revintage.md)

## Examples

``` r
panel <- lamp_sample_panel()
cov <- lamp_coverage(panel)
cov
#> streetlamp coverage: 2 forces, 2 file types, 16 mismatched force-months.
#> # A tibble: 96 × 10
#>    force_id    month      file_type       status    n_records archive n_versions
#>    <chr>       <date>     <chr>           <chr>         <int> <chr>        <int>
#>  1 dyfed-powys 2024-08-01 stop-and-search submitted       279 2026-07          2
#>  2 dyfed-powys 2024-09-01 stop-and-search submitted       280 2026-07          2
#>  3 dyfed-powys 2024-10-01 stop-and-search submitted       355 2026-07          2
#>  4 dyfed-powys 2024-11-01 stop-and-search submitted       320 2026-07          2
#>  5 dyfed-powys 2024-12-01 stop-and-search submitted       221 2026-07          2
#>  6 dyfed-powys 2025-01-01 stop-and-search submitted       270 2026-07          2
#>  7 dyfed-powys 2025-02-01 stop-and-search submitted       271 2026-07          2
#>  8 dyfed-powys 2025-03-01 stop-and-search submitted       315 2026-07          2
#>  9 dyfed-powys 2025-04-01 stop-and-search submitted       273 2026-07          2
#> 10 dyfed-powys 2025-05-01 stop-and-search submitted       275 2026-07          2
#> # ℹ 86 more rows
#> # ℹ 3 more variables: versions_differ <lgl>, note <chr>, mismatch <lgl>
table(cov$file_type, cov$status)
#>                  
#>                   missing submitted
#>   stop-and-search       8        40
#>   street                0        48
# Dyfed-Powys stopped submitting stop-and-search files in December 2025
cov[cov$mismatch %in% TRUE, c("force_id", "month", "file_type", "status")]
#> Warning: Unknown or uninitialised column: `mismatch`.
#> streetlamp coverage: 1 force, 2 file types, 0 mismatched force-months.
#> # A tibble: 16 × 4
#>    force_id    month      file_type       status   
#>    <chr>       <date>     <chr>           <chr>    
#>  1 dyfed-powys 2025-12-01 stop-and-search missing  
#>  2 dyfed-powys 2026-01-01 stop-and-search missing  
#>  3 dyfed-powys 2026-02-01 stop-and-search missing  
#>  4 dyfed-powys 2026-03-01 stop-and-search missing  
#>  5 dyfed-powys 2026-04-01 stop-and-search missing  
#>  6 dyfed-powys 2026-05-01 stop-and-search missing  
#>  7 dyfed-powys 2026-06-01 stop-and-search missing  
#>  8 dyfed-powys 2026-07-01 stop-and-search missing  
#>  9 dyfed-powys 2025-12-01 street          submitted
#> 10 dyfed-powys 2026-01-01 street          submitted
#> 11 dyfed-powys 2026-02-01 street          submitted
#> 12 dyfed-powys 2026-03-01 street          submitted
#> 13 dyfed-powys 2026-04-01 street          submitted
#> 14 dyfed-powys 2026-05-01 street          submitted
#> 15 dyfed-powys 2026-06-01 street          submitted
#> 16 dyfed-powys 2026-07-01 street          submitted
lamp_coverage_compare(cov, c("2024-08", "2025-07"), c("2025-08", "2026-07"),
  file_type = "stop-and-search"
)
#> # A tibble: 2 × 12
#>   force_id   n_months_a n_usable_a n_months_b n_usable_b n_partial_a n_partial_b
#>   <chr>           <int>      <int>      <int>      <int>       <int>       <int>
#> 1 dyfed-pow…         12         12         12          4           0           0
#> 2 west-york…         12         12         12         12           0           0
#> # ℹ 5 more variables: n_refreshed_a <int>, n_refreshed_b <int>,
#> #   n_mismatch_a <int>, n_mismatch_b <int>, comparable <lgl>
```

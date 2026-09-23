# Re-vintage LSOA codes between 2011 and 2021

Converts a vector of LSOA codes from one vintage to the other with the
bundled ONS lookup
([`lamp_lsoa_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_lookup.md))
and reports how many areas were unchanged, split, merged or complex.
From 2011 to 2021 each code maps to its best-fit 2021 LSOA. From 2021 to
2011 unchanged and split LSOAs map to their single parent; a 2021 LSOA
formed by a merger maps to the first of its parents in code order, so
`lsoa21` panels are the recommended target.

## Usage

``` r
lamp_revintage(codes, from = c("lsoa11", "lsoa21"), to = c("lsoa21", "lsoa11"))
```

## Arguments

- codes:

  A character vector of LSOA codes.

- from, to:

  The vintages, `"lsoa11"` or `"lsoa21"`.

## Value

A list with `codes` (the mapped vector, `NA` where a code is not in the
lookup) and `summary` (counts of records and distinct areas by change
type and the share of areas that were split or merged).

## See also

Other panel:
[`lamp_adjacency()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency.md),
[`lamp_adjacency_from_nb()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency_from_nb.md),
[`lamp_boundaries()`](https://blackthrive.github.io/streetlamp/reference/lamp_boundaries.md),
[`lamp_changelog()`](https://blackthrive.github.io/streetlamp/reference/lamp_changelog.md),
[`lamp_coverage()`](https://blackthrive.github.io/streetlamp/reference/lamp_coverage.md),
[`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md),
[`lamp_population()`](https://blackthrive.github.io/streetlamp/reference/lamp_population.md)

## Examples

``` r
r <- lamp_revintage(c("E01000001", "E01000002", "E01033768"), from = "lsoa11", to = "lsoa21")
r$codes
#> [1] "E01000001" "E01000002" "E01033768"
r$summary$share_split_or_merged
#> [1] 0
```

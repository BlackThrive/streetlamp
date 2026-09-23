# Census 2021 usual resident population by area

Fetches the Census 2021 usual resident population of every 2021 LSOA in
England and Wales from the NOMIS API (table TS001, dataset `NM_2021_1`),
caches it, and returns it at the requested area level. Coarser levels
are sums of LSOA values through
[`lamp_area_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_area_lookup.md);
because ONS applies cell-key perturbation to small-area counts, these
sums differ from the published MSOA and district totals by a few
persons. 2011 LSOAs receive the population of the 2021 LSOAs that map to
them: unchanged and split LSOAs pass their value to their single parent,
and a 2021 LSOA formed by a merger shares its value equally among its
parents, so `lsoa11` values are approximate.

## Usage

``` r
lamp_population(
  area = c("lsoa21", "msoa21", "lad", "pfa", "lsoa11"),
  dir = lamp_cache_dir(),
  refresh = FALSE
)
```

## Arguments

- area:

  The area level: `"lsoa21"` (default), `"msoa21"`, `"lad"`, `"pfa"` or
  `"lsoa11"`.

- dir:

  Cache directory; see
  [`lamp_cache_dir()`](https://blackthrive.github.io/streetlamp/reference/lamp_cache_dir.md).

- refresh:

  Fetch from NOMIS again even if a cached copy exists.

## Value

A tibble with columns `area`, `name` (`NA` for aggregated levels) and
`population`, with attributes `area` (the level) and `source` (a list
naming the NOMIS dataset, the census, the geography type, the retrieval
time and the aggregation rule) that
[`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md)
copies into the contract.

## Details

Without network access a cached download is returned, and an error of
class `streetlamp_error_network` is raised if there is none.

## See also

Other panel:
[`lamp_adjacency()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency.md),
[`lamp_adjacency_from_nb()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency_from_nb.md),
[`lamp_boundaries()`](https://blackthrive.github.io/streetlamp/reference/lamp_boundaries.md),
[`lamp_changelog()`](https://blackthrive.github.io/streetlamp/reference/lamp_changelog.md),
[`lamp_coverage()`](https://blackthrive.github.io/streetlamp/reference/lamp_coverage.md),
[`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md),
[`lamp_revintage()`](https://blackthrive.github.io/streetlamp/reference/lamp_revintage.md)

## Examples

``` r
if (FALSE) {
# Requires network access on first use
pop <- lamp_population("lsoa21")
head(pop)
pfa <- lamp_population("pfa")
}
```

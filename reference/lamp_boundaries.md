# ONS digital boundaries as an sf layer

Fetches the generalised, clipped (BGC, 20 m) boundaries for a geography
from the ONS Open Geography Portal, in British National Grid
(EPSG:27700), and caches them. Products: 2021 LSOAs, 2011 LSOAs, 2021
MSOAs, December 2022 local authority districts (England and Wales only)
and December 2023 police force areas. The generalised boundaries suit
adjacency and mapping; a search made within a few metres of a boundary
can be assigned to the neighbouring area, so supply full-resolution
boundaries yourself for point-in-polygon work that needs that precision.

## Usage

``` r
lamp_boundaries(
  type = c("lsoa21", "lsoa11", "msoa21", "lad", "pfa"),
  dir = lamp_cache_dir(),
  refresh = FALSE
)
```

## Arguments

- type:

  One of `"lsoa21"` (default), `"lsoa11"`, `"msoa21"`, `"lad"` or
  `"pfa"`.

- dir:

  Cache directory; see
  [`lamp_cache_dir()`](https://blackthrive.github.io/streetlamp/reference/lamp_cache_dir.md).

- refresh:

  Fetch again even if a cached copy exists.

## Value

An `sf` object with columns `area` (code), `name` and `geometry`
(multipolygons, EPSG:27700), sorted by `area`, with attributes `vintage`
(for example `"lsoa21-bgc-v5"`), `product` (the ONS title and item
identifier) and `retrieved`.

## Details

Without network access a cached copy is returned, and an error of class
`streetlamp_error_network` is raised if there is none. A first fetch of
the 2021 LSOA layer reads about 50 MB in 18 pages.

Source: Office for National Statistics licensed under the Open
Government Licence v3.0; contains OS data, Crown copyright and database
right 2024.

## See also

Other panel:
[`lamp_adjacency()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency.md),
[`lamp_adjacency_from_nb()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency_from_nb.md),
[`lamp_changelog()`](https://blackthrive.github.io/streetlamp/reference/lamp_changelog.md),
[`lamp_coverage()`](https://blackthrive.github.io/streetlamp/reference/lamp_coverage.md),
[`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md),
[`lamp_population()`](https://blackthrive.github.io/streetlamp/reference/lamp_population.md),
[`lamp_revintage()`](https://blackthrive.github.io/streetlamp/reference/lamp_revintage.md)

## Examples

``` r
if (FALSE) {
# Requires network access on first use
pfa <- lamp_boundaries("pfa")
plot(sf::st_geometry(pfa))
adj <- lamp_adjacency(pfa)
}
```

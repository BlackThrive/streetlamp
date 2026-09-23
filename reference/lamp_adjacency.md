# Spatial adjacency for a set of areas

Builds a neighbour list and row-standardised spatial weights for area
polygons with `spdep`, for the spillover estimators and for Moran's I
diagnostics. Queen contiguity (any shared point) is the default; rook
contiguity needs a shared edge; `knn` links each area to its `k` nearest
neighbours by centroid and symmetrises the result. Areas with no
neighbours (islands) are allowed and counted.

## Usage

``` r
lamp_adjacency(boundaries, method = c("queen", "rook", "knn"), k = 6L)
```

## Arguments

- boundaries:

  An `sf` polygon layer with an `area` column, for example from
  [`lamp_boundaries()`](https://blackthrive.github.io/streetlamp/reference/lamp_boundaries.md).

- method:

  `"queen"` (default), `"rook"` or `"knn"`.

- k:

  Number of neighbours for `method = "knn"`.

## Value

A list of class `lamp_adjacency` with `areas` (identifiers in order),
`nb` (an `spdep` neighbour list), `listw` (row-standardised weights,
`style = "W"`), `method`, `k`, `n_islands`, `boundary_vintage` (taken
from the `vintage` attribute of `boundaries` when present) and
`created`.

## See also

Other panel:
[`lamp_adjacency_from_nb()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency_from_nb.md),
[`lamp_boundaries()`](https://blackthrive.github.io/streetlamp/reference/lamp_boundaries.md),
[`lamp_changelog()`](https://blackthrive.github.io/streetlamp/reference/lamp_changelog.md),
[`lamp_coverage()`](https://blackthrive.github.io/streetlamp/reference/lamp_coverage.md),
[`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md),
[`lamp_population()`](https://blackthrive.github.io/streetlamp/reference/lamp_population.md),
[`lamp_revintage()`](https://blackthrive.github.io/streetlamp/reference/lamp_revintage.md)

## Examples

``` r
squares <- sf::st_sf(
  area = c("a", "b", "c"),
  geometry = sf::st_sfc(
    sf::st_polygon(list(rbind(c(0, 0), c(1, 0), c(1, 1), c(0, 1), c(0, 0)))),
    sf::st_polygon(list(rbind(c(1, 0), c(2, 0), c(2, 1), c(1, 1), c(1, 0)))),
    sf::st_polygon(list(rbind(c(5, 5), c(6, 5), c(6, 6), c(5, 6), c(5, 5)))),
    crs = 27700
  )
)
adj <- lamp_adjacency(squares)
adj
#> streetlamp adjacency: 3 areas, queen contiguity, 2 links, 1 island.
adj$nb
#> Neighbour list object:
#> Number of regions: 3 
#> Number of nonzero links: 2 
#> Percentage nonzero weights: 22.22222 
#> Average number of links: 0.6666667 
#> 1 region with no links:
#> c
#> 2 disjoint connected subgraphs
```

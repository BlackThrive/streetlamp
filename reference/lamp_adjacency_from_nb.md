# Build an adjacency object from a neighbour list

Wraps an existing `spdep` neighbour list, for example the lattice built
by
[`lamp_simulate()`](https://blackthrive.github.io/streetlamp/reference/lamp_simulate.md),
in the object the spillover estimators expect.

## Usage

``` r
lamp_adjacency_from_nb(nb, areas, method = "supplied")
```

## Arguments

- nb:

  An `spdep` neighbour list.

- areas:

  Area identifiers in the same order as `nb`.

- method:

  Label recorded in the object.

## Value

A `lamp_adjacency` object.

## See also

Other panel:
[`lamp_adjacency()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency.md),
[`lamp_boundaries()`](https://blackthrive.github.io/streetlamp/reference/lamp_boundaries.md),
[`lamp_changelog()`](https://blackthrive.github.io/streetlamp/reference/lamp_changelog.md),
[`lamp_coverage()`](https://blackthrive.github.io/streetlamp/reference/lamp_coverage.md),
[`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md),
[`lamp_population()`](https://blackthrive.github.io/streetlamp/reference/lamp_population.md),
[`lamp_revintage()`](https://blackthrive.github.io/streetlamp/reference/lamp_revintage.md)

## Examples

``` r
sim <- lamp_simulate(n_areas = 16, n_months = 12, design = "spillover", seed = 1)
truth <- attr(sim, "truth")
lamp_adjacency_from_nb(truth$nb, truth$lattice$area)
#> streetlamp adjacency: 16 areas, supplied contiguity, 48 links, 0 islands.
```

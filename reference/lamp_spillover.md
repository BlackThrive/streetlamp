# Own-area and neighbour effects estimated together

Adds the treatment of an area's neighbours to the specification, so that
the effect on the area itself and the effect on its neighbours are
estimated in one model. This is what separates a reduction in crime from
its displacement next door: if searching an area pushes offending into
the surrounding areas, the own-area coefficient is negative and the
neighbour coefficient positive, and the net effect is their sum.

## Usage

``` r
lamp_spillover(
  panel,
  outcome = "crime_total",
  treatment,
  adjacency = NULL,
  rings = 1:2,
  cluster = c("area", "force"),
  family = c("poisson", "negbin", "ols_log", "ols_ihs"),
  controls = NULL
)
```

## Arguments

- panel:

  A `lamp_panel` from
  [`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md).

- outcome:

  The outcome column, for example `"crime_total"` or a crime type key
  from
  [`lamp_crime_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_crime_types.md).

- treatment:

  A
  [`lamp_treatment()`](https://blackthrive.github.io/streetlamp/reference/lamp_treatment.md)
  object, or the name of a panel column.

- adjacency:

  A
  [`lamp_adjacency()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency.md)
  object; taken from the panel's contract when not given.

- rings:

  Contiguity rings to include, default first and second order.

- cluster:

  `"area"` (default) or `"force"`.

- family:

  `"poisson"` (default, a Poisson pseudo-likelihood suited to counts),
  `"negbin"`, `"ols_log"` or `"ols_ihs"`.

- controls:

  Optional panel columns to include as covariates.

## Value

A `lamp_estimate` of class `lamp_spillover`, whose coefficients hold the
own-area effect and one neighbour effect per ring, and whose
`diagnostics$net` gives the implied net effect (own plus neighbours)
with a standard error from the full covariance matrix.

## Identifying assumption

Parallel trends as in two-way fixed effects, and in addition that the
treatment reaches an area only through its own treatment and that of the
rings included. If spillovers extend beyond the last ring, the areas
used as controls are themselves affected, and every coefficient is
biased toward zero.

## See also

Other estimators:
[`lamp_allocation()`](https://blackthrive.github.io/streetlamp/reference/lamp_allocation.md),
[`lamp_crimes_prevented()`](https://blackthrive.github.io/streetlamp/reference/lamp_crimes_prevented.md),
[`lamp_did_staggered()`](https://blackthrive.github.io/streetlamp/reference/lamp_did_staggered.md),
[`lamp_displacement_quotient()`](https://blackthrive.github.io/streetlamp/reference/lamp_displacement_quotient.md),
[`lamp_elasticity()`](https://blackthrive.github.io/streetlamp/reference/lamp_elasticity.md),
[`lamp_event_study()`](https://blackthrive.github.io/streetlamp/reference/lamp_event_study.md),
[`lamp_synth()`](https://blackthrive.github.io/streetlamp/reference/lamp_synth.md),
[`lamp_twfe()`](https://blackthrive.github.io/streetlamp/reference/lamp_twfe.md),
[`tidy.lamp_estimate()`](https://blackthrive.github.io/streetlamp/reference/tidy.lamp_estimate.md)

## Examples

``` r
sim <- lamp_simulate(
  n_areas = 49, n_months = 20, design = "spillover",
  effect = -0.3, spillover_effect = 0.15, seed = 1
)
adj <- lamp_adjacency_from_nb(attr(sim, "truth")$nb, attr(sim, "truth")$lattice$area)
truth <- attr(sim, "truth")
tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
fit <- lamp_spillover(sim, "crime_total", tr, adjacency = adj, rings = 1)
fit
#> 
#> ── streetlamp estimate: lamp_spillover 
#> Outcome: crime_total; family: Poisson pseudo-likelihood on counts
#> Treatment: event; clustered by area
#> Identifying assumption: Parallel trends, and no spillover beyond the rings
#> included: if there is any, control areas are treated too and every coefficient
#> is pulled toward zero.
#> Sample: 980 area-months in 49 areas; 0 rows dropped for coverage.
#> Dispersion: 0.951
#>                term estimate std_error statistic p_value conf_low conf_high
#>            own area  -0.1228     0.206    -0.598   0.550   -0.526     0.280
#>  neighbours, ring 1  -0.0902     0.221    -0.409   0.683   -0.523     0.342
#> Net effect (own plus neighbours): -0.213 [-0.306, -0.12]
```

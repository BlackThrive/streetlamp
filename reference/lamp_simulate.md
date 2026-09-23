# Simulate a panel with a known treatment effect

Generates an area-by-month panel from a known data-generating process,
for testing estimators and for the simulation evidence in the vignettes.
Crime counts are Poisson draws around area and month fixed effects, and
the treatment multiplies the mean of the affected crime types by
`exp(effect)`, so `effect` is a log point effect: -0.1 is a 9.5 percent
reduction.

## Usage

``` r
lamp_simulate(
  n_areas = 36L,
  n_months = 24L,
  design = c("staggered", "event", "continuous", "spillover"),
  effect = -0.15,
  spillover_effect = 0.05,
  adoption = NULL,
  missing = 0,
  base_rate = 8,
  population = 1500,
  seed = NULL
)
```

## Arguments

- n_areas:

  Number of areas.

- n_months:

  Number of months.

- design:

  One of `"staggered"`, `"event"`, `"continuous"` or `"spillover"`.

- effect:

  True treatment effect in log points on the affected crime types (for
  `continuous`, the elasticity of crime with respect to
  `log(stops + 1)`).

- spillover_effect:

  True neighbour effect in log points, used by the `spillover` design.

- adoption:

  Adoption months for the `staggered` design, as month indices within
  the panel; `NULL` picks three evenly spaced cohorts.

- missing:

  Share of force-months with no street file (0 to 1).

- base_rate:

  Expected monthly count per area before fixed effects.

- population:

  Population per area, used for `stop_rate`.

- seed:

  Random seed.

## Value

A `lamp_panel` with the usual columns plus `treat` (the treatment
variable) and, for the event and staggered designs, `rel_time` and
`cohort`. Its contract carries the treatment definition, and
`attr(x, "truth")` holds the true `effect`, the implied effect on the
crime total (`effect_crime_total`, smaller in size than `effect` because
bicycle theft is unaffected), `spillover_effect`, `design`, the affected
crime types, the treated areas, the event date, the adoption table and
the neighbour list.

## Details

Designs:

- `event`: one date; the areas in the treated half are treated from that
  month onward. Suits
  [`lamp_event_study()`](https://blackthrive.github.io/streetlamp/reference/lamp_event_study.md).

- `staggered`: areas adopt in cohorts spread across the middle of the
  period, with never-treated areas kept as controls. Plain two-way fixed
  effects are biased here, which is what
  [`lamp_did_staggered()`](https://blackthrive.github.io/streetlamp/reference/lamp_did_staggered.md)
  is for.

- `continuous`: every area has a stop intensity that varies over time,
  and the outcome responds to `log(stops + 1)` with elasticity `effect`.

- `spillover`: as `event`, and in addition the mean treatment of an
  area's first-order lattice neighbours shifts its outcome by
  `spillover_effect`, so an estimator that omits the neighbour term is
  biased.

Areas sit on a square lattice and belong to two forces, so that
force-month missingness, clustering and adjacency are all exercisable. A
share `missing` of force-months has no street file: those rows carry
`NA` counts and `coverage_status = "missing"`, exactly as a real panel
does. Bicycle theft is never affected by treatment, which makes it the
default placebo outcome in
[`lamp_placebo()`](https://blackthrive.github.io/streetlamp/reference/lamp_placebo.md).

## Examples

``` r
sim <- lamp_simulate(n_areas = 36, n_months = 24, design = "event", effect = -0.2)
sim
#> streetlamp panel: 36 simulated area x 24 months; see `lamp_contract()` and
#> `lamp_coverage()`.
#> # A tibble: 864 × 27
#>    area  month      force_id bicycle_theft burglary criminal_damage_and_…¹ drugs
#>    <chr> <date>     <chr>            <int>    <int>                  <int> <int>
#>  1 S000… 2018-01-01 sim-nor…             1        0                      1     1
#>  2 S000… 2018-02-01 sim-nor…             0        0                      0     0
#>  3 S000… 2018-03-01 sim-nor…             3        0                      2     2
#>  4 S000… 2018-04-01 sim-nor…             1        2                      1     1
#>  5 S000… 2018-05-01 sim-nor…             2        1                      0     1
#>  6 S000… 2018-06-01 sim-nor…             0        0                      0     3
#>  7 S000… 2018-07-01 sim-nor…             2        0                      2     1
#>  8 S000… 2018-08-01 sim-nor…             0        0                      1     1
#>  9 S000… 2018-09-01 sim-nor…             0        0                      1     0
#> 10 S000… 2018-10-01 sim-nor…             0        0                      2     0
#> # ℹ 854 more rows
#> # ℹ abbreviated name: ¹​criminal_damage_and_arson
#> # ℹ 20 more variables: other_crime <int>, other_theft <int>,
#> #   possession_of_weapons <int>, public_order <int>, robbery <int>,
#> #   shoplifting <int>, theft_from_the_person <int>, vehicle_crime <int>,
#> #   violence_and_sexual_offences <int>, crime_total <int>, asb <int>,
#> #   stops <int>, stops_s60 <int>, population <dbl>, stop_rate <dbl>, …
attr(sim, "truth")$effect
#> [1] -0.2
table(sim$coverage_status)
#> 
#> submitted 
#>       864 
```

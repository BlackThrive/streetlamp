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
  seed = NULL,
  cohort_effects = NULL,
  dynamic_effect = NULL,
  trend_violation = 0,
  dispersion = Inf,
  missing_mechanism = c("random", "high_outcome"),
  effect_scale = c("log", "additive")
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

- cohort_effects:

  Optional named numeric vector, with adoption month indices as names
  (e.g. `c("9" = -0.4, "13" = -0.1, "17" = 0.2)`). Replaces `effect` for
  those cohorts; requires the staggered design and exactly one value for
  every adopting cohort.

- dynamic_effect:

  Optional finite numeric multipliers for relative months 0, 1, ...; the
  last multiplier persists thereafter. For example `c(0, 0.5, 1)` gives
  a delayed, growing effect. Binary designs only.

- trend_violation:

  Differential monthly trend for ever-treated areas, in the same units
  as `effect`. Zero preserves the identifying assumption.

- dispersion:

  Negative-binomial size per crime type; `Inf` (default) gives Poisson
  counts. Smaller positive values give more overdispersion.

- missing_mechanism:

  `"random"` or `"high_outcome"`. The latter makes force-months with
  larger untreated expected counts more likely to be missing, as a
  stress test rather than an ignorable missingness claim.

- effect_scale:

  `"log"` (default) multiplies affected count means. `"additive"` adds
  `effect` counts to the combined affected outcome and uses an additive
  area/time baseline, so count-level parallel trends hold when
  `trend_violation = 0`. Non-positive type means are rejected.

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

## See also

Other simulation:
[`lamp_simulation_truth()`](https://blackthrive.github.io/streetlamp/reference/lamp_simulation_truth.md)

## Examples

``` r
sim <- lamp_simulate(n_areas = 36, n_months = 24, design = "event", effect = -0.2)
sim
#> streetlamp panel: 36 simulated area x 24 months; see `lamp_contract()` and
#> `lamp_coverage()`.
#> # A tibble: 864 × 28
#>    area  month      force_id bicycle_theft burglary criminal_damage_and_…¹ drugs
#>    <chr> <date>     <chr>            <int>    <int>                  <int> <int>
#>  1 S000… 2018-01-01 sim-nor…             0        0                      1     0
#>  2 S000… 2018-02-01 sim-nor…             1        3                      0     1
#>  3 S000… 2018-03-01 sim-nor…             1        2                      1     0
#>  4 S000… 2018-04-01 sim-nor…             3        0                      1     0
#>  5 S000… 2018-05-01 sim-nor…             0        0                      1     0
#>  6 S000… 2018-06-01 sim-nor…             0        1                      0     2
#>  7 S000… 2018-07-01 sim-nor…             0        0                      1     0
#>  8 S000… 2018-08-01 sim-nor…             0        1                      0     0
#>  9 S000… 2018-09-01 sim-nor…             0        2                      1     1
#> 10 S000… 2018-10-01 sim-nor…             1        1                      1     2
#> # ℹ 854 more rows
#> # ℹ abbreviated name: ¹​criminal_damage_and_arson
#> # ℹ 21 more variables: other_crime <int>, other_theft <int>,
#> #   possession_of_weapons <int>, public_order <int>, robbery <int>,
#> #   shoplifting <int>, theft_from_the_person <int>, vehicle_crime <int>,
#> #   violence_and_sexual_offences <int>, crime_total <int>,
#> #   affected_crime <int>, asb <int>, stops <int>, stops_s60 <int>, …
attr(sim, "truth")$effect
#> [1] -0.2
table(sim$coverage_status)
#> 
#> submitted 
#>       864 
```

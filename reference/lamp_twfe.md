# Two-way fixed effects estimate of the effect of stops on crime

Fits the outcome on the treatment with area and month fixed effects, so
that the effect is identified from changes within an area over time, net
of anything common to all areas in a month. Standard errors are
clustered at the level given in `cluster`.

## Usage

``` r
lamp_twfe(
  panel,
  outcome = "crime_total",
  treatment,
  controls = NULL,
  cluster = c("area", "force"),
  family = c("poisson", "negbin", "ols_log", "ols_ihs"),
  force_month = FALSE
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

- controls:

  Optional panel columns to include as covariates.

- cluster:

  `"area"` (default) or `"force"`.

- family:

  `"poisson"` (default, a Poisson pseudo-likelihood suited to counts),
  `"negbin"`, `"ols_log"` or `"ols_ihs"`.

- force_month:

  Add force-by-month fixed effects, which absorb anything that moved a
  whole force in a month (a recording change, a force-wide operation) at
  the cost of identifying only from within-force variation.

## Value

A `lamp_estimate` of class `lamp_twfe`: coefficients with clustered
standard errors and 95 percent intervals, the identifying assumption,
the exclusion table and a `diagnostics` list holding the dispersion
statistic and, when the panel carries adjacency, Moran's I of the
residuals.

## Identifying assumption

Treated and control areas would have followed parallel paths in the
outcome had the treatment not changed, once area and month fixed effects
are removed. With a continuous treatment this also requires that the
intensity of searching is unrelated to what else was changing in the
area, which police allocation makes doubtful: see
[`lamp_allocation()`](https://blackthrive.github.io/streetlamp/reference/lamp_allocation.md).

## When this estimator is the wrong one

With staggered adoption, two-way fixed effects compares later-treated
areas against already-treated ones, and the estimate can lie outside the
range of every area's true effect. Use
[`lamp_did_staggered()`](https://blackthrive.github.io/streetlamp/reference/lamp_did_staggered.md)
instead; this function warns when the treatment has more than one
adoption date.

## See also

Other estimators:
[`lamp_allocation()`](https://blackthrive.github.io/streetlamp/reference/lamp_allocation.md),
[`lamp_crimes_prevented()`](https://blackthrive.github.io/streetlamp/reference/lamp_crimes_prevented.md),
[`lamp_did_staggered()`](https://blackthrive.github.io/streetlamp/reference/lamp_did_staggered.md),
[`lamp_displacement_quotient()`](https://blackthrive.github.io/streetlamp/reference/lamp_displacement_quotient.md),
[`lamp_elasticity()`](https://blackthrive.github.io/streetlamp/reference/lamp_elasticity.md),
[`lamp_event_study()`](https://blackthrive.github.io/streetlamp/reference/lamp_event_study.md),
[`lamp_spillover()`](https://blackthrive.github.io/streetlamp/reference/lamp_spillover.md),
[`lamp_synth()`](https://blackthrive.github.io/streetlamp/reference/lamp_synth.md),
[`tidy.lamp_estimate()`](https://blackthrive.github.io/streetlamp/reference/tidy.lamp_estimate.md)

## Examples

``` r
sim <- lamp_simulate(n_areas = 24, n_months = 24, design = "event", effect = -0.2, seed = 2)
truth <- attr(sim, "truth")
tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
fit <- lamp_twfe(sim, "crime_total", tr)
fit
#> 
#> ── streetlamp estimate: lamp_twfe 
#> Outcome: crime_total; family: Poisson pseudo-likelihood on counts
#> Treatment: event; clustered by area
#> Identifying assumption: Parallel trends: treated and control areas would have
#> moved together in the outcome, net of area and month fixed effects.
#> Sample: 576 area-months in 24 areas; 0 rows dropped for coverage.
#> Dispersion: 0.972
#>   Term             Estimate  Std. error            95% CI       p
#>   ───────────────  ────────  ──────────  ────────────────  ──────
#>   Treated × after    −0.276      0.0572  [−0.388, −0.164]  <0.001
tidy(fit)
#> # A tibble: 1 × 7
#>   term  estimate std_error statistic    p_value conf_low conf_high
#>   <chr>    <dbl>     <dbl>     <dbl>      <dbl>    <dbl>     <dbl>
#> 1 treat   -0.276    0.0572     -4.82 0.00000143   -0.388    -0.164
```

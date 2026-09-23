# How stop and search activity follows recorded crime

Regresses searches on the crime recorded in previous months, with area
and month fixed effects. This is not an effect of crime on searching in
any causal sense; it is a description of how activity is allocated, and
it is here because without it the other estimators cannot be read
honestly.

## Usage

``` r
lamp_allocation(
  panel,
  stops = "stops",
  crime = "crime_total",
  crime_lags = 1:3,
  cluster = c("area", "force"),
  family = c("poisson", "ols_log")
)
```

## Arguments

- panel:

  A `lamp_panel`.

- stops:

  The activity column, default `"stops"`.

- crime:

  The crime column, default `"crime_total"`.

- crime_lags:

  Lags of crime to include, default 1 to 3.

- cluster:

  `"area"` (default) or `"force"`.

- family:

  `"poisson"` (default) or `"ols_log"`.

## Value

A `lamp_estimate` of class `lamp_allocation`, with one coefficient per
lag and `diagnostics$total` for their sum. The identifying assumption
field states plainly that the result is descriptive.

## Why this matters for every other estimate

If police search more where crime has just risen, then searching is a
response to crime as well as a possible cause of it. A regression of
crime on searches then mixes the two directions: the deterrent effect
pushes the coefficient down, the allocation response pushes it up, and
the estimate is the net of them. A positive coefficient here is the size
of the channel that has to be argued away before a stop-crime elasticity
or a difference-in-differences estimate can be called causal. A
coefficient near zero is the case in which the other estimates are
easier to defend.

## See also

Other estimators:
[`lamp_crimes_prevented()`](https://blackthrive.github.io/streetlamp/reference/lamp_crimes_prevented.md),
[`lamp_did_staggered()`](https://blackthrive.github.io/streetlamp/reference/lamp_did_staggered.md),
[`lamp_displacement_quotient()`](https://blackthrive.github.io/streetlamp/reference/lamp_displacement_quotient.md),
[`lamp_elasticity()`](https://blackthrive.github.io/streetlamp/reference/lamp_elasticity.md),
[`lamp_event_study()`](https://blackthrive.github.io/streetlamp/reference/lamp_event_study.md),
[`lamp_spillover()`](https://blackthrive.github.io/streetlamp/reference/lamp_spillover.md),
[`lamp_synth()`](https://blackthrive.github.io/streetlamp/reference/lamp_synth.md),
[`lamp_twfe()`](https://blackthrive.github.io/streetlamp/reference/lamp_twfe.md),
[`tidy.lamp_estimate()`](https://blackthrive.github.io/streetlamp/reference/tidy.lamp_estimate.md)

## Examples

``` r
sim <- lamp_simulate(n_areas = 24, n_months = 30, design = "continuous", seed = 1)
lamp_allocation(sim, crime_lags = 1:2)
#> 
#> ── streetlamp estimate: lamp_allocation 
#> Outcome: stops; family: Poisson pseudo-likelihood on counts
#> Treatment: lagged crime; clustered by area
#> Identifying assumption: None: this is descriptive. It measures how searching
#> has tracked recorded crime, not an effect of crime on searching.
#> Sample: 672 area-months in 24 areas; 0 rows dropped for coverage.
#> Dispersion: 0.925
#>             term estimate std_error statistic p_value conf_low conf_high
#>  .log_crime_lag1  -0.0637    0.0507     -1.26   0.208   -0.163    0.0356
#>  .log_crime_lag2   0.0566    0.0560      1.01   0.312   -0.053    0.1663
#> Sum over lags: -0.0071 [-0.145, 0.131]
#> No clear allocation response: searching does not track recent crime in this
#> panel, which makes the other estimates easier to read as effects.
```

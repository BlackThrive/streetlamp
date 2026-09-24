# Elasticity of crime with respect to stop and search

Estimates how recorded crime responds to the intensity of searching, as
a distributed lag of log crime on log stops with area and month fixed
effects. Three methods are offered, differing in how they handle the
fact that areas move together.

## Usage

``` r
lamp_elasticity(
  panel,
  outcome = "crime_total",
  stops = "stops",
  lags = 0:3,
  method = c("fe", "cce_mg", "cce_pooled"),
  cluster = c("area", "force"),
  min_months = 12L
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

- stops:

  The stop intensity column, default `"stops"`.

- lags:

  Lags of log stops to include, default 0 to 3.

- method:

  `"fe"`, `"cce_mg"` or `"cce_pooled"`.

- cluster:

  `"area"` (default) or `"force"`.

- min_months:

  Months an area needs before it enters a mean-group regression.

## Value

A `lamp_estimate` of class `lamp_elasticity`. Coefficients are the
lag-by-lag elasticities; `diagnostics$long_run` is their sum with a
standard error, `diagnostics$cd_test` is Pesaran's test, and
`diagnostics$area_coefficients` holds the per-area slopes for the mean
group estimator. The CD test sums over every pair of areas, so above two
thousand areas it is computed on a random sample of them, drawn with a
fixed seed: `cd_test$sampled` says whether that happened and
`cd_test$n_areas_used` how many areas went in.

## What an elasticity here is and is not

The coefficient is the percentage change in recorded crime associated
with a one percent change in searches, not the effect of a decision to
search more. Police send officers where crime is rising, so the
association runs in both directions;
[`lamp_allocation()`](https://blackthrive.github.io/streetlamp/reference/lamp_allocation.md)
measures that reverse channel and should be reported alongside. Read the
elasticity as a description of the joint movement unless the variation
in searching has an argued external source.

## Methods

- `fe`: area and month fixed effects only.

- `cce_mg`: the common correlated effects mean group estimator. The
  cross-sectional averages of the outcome and the regressors are added
  to each area's own time-series regression, and the area coefficients
  are averaged; the standard error is the spread of those coefficients,
  which makes no assumption that areas share a slope.

- `cce_pooled`: one pooled regression with the same averages added,
  which is more precise if the slope really is common.

Pesaran's CD test is reported in every case. It is computed on the
residuals of a regression with area effects only, because month dummies
would remove the common factor by construction and make the statistic
negative whatever the data looked like. A large statistic says the areas
move together, and that the `fe` standard errors are too small.

## References

Pesaran, M. H. (2006). Estimation and inference in large heterogeneous
panels with a multifactor error structure. Econometrica 74(4), 967-1012.

Chudik, A. and Pesaran, M. H. (2015). Common correlated effects
estimation of heterogeneous dynamic panel data models with weakly
exogenous regressors. Journal of Econometrics 188(2), 393-420.

## See also

Other estimators:
[`lamp_allocation()`](https://blackthrive.github.io/streetlamp/reference/lamp_allocation.md),
[`lamp_crimes_prevented()`](https://blackthrive.github.io/streetlamp/reference/lamp_crimes_prevented.md),
[`lamp_did_staggered()`](https://blackthrive.github.io/streetlamp/reference/lamp_did_staggered.md),
[`lamp_displacement_quotient()`](https://blackthrive.github.io/streetlamp/reference/lamp_displacement_quotient.md),
[`lamp_event_study()`](https://blackthrive.github.io/streetlamp/reference/lamp_event_study.md),
[`lamp_spillover()`](https://blackthrive.github.io/streetlamp/reference/lamp_spillover.md),
[`lamp_synth()`](https://blackthrive.github.io/streetlamp/reference/lamp_synth.md),
[`lamp_twfe()`](https://blackthrive.github.io/streetlamp/reference/lamp_twfe.md),
[`tidy.lamp_estimate()`](https://blackthrive.github.io/streetlamp/reference/tidy.lamp_estimate.md)

## Examples

``` r
sim <- lamp_simulate(n_areas = 30, n_months = 36, design = "continuous", seed = 1)
fit <- lamp_elasticity(sim, "crime_total", lags = 0:1)
fit
#> 
#> ── streetlamp estimate: lamp_elasticity 
#> Outcome: crime_total; family: least squares on log(1 + outcome)
#> Treatment: continuous; clustered by area
#> Identifying assumption: The association between searching and recorded crime,
#> net of area and month effects. Causal only if the variation in searching has a
#> source outside the crime process; see lamp_allocation().
#> Sample: 1050 area-months in 30 areas; 0 rows dropped for coverage.
#>         term estimate std_error statistic  p_value conf_low conf_high
#>  .log_s_lag0  -0.1510    0.0276     -5.46 0.000007   -0.205   -0.0968
#>  .log_s_lag1  -0.0467    0.0405     -1.15 0.258073   -0.126    0.0327
#> Sum over lags: -0.198 [-0.302, -0.0934]
#> Pesaran CD: 2.92 (p = 0.00351), mean pairwise correlation 0.024
fit$diagnostics$cd_test$statistic
#> [1] 2.918753
```

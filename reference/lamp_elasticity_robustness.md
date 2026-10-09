# Evaluate an explicit elasticity specification grid

Runs every requested outcome, lag window and family, retaining failures
and optional leave-one-area-out estimates. Register the primary outcome
and specification before examining the grid. These are dependent,
exploratory checks; selecting a favourable row does not establish a
cause. The OLS and Poisson rows target different quantities and should
not be interpreted as estimates of one common elasticity.

## Usage

``` r
lamp_elasticity_robustness(
  panel,
  outcomes = "crime_total",
  lags = list(current = 0L, short = 0:1, distributed = 0:3),
  families = c("poisson", "ols_log"),
  cluster = c("area", "force"),
  leave_one_out = FALSE
)
```

## Arguments

- panel:

  A `lamp_panel`.

- outcomes:

  Outcome column names.

- lags:

  A named list of non-negative integer lag vectors.

- families:

  Character vector containing `"poisson"`, `"ols_log"`, or both.

- cluster:

  `"area"` or `"force"`.

- leave_one_out:

  Also fit each specification after omitting each area. This can be
  expensive on large panels.

## Value

A tibble with every requested specification, omitted area, status, error
message, lag-sum estimate and interval, and observed sample sizes.

## See also

Other diagnostics:
[`lamp_design_audit()`](https://blackthrive.github.io/streetlamp/reference/lamp_design_audit.md),
[`lamp_effect_summary()`](https://blackthrive.github.io/streetlamp/reference/lamp_effect_summary.md),
[`lamp_placebo()`](https://blackthrive.github.io/streetlamp/reference/lamp_placebo.md),
[`lamp_pretrends()`](https://blackthrive.github.io/streetlamp/reference/lamp_pretrends.md),
[`lamp_trend_sensitivity()`](https://blackthrive.github.io/streetlamp/reference/lamp_trend_sensitivity.md)

## Examples

``` r
sim <- lamp_simulate(design = "continuous", n_areas = 12, seed = 1)
lamp_elasticity_robustness(sim, lags = list(current = 0, short = 0:1))
#> # A tibble: 4 × 14
#>   outcome    lag_specification lags  family omitted_area status message estimate
#>   <chr>      <chr>             <chr> <chr>  <chr>        <chr>  <chr>      <dbl>
#> 1 crime_tot… current           0     poiss… NA           ok     NA       -0.0519
#> 2 crime_tot… current           0     ols_l… NA           ok     NA       -0.0417
#> 3 crime_tot… short             0,1   poiss… NA           ok     NA        0.150 
#> 4 crime_tot… short             0,1   ols_l… NA           ok     NA        0.147 
#> # ℹ 6 more variables: std_error <dbl>, conf_low <dbl>, conf_high <dbl>,
#> #   n_rows <int>, n_areas <int>, n_clusters <int>
```

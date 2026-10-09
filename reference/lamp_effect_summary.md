# Summarise effects using their joint covariance

Computes a linear combination with the full covariance matrix. For
staggered estimates, the default is the backend's overall ATT and its
own weighting, rather than an equally weighted mean of dynamic
estimates.

## Usage

``` r
lamp_effect_summary(estimate, terms = NULL, weights = NULL, level = 0.95)
```

## Arguments

- estimate:

  A `lamp_estimate`.

- terms:

  Coefficient names; `NULL` selects all elasticity lags, post-event
  coefficients for an event study, or the treatment coefficient.

- weights:

  Numeric weights in the order of `terms`. Defaults to one for
  elasticity lags and equal averaging weights otherwise. Supplied
  weights are used as supplied, without normalisation.

- level:

  Confidence level between zero and one.

## Value

A one-row tibble with estimate, standard error, interval, confidence
level and the aggregation definition. Unsupported joint covariance is an
error, rather than an independence approximation.

## See also

Other diagnostics:
[`lamp_design_audit()`](https://blackthrive.github.io/streetlamp/reference/lamp_design_audit.md),
[`lamp_elasticity_robustness()`](https://blackthrive.github.io/streetlamp/reference/lamp_elasticity_robustness.md),
[`lamp_placebo()`](https://blackthrive.github.io/streetlamp/reference/lamp_placebo.md),
[`lamp_pretrends()`](https://blackthrive.github.io/streetlamp/reference/lamp_pretrends.md),
[`lamp_trend_sensitivity()`](https://blackthrive.github.io/streetlamp/reference/lamp_trend_sensitivity.md)

## Examples

``` r
sim <- lamp_simulate(design = "continuous", seed = 1)
lamp_effect_summary(lamp_elasticity(sim, lags = 0:1))
#> # A tibble: 1 × 6
#>   estimate std_error conf_low conf_high level definition                       
#>      <dbl>     <dbl>    <dbl>     <dbl> <dbl> <chr>                            
#> 1   -0.176    0.0620   -0.298   -0.0545  0.95 1 * .log_s_lag0 + 1 * .log_s_lag1
```

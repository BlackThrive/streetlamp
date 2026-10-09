# Sensitivity to a specified differential linear trend

Adjusts an event-study average for user-specified untreated trend
slopes. Each slope is an assumption in the model's outcome units per
month, not a trend estimated and treated as known. Intervals reflect
sampling uncertainty conditional on each slope. This is a transparent
linear bias calculation, not a general robust confidence procedure or a
test of parallel trends.

## Usage

``` r
lamp_trend_sensitivity(
  estimate,
  slopes,
  periods = NULL,
  reference = -1L,
  level = 0.95
)
```

## Arguments

- estimate:

  An estimate from
  [`lamp_event_study()`](https://blackthrive.github.io/streetlamp/reference/lamp_event_study.md).

- slopes:

  Finite numeric differential trend assumptions.

- periods:

  Post-event relative months to average; defaults to available
  post-event months.

- reference:

  Reference relative month; must match the fitted model.

- level:

  Confidence level.

## Value

A tibble with the assumed slope, implied bias and adjusted estimate and
interval for each scenario.

## See also

Other diagnostics:
[`lamp_design_audit()`](https://blackthrive.github.io/streetlamp/reference/lamp_design_audit.md),
[`lamp_effect_summary()`](https://blackthrive.github.io/streetlamp/reference/lamp_effect_summary.md),
[`lamp_elasticity_robustness()`](https://blackthrive.github.io/streetlamp/reference/lamp_elasticity_robustness.md),
[`lamp_placebo()`](https://blackthrive.github.io/streetlamp/reference/lamp_placebo.md),
[`lamp_pretrends()`](https://blackthrive.github.io/streetlamp/reference/lamp_pretrends.md)

## Examples

``` r
sim <- lamp_simulate(design = "event", seed = 1)
truth <- attr(sim, "truth")
tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
fit <- lamp_event_study(sim, "crime_total", tr, window = c(-4, 4))
lamp_trend_sensitivity(fit, c(-0.01, 0, 0.01))
#> # A tibble: 3 × 7
#>   slope  bias estimate std_error conf_low conf_high level
#>   <dbl> <dbl>    <dbl>     <dbl>    <dbl>     <dbl> <dbl>
#> 1 -0.01 -0.03   -0.166     0.138   -0.437    0.105   0.95
#> 2  0     0      -0.196     0.138   -0.467    0.0752  0.95
#> 3  0.01  0.03   -0.226     0.138   -0.497    0.0452  0.95
```

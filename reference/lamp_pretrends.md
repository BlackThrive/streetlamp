# Test and interpret pre-trends

Reports the joint test that every pre-period coefficient of an event
study is zero, and answers the question the test cannot: how large a
pre-trend could have been present without this test detecting it, and
how much bias that undetected pre-trend would put into the post-period
estimates.

## Usage

``` r
lamp_pretrends(estimate, power = c(0.5, 0.8), level = 0.05)
```

## Arguments

- estimate:

  A `lamp_estimate` from
  [`lamp_event_study()`](https://blackthrive.github.io/streetlamp/reference/lamp_event_study.md).

- power:

  Detection probabilities to report, default 0.5 and 0.8.

- level:

  Significance level of the pre-trend test, default 0.05.

## Value

A list of class `lamp_pretrends` with `test` (statistic, degrees of
freedom and p value), `coefficients` (the pre-period coefficients),
`power` (a tibble of `power`, `slope` in log points per month, and
`bias_mean_post`, the bias such a slope would add to the mean
post-period coefficient) and `interpretation`.

## Details

The power calculation follows the argument in Roth (2022) and is
implemented here rather than taken from another package. Under a linear
violation of parallel trends with slope `s` per month, the expected
pre-period coefficients are `s` times their relative time (measured from
the reference month), so the Wald statistic is non-central chi-square
with non-centrality `s^2 * t' V^-1 t`, where `t` is that vector of
relative times and `V` the clustered covariance of the pre-period
coefficients. Inverting this gives the slope the test detects with a
given probability. The bias column shows what that slope would add to
each post-period coefficient if it continued, which is the quantity that
matters: a test that passes while remaining blind to a trend big enough
to explain the result is not reassurance.

## References

Roth, J. (2022). Pretest with caution: event-study estimates after
testing for parallel trends. American Economic Review: Insights 4(3),
305-322.

## See also

Other diagnostics:
[`lamp_placebo()`](https://blackthrive.github.io/streetlamp/reference/lamp_placebo.md)

## Examples

``` r
sim <- lamp_simulate(n_areas = 24, n_months = 24, design = "event", effect = -0.25, seed = 5)
truth <- attr(sim, "truth")
tr <- lamp_treatment(
  sim, "event",
  date = truth$event_date, scope = truth$treated_areas, window = c(-6, 6)
)
es <- lamp_event_study(sim, "crime_total", tr, window = c(-6, 6))
pt <- lamp_pretrends(es)
pt
#> 
#> ── streetlamp pre-trend diagnostic 
#> Joint test of 5 pre-period coefficients: p = 0.456
#> Linear pre-trend the test would detect:
#>  power  slope bias_mean_post
#>    0.5 0.0399          0.160
#>    0.8 0.0541          0.216
#> The pre-trend test does not reject (p = 0.456), but it would detect a linear
#> trend of 0.054 log points a month only 80 percent of the time; such a trend
#> would shift the mean post-period coefficient by 0.22. Compare that with the
#> estimate itself before treating the test as reassurance.
```

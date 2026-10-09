# Recover exact expected outcomes from a simulated panel

Keeps count-level effects and log mean ratios distinct. This function
deliberately does not treat a log mean as the expectation of log counts.

## Usage

``` r
lamp_simulation_truth(
  panel,
  outcome = c("affected_crime", "crime_total"),
  scale = c("identity", "log_mean")
)
```

## Arguments

- panel:

  A panel returned by
  [`lamp_simulate()`](https://blackthrive.github.io/streetlamp/reference/lamp_simulate.md).

- outcome:

  `"affected_crime"` or `"crime_total"`.

- scale:

  `"identity"` for expected count differences or `"log_mean"` for log
  ratios of expected counts.

## Value

A tibble of area-month counterfactual means and exact effects, including
cohort, relative time and observed coverage status. For spillover
designs the effect includes the simulated neighbour exposure.

## See also

Other simulation:
[`lamp_simulate()`](https://blackthrive.github.io/streetlamp/reference/lamp_simulate.md)

## Examples

``` r
sim <- lamp_simulate(seed = 1)
head(lamp_simulation_truth(sim))
#> # A tibble: 6 × 11
#>   area   month      cohort rel_time treated coverage_status mean_untreated
#>   <chr>  <date>      <int>    <int>   <dbl> <chr>                    <dbl>
#> 1 S00001 2018-01-01      9       -8       0 submitted                 6.32
#> 2 S00001 2018-02-01      9       -7       0 submitted                 6.63
#> 3 S00001 2018-03-01      9       -6       0 submitted                 6.77
#> 4 S00001 2018-04-01      9       -5       0 submitted                 6.69
#> 5 S00001 2018-05-01      9       -4       0 submitted                 6.42
#> 6 S00001 2018-06-01      9       -3       0 submitted                 6.07
#> # ℹ 4 more variables: mean_treated <dbl>, effect <dbl>, outcome <chr>,
#> #   scale <chr>
```

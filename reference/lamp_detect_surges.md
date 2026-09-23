# Detect surges in stop and search activity

Flags area-months in which searches rise far above the area's recent
level, and returns them as a candidate staggered-adoption table. Two
methods are offered: a threshold of `k` standard deviations above the
area's trailing twelve-month mean, and a structural break test from
`strucchange`.

## Usage

``` r
lamp_detect_surges(
  panel,
  method = c("threshold", "breakpoints"),
  k = 2,
  min_months = 12L,
  min_stops = 3L
)
```

## Arguments

- panel:

  A `lamp_panel` with a `stops` column.

- method:

  `"threshold"` (default) or `"breakpoints"`.

- k:

  Threshold in standard deviations above the trailing mean.

- min_months:

  Months of history required before an area can be flagged.

- min_stops:

  Minimum searches in the month, so that tiny areas do not surge from
  one search to three.

## Value

A tibble of class `lamp_surges` with one row per area: `area`,
`adoption_month` (the first flagged month, `NA` if none), `n_flagged`,
`trailing_mean`, `trailing_sd`, `peak_stops` and `peak_ratio` (peak over
trailing mean). Pass it to
[`lamp_treatment()`](https://blackthrive.github.io/streetlamp/reference/lamp_treatment.md)
as `adoption` for a staggered design. The attribute `flags` holds every
flagged area-month.

## Endogeneity

A surge detected from the stop series is not an experiment. Police
deploy searches where crime has risen, so an area's first surge month is
correlated with its recent crime history and with anything else that
prompted the deployment. Treating a detected surge as exogenous will
mistake the response for the cause. Use this to explore where activity
changed and to pick candidate cases for a design with an external source
of variation, not as the primary design; and read
[`lamp_allocation()`](https://blackthrive.github.io/streetlamp/reference/lamp_allocation.md)
alongside any estimate that uses it.

## See also

Other treatment:
[`lamp_treatment()`](https://blackthrive.github.io/streetlamp/reference/lamp_treatment.md)

## Examples

``` r
sim <- lamp_simulate(n_areas = 16, n_months = 30, design = "event", seed = 3)
surges <- lamp_detect_surges(sim, min_stops = 5)
head(surges)
#> streetlamp surges: 6 of 6 areas flagged (threshold, k = 2).
#> ! Surges detected from the stop series are endogenous; see `lamp_detect_surges()`.
#> # A tibble: 6 × 7
#>   area  adoption_month n_flagged trailing_mean trailing_sd peak_stops peak_ratio
#>   <chr> <date>             <int>         <dbl>       <dbl>      <dbl>      <dbl>
#> 1 S000… 2019-04-01             3          7.79        3.48         16       2.05
#> 2 S000… 2019-03-01             2          7.80        3.46         16       2.05
#> 3 S000… 2019-03-01             2          8.24        3.75         16       1.94
#> 4 S000… 2019-03-01             2          8.90        3.49         16       1.80
#> 5 S000… 2019-03-01             5          8.40        4.30         21       2.50
#> 6 S000… 2019-03-01             1          9.32        4.18         19       2.04
```

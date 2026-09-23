# Placebo tests for a streetlamp estimate

Re-estimates the same specification under conditions in which the true
effect is zero, and compares the real estimate with that distribution.
An estimate that looks the same when the treatment is moved to the wrong
date, the wrong areas, or an outcome the intervention cannot plausibly
affect, is measuring something other than the intervention.

## Usage

``` r
lamp_placebo(
  estimate,
  type = c("time", "space", "outcome"),
  n = 200,
  outcome = "bicycle_theft",
  seed = NULL
)
```

## Arguments

- estimate:

  A `lamp_estimate`.

- type:

  `"time"`, `"space"` or `"outcome"`.

- n:

  Number of placebo draws for `type = "space"`.

- outcome:

  Placebo outcome for `type = "outcome"`, default `"bicycle_theft"`.

- seed:

  Random seed for `type = "space"`.

## Value

A list of class `lamp_placebo` with `type`, `actual` (the real
estimate), `distribution` (a tibble of placebo estimates), `p_value`,
`n_valid` and `interpretation`.

## Details

Types:

- `time`: the event is moved back to each month that leaves a full
  pre-period, and only pre-period data is used, so nothing real happens
  at the fake date.

- `space`: the same number of areas is drawn at random, keeping the real
  dates, and the treatment is reassigned to them.

- `outcome`: the same specification is run on a crime type the
  intervention is not expected to move (bicycle theft by default), which
  tests for anything that shifts recorded crime generally, such as a
  recording change.

The reported p value is the share of placebo estimates at least as large
in absolute value as the real one. It is a randomisation p value, not a
test of a specific null, and with few areas it is coarse.

## See also

Other diagnostics:
[`lamp_pretrends()`](https://blackthrive.github.io/streetlamp/reference/lamp_pretrends.md)

## Examples

``` r
sim <- lamp_simulate(n_areas = 20, n_months = 24, design = "event", effect = -0.3, seed = 6)
truth <- attr(sim, "truth")
tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
fit <- lamp_twfe(sim, "crime_total", tr)
lamp_placebo(fit, type = "space", n = 20, seed = 1)
#> 
#> ── streetlamp placebo: space 
#> Real estimate: -0.233 on crime_total
#> 20 placebo estimates; share at least as extreme: 0
#> The real estimate (-0.233) is larger than 100 percent of the placebo estimates,
#> which is what a real effect looks like.
```

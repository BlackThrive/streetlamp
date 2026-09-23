# Weighted displacement quotient

Measures whether crime prevented in a treated area reappeared in the
areas around it. The quotient compares the change in a buffer of
surrounding areas with the change in control areas, relative to the
change in the treated areas, following Bowers and Johnson (2003).

## Usage

``` r
lamp_displacement_quotient(
  panel,
  outcome = "crime_total",
  treated_areas,
  buffer_areas,
  control_areas,
  pre,
  post,
  n_boot = 1000,
  seed = NULL
)
```

## Arguments

- panel:

  A `lamp_panel`.

- outcome:

  The outcome column.

- treated_areas, buffer_areas, control_areas:

  Area identifiers.

- pre, post:

  Two-element vectors giving the first and last month of the before and
  after periods.

- n_boot:

  Bootstrap replications over areas, default 1000.

- seed:

  Random seed.

## Value

A list of class `lamp_wdq` with `wdq`, `conf_low`, `conf_high`, the
underlying totals, `success` (the treated area's change net of controls)
and `interpretation`.

## Details

The statistic is `WDQ = ((B1/C1) - (B0/C0)) / ((A1/C1) - (A0/C0))`,
where `A`, `B` and `C` are total crime in the treated, buffer and
control areas and the subscripts are the pre and post periods. Read it
as:

- negative: crime moved into the buffer, so the gain in the treated area
  is partly or wholly displacement;

- between 0 and 1: the buffer improved too, a diffusion of benefit
  smaller than the treated area's gain;

- above 1: the buffer improved more than the treated area.

The quotient is a descriptive ratio, not a causal estimate: it assumes
the control areas show what would have happened everywhere, and it is
unstable when the treated-area change is close to zero, which the
bootstrap interval will show as a very wide range.

## References

Bowers, K. J. and Johnson, S. D. (2003). Measuring the geographical
displacement and diffusion of benefit effects of crime prevention
activity. Journal of Quantitative Criminology 19(3), 275-301.

## See also

Other estimators:
[`lamp_allocation()`](https://blackthrive.github.io/streetlamp/reference/lamp_allocation.md),
[`lamp_crimes_prevented()`](https://blackthrive.github.io/streetlamp/reference/lamp_crimes_prevented.md),
[`lamp_did_staggered()`](https://blackthrive.github.io/streetlamp/reference/lamp_did_staggered.md),
[`lamp_elasticity()`](https://blackthrive.github.io/streetlamp/reference/lamp_elasticity.md),
[`lamp_event_study()`](https://blackthrive.github.io/streetlamp/reference/lamp_event_study.md),
[`lamp_spillover()`](https://blackthrive.github.io/streetlamp/reference/lamp_spillover.md),
[`lamp_synth()`](https://blackthrive.github.io/streetlamp/reference/lamp_synth.md),
[`lamp_twfe()`](https://blackthrive.github.io/streetlamp/reference/lamp_twfe.md),
[`tidy.lamp_estimate()`](https://blackthrive.github.io/streetlamp/reference/tidy.lamp_estimate.md)

## Examples

``` r
sim <- lamp_simulate(
  n_areas = 36, n_months = 20, design = "spillover",
  effect = -0.4, spillover_effect = 0.2, seed = 2
)
truth <- attr(sim, "truth")
areas <- truth$lattice$area
lamp_displacement_quotient(
  sim, "crime_total",
  treated_areas = truth$treated_areas[1:6],
  buffer_areas = truth$treated_areas[7:12],
  control_areas = setdiff(areas, truth$treated_areas),
  pre = c("2018-01", "2018-06"), post = c("2018-12", "2019-05"), n_boot = 50
)
#> 
#> ── Weighted displacement quotient 
#> Outcome: crime_total
#> WDQ: 3.93 [1.5, 69.4] from 50 of 50 bootstrap draws
#> Treated-area change net of controls: -0.02623
#> WDQ 3.93 is above 1: the buffer improved more than the treated areas, which is
#> hard to attribute to the intervention.
```

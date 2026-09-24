# Convert an estimate into crimes prevented per thousand searches

Takes an elasticity or a treatment effect and expresses it as the number
of crimes prevented per thousand searches at the sample mean, which is
the form in which the question is usually asked. The conversion is
arithmetic, not evidence: it inherits every assumption of the estimate
it is given, and adds more of its own. The assumption chain is returned
with the number and printed with it.

## Usage

``` r
lamp_crimes_prevented(
  estimate,
  panel,
  per_stops = 1000,
  stops_added = NULL,
  outcome_column = NULL,
  n_boot = 2000,
  seed = NULL
)
```

## Arguments

- estimate:

  A `lamp_estimate` from
  [`lamp_elasticity()`](https://blackthrive.github.io/streetlamp/reference/lamp_elasticity.md),
  [`lamp_twfe()`](https://blackthrive.github.io/streetlamp/reference/lamp_twfe.md),
  [`lamp_did_staggered()`](https://blackthrive.github.io/streetlamp/reference/lamp_did_staggered.md)
  or
  [`lamp_event_study()`](https://blackthrive.github.io/streetlamp/reference/lamp_event_study.md).

- panel:

  The panel the estimate was built from, for the sample means.

- per_stops:

  Searches to express the result per, default 1000.

- stops_added:

  For a treatment effect: the searches the intervention added per
  area-month. Required unless the estimate is an elasticity.

- outcome_column:

  The crime column to take the mean of; defaults to the estimate's
  outcome.

- n_boot:

  Bootstrap replications for the interval, default 2000.

- seed:

  Random seed.

## Value

A list of class `lamp_crimes_prevented` with `crimes_prevented`,
`conf_low`, `conf_high`, the inputs used, and `assumptions`, a character
vector naming every step from the estimate to the number.

## Details

For an elasticity `e`, a proportional change in searches `dS/S` changes
crime by `e * dS/S`, so at mean monthly crime `C` and mean searches `S`
the crimes prevented by an extra `per_stops` searches are
`-e * C * per_stops / S`. For a treatment effect in log points `b`, the
effect on crime is `C * (exp(b) - 1)`, and it is divided by the searches
the intervention actually added, which you must supply as `stops_added`
because a binary treatment does not say how much searching it involved.

## What this number does not include

It counts recorded crime only, so crimes not reported to the police are
invisible to it, and any change in recording practice is counted as a
change in crime. It assumes the effect is linear in searches over the
range considered, and that the average effect applies at the margin,
which is the opposite of what diminishing returns implies. It says
nothing about the costs of searching, which fall on the people searched.

## See also

Other estimators:
[`lamp_allocation()`](https://blackthrive.github.io/streetlamp/reference/lamp_allocation.md),
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
sim <- lamp_simulate(n_areas = 30, n_months = 30, design = "continuous", seed = 1)
el <- lamp_elasticity(sim, "crime_total", lags = 0:1)
lamp_crimes_prevented(el, sim)
#> 
#> ── Crimes prevented per 1000 searches 
#> 85.6 [-8.81, 179] on crime_total
#> 
#> ── Assumption chain 
#> 1. The elasticity is -0.0814, summed over lags 0, 1.
#> 2. The effect is proportional, so it scales with the mean level of crime.
#> 3. At the sample mean of 7.13 crimes and 6.78 searches per area-month.
#> 4. The association between searching and recorded crime, net of area and month
#> effects. Causal only if the variation in searching has a source outside the
#> crime process; see lamp_allocation().
#> 5. Recorded crime only: unreported crime and recording changes are not
#> separated.
#> 6. The average effect is applied at the margin, which ignores diminishing
#> returns.
```

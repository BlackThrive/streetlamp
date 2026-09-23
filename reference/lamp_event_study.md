# Event study around a dated intervention

Estimates one coefficient per month relative to the intervention, so
that the path of the outcome before and after the event is visible
rather than summarised in a single number. The months before the event
are the pre-trend test: if the outcome was already moving, the
parallel-trends assumption behind any difference-in-differences estimate
is in doubt.

## Usage

``` r
lamp_event_study(
  panel,
  outcome = "crime_total",
  event,
  window = c(-12, 12),
  reference = -1,
  cluster = c("area", "force"),
  family = c("poisson", "negbin", "ols_log", "ols_ihs"),
  controls = NULL,
  staggered_ok = FALSE
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

- event:

  A
  [`lamp_treatment()`](https://blackthrive.github.io/streetlamp/reference/lamp_treatment.md)
  object of type `event` or `binary`, or the name of a panel column
  holding relative time.

- window:

  The first and last relative month to estimate, default `c(-12, 12)`.
  Months outside it are pooled into endpoint bins so that they still
  contribute to the fixed effects.

- reference:

  The omitted relative month, default `-1` (the month before the event).

- cluster:

  `"area"` (default) or `"force"`.

- family:

  `"poisson"` (default, a Poisson pseudo-likelihood suited to counts),
  `"negbin"`, `"ols_log"` or `"ols_ihs"`.

- controls:

  Optional panel columns to include as covariates.

- staggered_ok:

  With several adoption dates, delegate to
  [`lamp_did_staggered()`](https://blackthrive.github.io/streetlamp/reference/lamp_did_staggered.md)
  instead of stopping.

## Value

A `lamp_estimate` of class `lamp_event_study`. Its coefficients carry a
`rel_time` column, and `diagnostics$pretrend_p` holds the joint test
that every pre-period coefficient is zero.

## Identifying assumption

In the absence of the event, treated areas would have followed the same
path as controls, net of area and month fixed effects. The pre-period
coefficients test a necessary consequence of this, not the assumption
itself: passing the test does not establish parallel trends, and with
few areas the test has little power to detect a trend that matters. See
[`lamp_pretrends()`](https://blackthrive.github.io/streetlamp/reference/lamp_pretrends.md).

## Staggered adoption

When areas adopt at different dates, relative-time dummies in a two-way
fixed effects regression use already-treated areas as controls and are
biased. This function never does that: with more than one adoption date
it stops and explains, or, with `staggered_ok = TRUE`, hands the work to
[`lamp_did_staggered()`](https://blackthrive.github.io/streetlamp/reference/lamp_did_staggered.md)
and says so. The result is then a `lamp_did_staggered` estimate, not an
event study.

## See also

Other estimators:
[`lamp_allocation()`](https://blackthrive.github.io/streetlamp/reference/lamp_allocation.md),
[`lamp_crimes_prevented()`](https://blackthrive.github.io/streetlamp/reference/lamp_crimes_prevented.md),
[`lamp_did_staggered()`](https://blackthrive.github.io/streetlamp/reference/lamp_did_staggered.md),
[`lamp_displacement_quotient()`](https://blackthrive.github.io/streetlamp/reference/lamp_displacement_quotient.md),
[`lamp_elasticity()`](https://blackthrive.github.io/streetlamp/reference/lamp_elasticity.md),
[`lamp_spillover()`](https://blackthrive.github.io/streetlamp/reference/lamp_spillover.md),
[`lamp_synth()`](https://blackthrive.github.io/streetlamp/reference/lamp_synth.md),
[`lamp_twfe()`](https://blackthrive.github.io/streetlamp/reference/lamp_twfe.md),
[`tidy.lamp_estimate()`](https://blackthrive.github.io/streetlamp/reference/tidy.lamp_estimate.md)

## Examples

``` r
sim <- lamp_simulate(n_areas = 24, n_months = 24, design = "event", effect = -0.25, seed = 4)
truth <- attr(sim, "truth")
# half the areas are treated; the rest are the comparison group
tr <- lamp_treatment(
  sim, "event",
  date = truth$event_date, scope = truth$treated_areas, window = c(-6, 6)
)
es <- lamp_event_study(sim, "crime_total", tr, window = c(-6, 6))
es
#> 
#> ── streetlamp estimate: lamp_event_study 
#> Outcome: crime_total; family: Poisson pseudo-likelihood on counts
#> Treatment: event; clustered by area
#> Identifying assumption: Parallel trends around the event: without it, treated
#> areas would have followed the control path, net of area and month fixed
#> effects. Pre-period coefficients test a consequence of this, not the
#> assumption.
#> Sample: 576 area-months in 24 areas; 0 rows dropped for coverage.
#> Pre-trend joint test: p = 0.966
#> Dispersion: 0.903
#>  rel_time estimate std_error conf_low conf_high p_value
#>        -6  -0.0757     0.169   -0.407    0.2556  0.6542
#>        -5  -0.0763     0.183   -0.436    0.2832  0.6775
#>        -4  -0.0974     0.207   -0.503    0.3081  0.6377
#>        -3  -0.1848     0.308   -0.789    0.4191  0.5486
#>        -2  -0.1481     0.184   -0.509    0.2131  0.4215
#>        -1   0.0000     0.000    0.000    0.0000      NA
#>         0  -0.2683     0.178   -0.617    0.0808  0.1319
#>         1  -0.4001     0.178   -0.749   -0.0512  0.0246
#>         2  -0.1790     0.184   -0.539    0.1814  0.3304
#>         3  -0.2711     0.191   -0.646    0.1037  0.1563
#>         4  -0.5098     0.198   -0.898   -0.1215  0.0101
#>         5  -0.2930     0.193   -0.672    0.0862  0.1299
#>         6  -0.3380     0.152   -0.636   -0.0400  0.0262
plot(es)
```

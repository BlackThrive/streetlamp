# Synthetic control for a single treated area or force

Builds a weighted average of untreated donor units whose pre-period path
matches the treated unit's, and reads the gap between them afterwards as
the effect. Inference is by permutation: the same procedure is run
pretending each donor was treated, and the treated unit's post-period
fit is compared with that distribution.

## Usage

``` r
lamp_synth(
  panel,
  outcome = "crime_total",
  treated_unit,
  treatment_start,
  donors = NULL,
  method = c("internal", "synth", "gsynth"),
  placebo = TRUE,
  min_pre = 6L
)
```

## Arguments

- panel:

  A `lamp_panel`.

- outcome:

  The outcome column.

- treated_unit:

  The area that was treated.

- treatment_start:

  The first treated month.

- donors:

  Candidate donor areas; `NULL` uses every other area that has a
  complete series.

- method:

  `"internal"` (default), `"synth"` or `"gsynth"`.

- placebo:

  Run in-space placebos over the donors for the permutation p value.

- min_pre:

  Months of pre-period required.

## Value

A list of class `lamp_synth` with `weights`, `path` (a tibble of month,
observed, synthetic and gap), `effect` (mean post-period gap),
`rmspe_pre`, `rmspe_post`, `rmspe_ratio`, `p_value` (the share of donors
with a ratio at least as large), `placebos` and `assumption`.

## Identifying assumption

The weighted donors reproduce what the treated unit would have done
without the intervention. This is credible only when the pre-period fit
is close over a long window, no donor was itself affected by the
intervention, and nothing else happened to the treated unit at the same
time. A poor pre-period fit invalidates the comparison, which is why the
pre-period root mean squared error is reported first.

## References

Abadie, A., Diamond, A. and Hainmueller, J. (2010). Synthetic control
methods for comparative case studies. Journal of the American
Statistical Association 105(490), 493-505.

Xu, Y. (2017). Generalized synthetic control method. Political Analysis
25(1), 57-76.

## See also

Other estimators:
[`lamp_allocation()`](https://blackthrive.github.io/streetlamp/reference/lamp_allocation.md),
[`lamp_crimes_prevented()`](https://blackthrive.github.io/streetlamp/reference/lamp_crimes_prevented.md),
[`lamp_did_staggered()`](https://blackthrive.github.io/streetlamp/reference/lamp_did_staggered.md),
[`lamp_displacement_quotient()`](https://blackthrive.github.io/streetlamp/reference/lamp_displacement_quotient.md),
[`lamp_elasticity()`](https://blackthrive.github.io/streetlamp/reference/lamp_elasticity.md),
[`lamp_event_study()`](https://blackthrive.github.io/streetlamp/reference/lamp_event_study.md),
[`lamp_spillover()`](https://blackthrive.github.io/streetlamp/reference/lamp_spillover.md),
[`lamp_twfe()`](https://blackthrive.github.io/streetlamp/reference/lamp_twfe.md),
[`tidy.lamp_estimate()`](https://blackthrive.github.io/streetlamp/reference/tidy.lamp_estimate.md)

## Examples

``` r
sim <- lamp_simulate(n_areas = 20, n_months = 30, design = "event", effect = -0.4, seed = 1)
truth <- attr(sim, "truth")
sc <- lamp_synth(
  sim, "crime_total",
  treated_unit = truth$treated_areas[1],
  treatment_start = truth$event_date,
  donors = setdiff(unique(sim$area), truth$treated_areas),
  placebo = FALSE
)
sc
#> 
#> ── streetlamp synthetic control 
#> Treated unit: "S00001" from 2019-03
#> Donors: 8; pre-period months: 14; post-period months: 16
#> Identifying assumption: The weighted donors reproduce what the treated unit
#> would have done without the intervention; no donor is itself affected by it.
#> Pre-period fit (root mean squared error): 3.23; post-period: 2.84; ratio 0.878
#> Mean post-period gap: -0.964
#> The synthetic unit does not track the treated unit before the intervention, so
#> the gap afterwards is not evidence of an effect.
#> Largest weights: S00014 0.66, S00019 0.24, S00017 0.06, S00015 0.04
```

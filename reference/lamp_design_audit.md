# Audit the support and assumptions of an intervention design

Reports missing submissions, pre/post support and detection-sensitive
outcomes. A clean data audit does not establish causal identification;
intervention assignment, contemporaneous changes and spillovers still
require substantive evidence.

## Usage

``` r
lamp_design_audit(
  panel,
  treatment = NULL,
  outcomes = "crime_total",
  min_pre = 6L,
  min_post = 6L
)
```

## Arguments

- panel:

  A `lamp_panel`.

- treatment:

  Optional dated
  [`lamp_treatment()`](https://blackthrive.github.io/streetlamp/reference/lamp_treatment.md)
  object.

- outcomes:

  Outcome columns under consideration.

- min_pre, min_post:

  Minimum observed months per treated area before and after adoption for
  the support audit.

## Value

A list with `issues` (check, status, detail), `area_support`, and
`summary`. Statuses describe data support or required arguments, not
certification of causality.

## See also

Other diagnostics:
[`lamp_effect_summary()`](https://blackthrive.github.io/streetlamp/reference/lamp_effect_summary.md),
[`lamp_elasticity_robustness()`](https://blackthrive.github.io/streetlamp/reference/lamp_elasticity_robustness.md),
[`lamp_placebo()`](https://blackthrive.github.io/streetlamp/reference/lamp_placebo.md),
[`lamp_pretrends()`](https://blackthrive.github.io/streetlamp/reference/lamp_pretrends.md),
[`lamp_trend_sensitivity()`](https://blackthrive.github.io/streetlamp/reference/lamp_trend_sensitivity.md)

## Examples

``` r
sim <- lamp_simulate(design = "event", seed = 1)
lamp_design_audit(sim)
#> $issues
#> # A tibble: 5 × 3
#>   check                             status            detail                    
#>   <chr>                             <chr>             <chr>                     
#> 1 observed outcomes and submissions supported         0 of 864 area-months unav…
#> 2 intervention assignment           requires_argument Document assignment, comp…
#> 3 observed stop intensity           supported         0 area-month stop counts …
#> 4 force-month source files          supported         0 crime/search force-mont…
#> 5 detection-sensitive outcomes      concern           Searching can change dete…
#> 
#> $area_support
#> # A tibble: 0 × 0
#> 
#> $summary
#> $summary$n_rows
#> [1] 864
#> 
#> $summary$n_areas
#> [1] 36
#> 
#> $summary$n_months
#> [1] 24
#> 
#> $summary$n_unavailable
#> [1] 0
#> 
#> $summary$source
#> [1] "simulated"
#> 
#> $summary$causal_identification
#> [1] "requires substantive evidence"
#> 
#> 
```

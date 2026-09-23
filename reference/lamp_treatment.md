# Define the treatment

Turns a panel into a treatment definition that the estimators can use: a
continuous stop intensity, a binary intervention in named areas and
months, staggered adoption dates by area, or a dated event applied to
every area. The result records how the treatment was built, is stored in
the contract of every estimate made with it, and is printed by the
estimators alongside their identifying assumption.

## Usage

``` r
lamp_treatment(
  panel,
  type = c("continuous", "binary", "staggered", "event"),
  measure = c("stop_rate", "stops", "stops_per_100_crimes"),
  transform = c("identity", "log", "ihs"),
  areas = NULL,
  window = NULL,
  adoption = NULL,
  event = NULL,
  date = NULL,
  scope = NULL
)
```

## Arguments

- panel:

  A `lamp_panel` from
  [`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md).

- type:

  `"continuous"`, `"binary"`, `"staggered"` or `"event"`.

- measure, transform:

  For `continuous`: which intensity and which transformation.

- areas:

  For `binary`: the treated areas.

- window:

  For `binary`: the first and last treated month. For `event`: the event
  window in months, default `c(-12, 12)`.

- adoption:

  For `staggered`: a table with columns `area` and `adoption_month`.

- event:

  For `event`: a name in
  [`lamp_shocks()`](https://blackthrive.github.io/streetlamp/reference/lamp_shocks.md),
  or `NULL` when `date` is given.

- date:

  For `event`: the event month, overriding the shocks table.

- scope:

  For `event`: areas the event applies to; `NULL` for all.

## Value

A `lamp_treatment` object: a list with `type`, `column` (the treatment
variable's name), `data` (area, month, the treatment column and, where
applicable, `rel_time` and `cohort`), `details`, `n_treated_areas`,
`n_control_areas` and `created`.

## Details

Types:

- `continuous`: `measure` is `"stops"`, `"stop_rate"` (per 1,000
  residents, the default) or `"stops_per_100_crimes"` (searches per 100
  crimes recorded in the area's previous twelve months, which removes
  the mechanical dependence on population). `transform` is `"identity"`,
  `"log"` (log of one plus the measure) or `"ihs"` (inverse hyperbolic
  sine, which handles zeros).

- `binary`: `areas` are treated during `window`, a pair of months, and
  untreated outside it; every other area is a control.

- `staggered`: `adoption` is a table of `area` and `adoption_month`.
  Areas absent from it are never treated. `rel_time` (months since
  adoption) and `cohort` are added.

- `event`: a dated shock applied to every area in scope, from
  [`lamp_shocks()`](https://blackthrive.github.io/streetlamp/reference/lamp_shocks.md)
  by `event` name or from `date`, with an event `window` in months
  around it. `rel_time` is months since the event.

A continuous treatment is a dose, not an experiment: the allocation of
searches to areas responds to crime, so estimates from it describe an
association unless the variation is argued to be exogenous. See
[`lamp_allocation()`](https://blackthrive.github.io/streetlamp/reference/lamp_allocation.md).

## See also

Other treatment:
[`lamp_detect_surges()`](https://blackthrive.github.io/streetlamp/reference/lamp_detect_surges.md)

## Examples

``` r
sim <- lamp_simulate(n_areas = 16, n_months = 18, design = "event", seed = 1)

# a dated event, twelve months either side
lamp_treatment(sim, "event", date = "2018-10", window = c(-6, 6))
#> 
#> ── streetlamp treatment 
#> Type: "event"; column treat
#> Areas: 16 treated, 0 control
#> Event: user-supplied event on 2018-10-01, window -6 to 6 months

# stop intensity as a continuous dose
lamp_treatment(sim, "continuous", measure = "stop_rate", transform = "ihs")
#> 
#> ── streetlamp treatment 
#> Type: "continuous"; column treat
#> Areas: 16 treated, 0 control
#> Measure: stop_rate, transform ihs

# a surge in named areas
lamp_treatment(sim, "binary", areas = unique(sim$area)[1:4], window = c("2018-06", "2018-12"))
#> 
#> ── streetlamp treatment 
#> Type: "binary"; column treat
#> Areas: 4 treated, 12 control
#> Never-treated areas: 12
```

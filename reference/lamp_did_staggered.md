# Difference-in-differences with staggered adoption

Estimates the effect of an intervention that different areas adopt at
different dates, using an estimator that compares each adopting cohort
with areas that have not yet adopted rather than with areas already
treated. Plain two-way fixed effects does the latter and can return an
estimate outside the range of every area's true effect; this function
exists so that staggered designs are not analysed that way.

## Usage

``` r
lamp_did_staggered(
  panel,
  outcome = "crime_total",
  treatment,
  estimator = c("callaway_santanna", "sun_abraham", "imputation"),
  control_group = c("never_treated", "not_yet_treated"),
  cluster = c("area", "force"),
  family = c("ols_log", "ols_ihs", "identity"),
  window = c(-12, 12)
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

- treatment:

  A
  [`lamp_treatment()`](https://blackthrive.github.io/streetlamp/reference/lamp_treatment.md)
  object of type `staggered` (or `event`, which is a single cohort).

- estimator:

  `"callaway_santanna"`, `"sun_abraham"` or `"imputation"`.

- control_group:

  `"never_treated"` (default) or `"not_yet_treated"`.

- cluster:

  `"area"` (default) or `"force"`.

- family:

  Scale for the outcome: `"ols_log"` (default, log of one plus the
  outcome), `"ols_ihs"` or `"identity"`.

- window:

  Relative months to report in the dynamic aggregation.

## Value

A `lamp_estimate` of class `lamp_did_staggered`. `coefficients` holds
the dynamic (event-study) aggregation with a `rel_time` column;
`diagnostics$overall` is the single summary effect with its standard
error; `diagnostics$group_time` holds the group-time effects for the
Callaway and Sant'Anna backend; and `diagnostics$pretrend_p` is that
backend's pre-test.

## Identifying assumption

Parallel trends holds for each adopting cohort against the chosen
control group, from the period before that cohort adopts onward, and
there is no anticipation: the outcome does not move before adoption in
response to it. With `control_group = "never_treated"` the comparison is
against areas that never adopt, which must exist; with
`"not_yet_treated"` it is against areas that adopt later, which uses
more data but assumes their later adoption carries no information about
their current path.

## Backends

- `callaway_santanna` (default) calls
  [`did::att_gt()`](https://bcallaway11.github.io/did/reference/att_gt.html)
  and
  [`did::aggte()`](https://bcallaway11.github.io/did/reference/aggte.html),
  giving one effect per cohort and period and the aggregations of them.

- `sun_abraham` uses
  [`fixest::sunab()`](https://lrberge.github.io/fixest/reference/sunab.html),
  an interaction-weighted estimator fitted in one regression.

- `imputation` uses the `didimputation` package, which fits the
  untreated potential outcome and imputes: efficient, but it needs that
  package, which is in Suggests.

Counts are modelled on a transformed scale by all three backends, which
is why the function warns when a count outcome meets `ols_log` or
`ols_ihs`: the coefficients are effects on that scale.

## References

Callaway, B. and Sant'Anna, P. H. C. (2021). Difference-in-differences
with multiple time periods. Journal of Econometrics 225(2), 200-230.

Sun, L. and Abraham, S. (2021). Estimating dynamic treatment effects in
event studies with heterogeneous treatment effects. Journal of
Econometrics 225(2), 175-199.

Borusyak, K., Jaravel, X. and Spiess, J. (2024). Revisiting event-study
designs: robust and efficient estimation. Review of Economic Studies
91(6).

## See also

Other estimators:
[`lamp_allocation()`](https://blackthrive.github.io/streetlamp/reference/lamp_allocation.md),
[`lamp_crimes_prevented()`](https://blackthrive.github.io/streetlamp/reference/lamp_crimes_prevented.md),
[`lamp_displacement_quotient()`](https://blackthrive.github.io/streetlamp/reference/lamp_displacement_quotient.md),
[`lamp_elasticity()`](https://blackthrive.github.io/streetlamp/reference/lamp_elasticity.md),
[`lamp_event_study()`](https://blackthrive.github.io/streetlamp/reference/lamp_event_study.md),
[`lamp_spillover()`](https://blackthrive.github.io/streetlamp/reference/lamp_spillover.md),
[`lamp_synth()`](https://blackthrive.github.io/streetlamp/reference/lamp_synth.md),
[`lamp_twfe()`](https://blackthrive.github.io/streetlamp/reference/lamp_twfe.md),
[`tidy.lamp_estimate()`](https://blackthrive.github.io/streetlamp/reference/tidy.lamp_estimate.md)

## Examples

``` r
sim <- lamp_simulate(n_areas = 40, n_months = 24, design = "staggered", effect = -0.3, seed = 1)
ad <- attr(sim, "truth")$adoption
tr <- lamp_treatment(sim, "staggered", adoption = ad[!is.na(ad$adoption_month), ])
fit <- lamp_did_staggered(sim, "crime_total", tr)
#> Warning: crime_total is a count, and this backend models it on the ols_log scale.
#> ℹ Coefficients are effects on that transformed scale, not proportional effects
#>   on the count; zeros are handled by the transformation, not modelled.
#> You have a balanced panel. Setting allow_unbalanced_panel = FALSE.
fit
#> 
#> ── streetlamp estimate: lamp_did_staggered 
#> Outcome: crime_total; family: least squares on log(1 + outcome)
#> Treatment: staggered; clustered by area
#> Identifying assumption: Parallel trends by cohort against never-treated areas,
#> and no anticipation before adoption. Outcome modelled on the ols_log scale.
#> Sample: 960 area-months in 40 areas; 0 rows dropped for coverage.
#> Pre-trend joint test: p = 0
#>  rel_time estimate std_error conf_low conf_high  p_value
#>       -12   0.0668    0.1370   -0.202    0.3354 0.625833
#>       -11  -0.0911    0.1537   -0.392    0.2102 0.553408
#>       -10   0.0302    0.1253   -0.215    0.2757 0.809606
#>        -9  -0.0632    0.0973   -0.254    0.1275 0.515843
#>        -8  -0.0149    0.1059   -0.222    0.1926 0.887913
#>        -7  -0.0345    0.1328   -0.295    0.2259 0.795322
#>        -6  -0.0997    0.1008   -0.297    0.0978 0.322543
#>        -5   0.0588    0.0886   -0.115    0.2326 0.507028
#>        -4   0.0407    0.1165   -0.188    0.2691 0.727167
#>        -3   0.0357    0.1137   -0.187    0.2585 0.753671
#>        -2  -0.0889    0.0937   -0.273    0.0946 0.342297
#>        -1   0.0000        NA       NA        NA       NA
#>         0  -0.1499    0.1393   -0.423    0.1231 0.281738
#>         1  -0.2083    0.0978   -0.400   -0.0166 0.033205
#>         2  -0.3146    0.0972   -0.505   -0.1241 0.001212
#>         3  -0.2957    0.1149   -0.521   -0.0705 0.010051
#>         4  -0.1360    0.1206   -0.372    0.1004 0.259480
#>         5  -0.3391    0.1106   -0.556   -0.1223 0.002173
#>         6  -0.2982    0.1174   -0.528   -0.0680 0.011113
#>         7  -0.0837    0.1062   -0.292    0.1244 0.430437
#>         8  -0.3303    0.0991   -0.525   -0.1361 0.000856
#>         9  -0.2695    0.1459   -0.555    0.0165 0.064791
#>        10  -0.0652    0.1570   -0.373    0.2424 0.677706
#>        11  -0.2177    0.1895   -0.589    0.1536 0.250501
#>        12  -0.3030    0.1484   -0.594   -0.0122 0.041126
#> Overall effect: -0.227 (standard error 0.0897)
fit$diagnostics$overall
#> $estimate
#> [1] -0.2271851
#> 
#> $std_error
#> [1] 0.08972677
#> 
```

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
# small: most of this example's cost is loading the did package, which
# whichever example reaches it first has to pay
sim <- lamp_simulate(n_areas = 24, n_months = 18, design = "staggered", effect = -0.3, seed = 1)
ad <- attr(sim, "truth")$adoption
tr <- lamp_treatment(sim, "staggered", adoption = ad[!is.na(ad$adoption_month), ])
fit <- lamp_did_staggered(sim, "crime_total", tr)
#> Warning: crime_total is a count, and this backend models it on the ols_log scale.
#> ℹ Coefficients are effects on that transformed scale, not proportional effects
#>   on the count; zeros are handled by the transformation, not modelled.
#> You have a balanced panel. Setting allow_unbalanced_panel = FALSE.
#> Warning: Not returning pre-test Wald statistic due to singular covariance matrix
fit
#> 
#> ── streetlamp estimate: lamp_did_staggered 
#> Outcome: crime_total; family: least squares on log(1 + outcome)
#> Treatment: staggered; clustered by area
#> Identifying assumption: Parallel trends by cohort against never-treated areas,
#> and no anticipation before adoption. Outcome modelled on the ols_log scale.
#> Sample: 432 area-months in 24 areas; 0 rows dropped for coverage.
#>   Months since adoption  Estimate  Std. error             95% CI       p
#>   ─────────────────────  ────────  ──────────  ─────────────────  ──────
#>   -11                     −0.0912       0.201    [−0.485, 0.303]   0.650
#>   -10                       0.165       0.218    [−0.263, 0.593]   0.451
#>   -9                       −0.352       0.149  [−0.644, −0.0589]   0.019
#>   -8                       −0.114       0.155    [−0.417, 0.189]   0.460
#>   -7                       −0.149       0.177    [−0.496, 0.199]   0.401
#>   -6                       −0.246       0.132   [−0.504, 0.0128]   0.062
#>   -5                       0.0282       0.141    [−0.249, 0.305]   0.842
#>   -4                      −0.0317       0.107    [−0.241, 0.177]   0.766
#>   -3                        −0.01       0.139    [−0.282, 0.262]   0.942
#>   -2                      −0.0386       0.181    [−0.393, 0.316]   0.831
#>   -1 (reference)                0                                       
#>   0                        −0.372       0.134   [−0.634, −0.111]   0.005
#>   1                        −0.412       0.136   [−0.678, −0.146]   0.002
#>   2                        −0.252       0.136   [−0.518, 0.0147]   0.064
#>   3                        −0.499       0.135   [−0.764, −0.233]  <0.001
#>   4                         −0.36       0.144  [−0.641, −0.0781]   0.012
#>   5                        −0.519       0.129   [−0.771, −0.267]  <0.001
#>   6                        −0.242       0.107  [−0.451, −0.0324]   0.024
#>   7                        −0.613        0.13   [−0.869, −0.358]  <0.001
#>   8                        −0.474        0.18   [−0.826, −0.123]   0.008
#>   9                        −0.105       0.194    [−0.485, 0.274]   0.586
#>   10                       −0.517       0.167    [−0.844, −0.19]   0.002
#>   11                       −0.463       0.215  [−0.885, −0.0412]   0.031
#> Overall effect: -0.401 (standard error 0.0894)
fit$diagnostics$overall
#> $estimate
#> [1] -0.4009418
#> 
#> $std_error
#> [1] 0.08936057
#> 
```

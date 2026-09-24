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
#>  rel_time estimate std_error conf_low conf_high  p_value
#>       -11  -0.0912     0.201   -0.485    0.3028 6.50e-01
#>       -10   0.1647     0.218   -0.263    0.5926 4.51e-01
#>        -9  -0.3517     0.149   -0.644   -0.0589 1.86e-02
#>        -8  -0.1143     0.155   -0.417    0.1889 4.60e-01
#>        -7  -0.1486     0.177   -0.496    0.1985 4.01e-01
#>        -6  -0.2456     0.132   -0.504    0.0128 6.25e-02
#>        -5   0.0282     0.141   -0.249    0.3055 8.42e-01
#>        -4  -0.0317     0.107   -0.241    0.1774 7.66e-01
#>        -3  -0.0100     0.139   -0.282    0.2617 9.42e-01
#>        -2  -0.0386     0.181   -0.393    0.3161 8.31e-01
#>        -1   0.0000        NA       NA        NA       NA
#>         0  -0.3724     0.134   -0.634   -0.1107 5.29e-03
#>         1  -0.4120     0.136   -0.678   -0.1459 2.41e-03
#>         2  -0.2516     0.136   -0.518    0.0147 6.40e-02
#>         3  -0.4985     0.135   -0.764   -0.2333 2.30e-04
#>         4  -0.3597     0.144   -0.641   -0.0781 1.23e-02
#>         5  -0.5191     0.129   -0.771   -0.2668 5.52e-05
#>         6  -0.2419     0.107   -0.451   -0.0324 2.36e-02
#>         7  -0.6134     0.130   -0.869   -0.3579 2.55e-06
#>         8  -0.4745     0.180   -0.826   -0.1226 8.22e-03
#>         9  -0.1054     0.194   -0.485    0.2741 5.86e-01
#>        10  -0.5167     0.167   -0.844   -0.1897 1.96e-03
#>        11  -0.4630     0.215   -0.885   -0.0412 3.14e-02
#> Overall effect: -0.401 (standard error 0.0894)
fit$diagnostics$overall
#> $estimate
#> [1] -0.4009418
#> 
#> $std_error
#> [1] 0.08936057
#> 
```

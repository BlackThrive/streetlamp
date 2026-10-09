# Research validation: estimands, heterogeneity and empirical credibility

## A matching target is part of a valid coverage study

`E[log(1 + Y)]`, `log(E[Y])`, and `log(1 + E[Y])` are different
quantities. Comparing an interval for the first with a target for the
second can look like poor uncertainty estimation when the principal
problem is estimand mismatch. Widening the interval does not repair that
mismatch.

The fixed-effects elasticity estimator now defaults to Poisson
pseudo-likelihood for the conditional count mean, with clustered
covariance. It does not require the conditional variance to equal the
conditional mean. Its consistency still requires a correctly specified
conditional mean and suitable exogeneity. Clustered inference needs
sufficiently many independent clusters; it does not resolve unmodelled
dependence or confounding.

``` r

sim <- lamp_simulate(n_areas = 24, n_months = 24, design = "continuous",
                     effect = -0.25, base_rate = 30, seed = 83)
fit <- lamp_elasticity(sim, "affected_crime", lags = 0)
lamp_effect_summary(fit)
#> # A tibble: 1 × 6
#>   estimate std_error conf_low conf_high level definition     
#>      <dbl>     <dbl>    <dbl>     <dbl> <dbl> <chr>          
#> 1   -0.244    0.0245   -0.292    -0.196  0.95 1 * .log_s_lag0
fit$diagnostics$estimand
#> [1] "log conditional count mean per log(1 + stops)"
```

The covariate is `log(1 + stops)`, so its coefficient is a slope with
respect to that covariate. At stop intensity S, the conventional
elasticity is `slope * S / (1 + S)`. The sum over lags is the response
to a persistent change in log-one-plus intensity. When the outcome
combines affected and unaffected crime types, its mean response need not
have one constant slope.

The former FE response remains available with `family = "ols_log"`. CCE
methods continue to use it; they should be described as effects on
log-one-plus observed outcomes, rather than interchangeable count-mean
elasticities. Their auxiliary CD statistic describes shared movements in
an OLS model and is not a causal validity test or a formal test of the
primary Poisson model’s residuals.

## Effects can vary by cohort and exposure duration

In the additive count design, the untreated area and time components are
additive. This permits count-level parallel trends, unlike assuming that
parallel trends on a log scale automatically imply it for counts.

``` r

sim <- lamp_simulate(n_areas = 24, n_months = 24, design = "staggered",
  adoption = c(8, 12, 16), cohort_effects = c("8" = -10, "12" = -4, "16" = 5),
  dynamic_effect = c(0, 0.5, 1), effect_scale = "additive", base_rate = 50, seed = 41)
truth <- lamp_simulation_truth(sim, "affected_crime", "identity")
head(truth[which(truth$rel_time >= 0), c("cohort", "rel_time", "effect")])
#> # A tibble: 6 × 3
#>   cohort rel_time effect
#>    <int>    <int>  <dbl>
#> 1      8        0   0   
#> 2      8        1  -5.00
#> 3      8        2 -10   
#> 4      8        3 -10   
#> 5      8        4 -10   
#> 6      8        5 -10
```

`effect` and `cohort_effects` are combined affected-outcome count
differences for the additive design, and log mean ratios for the default
multiplicative design. The dynamic vector multiplies each cohort’s
effect; its last entry persists. The exact counterfactual means remain
available when observations are missing. `effect_crime_total` is
unavailable when there is no single constant total-outcome effect.

For a count-level staggered analysis, select `family = "identity"`. Use
each backend’s overall ATT when aggregating; the simple ATT and an
equal-weight mean of dynamic coefficients generally have different
weights.

``` r

adoption <- attr(sim, "truth")$adoption
tr <- lamp_treatment(sim, "staggered",
                     adoption = adoption[!is.na(adoption$adoption_month), ])
fit <- lamp_did_staggered(sim, "affected_crime", tr, family = "identity")
lamp_effect_summary(fit)
```

Negative-binomial `dispersion`, `missing_mechanism = "high_outcome"`,
and non-zero `trend_violation` are stress scenarios. A good estimator
need not recover a causal effect when its identifying assumption is
deliberately violated. Such failures belong in the validation results.

## Summaries and sensitivity retain uncertainty

An average of event coefficients has variance `w' V w`, including the
off-diagonal covariances. Averaging confidence limits or assuming
independent coefficients is not a valid replacement.
[`lamp_effect_summary()`](https://blackthrive.github.io/streetlamp/reference/lamp_effect_summary.md)
uses the joint covariance, or the backend’s overall ATT. It errors when
the requested joint covariance is unavailable.

[`lamp_trend_sensitivity()`](https://blackthrive.github.io/streetlamp/reference/lamp_trend_sensitivity.md)
subtracts a user-specified differential linear trend from an event-study
average. Its intervals are conditional on each trend assumption. It is a
transparent bias calculation, not a general robust confidence procedure
or evidence that the true trend lies inside the grid.

## Empirical evidence needs a design, not just a coefficient

[`lamp_design_audit()`](https://blackthrive.github.io/streetlamp/reference/lamp_design_audit.md)
documents missing outcomes, treated-area pre/post support and
detection-sensitive offences. It leaves intervention assignment as a
substantive question even when the data checks pass.

[`lamp_elasticity_robustness()`](https://blackthrive.github.io/streetlamp/reference/lamp_elasticity_robustness.md)
runs explicit outcome/lag/family grids and optional leave-one-area-out
checks. All failures are retained. Specify the primary analysis before
examining results; a grid is not permission to select a significant
result.

The London validation uses cached, hash-verified source files. It
retains seven outcomes, three lag windows, two response scales, borough
omission checks, future-exposure diagnostics and the reverse allocation
model. These are audited associations. Bicycle theft is a comparison
outcome, not a proven unaffected negative control, and drugs and weapons
counts respond to police detection. Independently documented
intervention deployment and assignment are needed for a causal case.

## Reproduce the research evidence

The source scripts run outside package checks. Script
`inst/scripts/05-research-validation.R` uses fixed seeds, records failed
fits and Monte Carlo uncertainty, and needs no downloads. Script
`05b-elasticity-original-design.R` also checks the original study
dimensions; `08-staggered-bias-audit.R` investigates finite-run bias
with independent analytic contrasts. Script `06-london-robustness.R`
requires the London source cache and refuses network access. Script
`07-research-figures.R` creates shareable figures from these saved
summaries. Historical results remain separate in `inst/validation`; new
results are in `inst/validation/research-upgrade`.

The validation is a finite set of designs, not a guarantee of nominal
coverage in every policing dataset. A publication should add
substantively relevant interventions, larger Monte Carlo experiments,
alternative dependence structures and independent reproduction.

# Stop-crime slopes and cross-sectional dependence

## Estimate the count mean on an explicit scale

A recorded count and a conditional mean are different quantities. The
fixed-effects method defaults to Poisson pseudo-likelihood, modelling
expected recorded counts, with clustered covariance. The stop covariate
is `log(1 + stops)`. Its coefficient is a log-mean slope per unit of
that covariate; at intensity S, the conventional stops elasticity is the
slope multiplied by `S / (1 + S)`.

``` r

sim <- lamp_simulate(n_areas = 40, n_months = 36, design = "continuous",
                     effect = -0.2, base_rate = 30, seed = 5)
fit <- lamp_elasticity(sim, "affected_crime", lags = 0:3, method = "fe")
fit
#> 
#> ── streetlamp estimate: lamp_elasticity
#> Outcome: affected_crime; family: Poisson pseudo-likelihood on counts
#> Treatment: continuous; clustered by area
#> Identifying assumption: The association between searching and recorded crime,
#> net of area and month effects. Causal only if the variation in searching has a
#> source outside the crime process; see lamp_allocation().
#> Sample: 1320 area-months in 40 areas; 0 rows dropped for coverage.
#>   Term              Estimate  Std. error              95% CI       p
#>   ────────────────  ────────  ──────────  ──────────────────  ──────
#>   Log stops, lag 0    −0.192      0.0157    [−0.223, −0.161]  <0.001
#>   Log stops, lag 1   −0.0239      0.0166  [−0.0564, 0.00865]   0.150
#>   Log stops, lag 2  −0.00125      0.0157    [−0.032, 0.0295]   0.936
#>   Log stops, lag 3  −0.00859       0.016   [−0.0399, 0.0227]   0.591
#> Sum over lags: -0.226 [-0.305, -0.146]
#> Pesaran CD: 13.2 (p = 5.05e-40), mean pairwise correlation 0.083
lamp_effect_summary(fit)
#> # A tibble: 1 × 6
#>   estimate std_error conf_low conf_high level definition                        
#>      <dbl>     <dbl>    <dbl>     <dbl> <dbl> <chr>                             
#> 1   -0.226    0.0405   -0.305    -0.146  0.95 1 * .log_s_lag0 + 1 * .log_s_lag1…
```

The lag sum describes a persistent shift in log-one-plus stop intensity.
Calendar months define the lags: an absent month cannot turn a
two-month-old observation into last month’s value. The fitted sample and
exclusions are reported. Poisson pseudo-likelihood includes zeros and
uses robust clustered covariance rather than imposing Poisson variance
for inference. It still requires a correctly specified mean and suitable
exogeneity.

## Common correlated effects have a different response scale

The CCE implementations currently model `log(1 + observed crime)`. That
is not `log(expected crime)`, especially with sparse counts. For a
comparison between the three implementations on that response scale,
explicitly select legacy OLS for the FE row:

``` r

legacy_fe <- lamp_elasticity(sim, "crime_total", lags = 0:1, family = "ols_log")
pooled <- lamp_elasticity(sim, "crime_total", lags = 0:1, method = "cce_pooled")
mg <- lamp_elasticity(sim, "crime_total", lags = 0:1, method = "cce_mg")
rbind(fe = lamp_effect_summary(legacy_fe),
      cce_pooled = lamp_effect_summary(pooled),
      cce_mg = lamp_effect_summary(mg))
#> # A tibble: 3 × 6
#>   estimate std_error conf_low conf_high level definition                       
#> *    <dbl>     <dbl>    <dbl>     <dbl> <dbl> <chr>                            
#> 1   -0.199    0.0239   -0.247    -0.150  0.95 1 * .log_s_lag0 + 1 * .log_s_lag1
#> 2   -0.197    0.0234   -0.244    -0.149  0.95 1 * .log_s_lag0 + 1 * .log_s_lag1
#> 3   -0.199    0.0315   -0.263    -0.136  0.95 1 * .log_s_lag0 + 1 * .log_s_lag1
```

CCE uses cross-sectional averages to proxy common factors. Mean-group
inference averages area slopes and uses their cross-area dispersion.
Force clustering for that method is not implemented and is rejected.

The auxiliary Pesaran CD statistic uses an OLS regression of
log-one-plus outcomes with area effects only. A large value describes
shared movements. It does not establish that the clustered intervals
from the primary count model are invalid, or that adding common-factor
proxies identifies a cause.

## Reverse allocation remains an identification question

``` r

allocation <- lamp_allocation(sim, crime_lags = 1:3)
allocation$diagnostics$interpretation
#> [1] "No clear allocation response was detected in this panel. This does not establish exogeneity or rule out reverse allocation and confounding."
```

Police deployment can respond to recent or anticipated crime. A detected
allocation response must be considered when interpreting the stop-crime
association. A non-significant response does not establish exogeneity or
rule out reverse allocation through other channels. Neither coefficient
sign supplies an intervention assignment mechanism.

## Converting the estimate requires further assumptions

``` r

lamp_crimes_prevented(fit, sim)
#> 
#> ── Crimes prevented per 1000 searches
#> 648 [420, 876] on affected_crime
#> 
#> ── Assumption chain
#> 1. The log-one-plus stops slope is -0.226, summed over lags 0, 1, 2, 3.
#> 2. The denominator is mean stops plus one; legacy OLS also uses mean crime plus
#> one.
#> 3. The effect is proportional, so it scales with the mean level of crime.
#> 4. At the sample mean of 21.9 crimes and 6.63 searches per area-month.
#> 5. The association between searching and recorded crime, net of area and month
#> effects. Causal only if the variation in searching has a source outside the
#> crime process; see lamp_allocation().
#> 6. Recorded crime only: unreported crime and recording changes are not
#> separated.
#> 7. The average effect is applied at the margin, which ignores diminishing
#> returns.
```

This is a local arithmetic approximation at fitted-sample means. Because
the covariate is log-one-plus stops, its denominator is mean stops plus
one. A count-mean slope uses mean crime in the numerator. Legacy OLS
requires an approximation on mean crime plus one and cannot be treated
as an expected count effect without further retransformation
assumptions. The output retains the assumption chain and does not
certify prevention.

See
[`vignette("research-validation", package = "streetlamp")`](https://blackthrive.github.io/streetlamp/articles/research-validation.md)
for heterogeneous effects, simulation truth, complete robustness grids,
conditional trend sensitivity and the limits of the London empirical
case.

# Simulation evidence: what each estimator recovers and when it fails

Every estimator in this package returns a number. This vignette is about
which of those numbers are right, under what conditions, and how each
one fails when its assumption does not hold. It uses
[`lamp_simulate()`](https://blackthrive.github.io/streetlamp/reference/lamp_simulate.md),
where the answer is known by construction.

``` r

library(streetlamp)
```

## The generator

``` r

sim <- lamp_simulate(
  n_areas = 100, n_months = 30, design = "event",
  effect = -0.25, base_rate = 30, missing = 0.05, seed = 1
)
truth <- attr(sim, "truth")
str(truth[c("design", "effect", "effect_crime_total", "spillover_effect", "placebo_type")])
#> List of 5
#>  $ design            : chr "event"
#>  $ effect            : num -0.25
#>  $ effect_crime_total: num -0.228
#>  $ spillover_effect  : num 0
#>  $ placebo_type      : chr "bicycle_theft"
```

Crime counts are Poisson draws around area and month fixed effects. The
treatment multiplies the mean of every crime type except bicycle theft
by `exp(effect)`, so the effect on the total is smaller in size than
`effect`, and bicycle theft is a genuine placebo. A share of
force-months is marked unsubmitted, with `NA` counts, exactly as the
real archive has.

## Each estimator against its own design

``` r

recover <- function(design, seed) {
  s <- lamp_simulate(
    n_areas = 120, n_months = 30, design = design,
    effect = -0.25, spillover_effect = 0.12, base_rate = 40, seed = seed
  )
  tr_truth <- attr(s, "truth")
  target <- tr_truth$effect_crime_total

  if (design == "staggered") {
    ad <- tr_truth$adoption
    tr <- lamp_treatment(s, "staggered", adoption = ad[!is.na(ad$adoption_month), ])
    fit <- suppressWarnings(lamp_did_staggered(s, "crime_total", tr))
    est <- fit$diagnostics$overall$estimate
    label <- "lamp_did_staggered"
  } else if (design == "spillover") {
    adj <- lamp_adjacency_from_nb(tr_truth$nb, tr_truth$lattice$area)
    tr <- lamp_treatment(s, "event", date = tr_truth$event_date, scope = tr_truth$treated_areas)
    fit <- lamp_spillover(s, "crime_total", tr, adjacency = adj, rings = 1)
    est <- fit$diagnostics$net$estimate
    target <- target + log((12 * exp(tr_truth$spillover_effect) + 1) / 13)
    label <- "lamp_spillover (net)"
  } else {
    tr <- lamp_treatment(s, "event", date = tr_truth$event_date, scope = tr_truth$treated_areas)
    fit <- lamp_twfe(s, "crime_total", tr)
    est <- fit$coefficients$estimate[1]
    label <- "lamp_twfe"
  }
  data.frame(design = design, estimator = label, truth = target, estimate = est, error = est - target)
}

do.call(rbind, list(
  recover("event", 11),
  recover("staggered", 12),
  recover("spillover", 13)
))
#> You have a balanced panel. Setting allow_unbalanced_panel = FALSE.
#>      design            estimator      truth   estimate        error
#> 1     event            lamp_twfe -0.2283871 -0.2094578  0.018929337
#> 2 staggered   lamp_did_staggered -0.2283871 -0.2185879  0.009799284
#> 3 spillover lamp_spillover (net) -0.1171236 -0.1183379 -0.001214289
```

Each estimator, given the design it was built for, lands close to the
truth.

## Failure one: the wrong estimator for staggered adoption

``` r

s <- lamp_simulate(n_areas = 120, n_months = 36, design = "staggered", effect = -0.3, base_rate = 50, seed = 21)
tr_truth <- attr(s, "truth")
ad <- tr_truth$adoption
tr <- lamp_treatment(s, "staggered", adoption = ad[!is.na(ad$adoption_month), ])

right <- suppressWarnings(lamp_did_staggered(s, "crime_total", tr))
#> You have a balanced panel. Setting allow_unbalanced_panel = FALSE.
wrong <- suppressWarnings(lamp_twfe(s, "crime_total", tr, family = "ols_log"))
data.frame(
  estimator = c("lamp_did_staggered", "lamp_twfe"),
  estimate = c(right$diagnostics$overall$estimate, wrong$coefficients$estimate[1]),
  truth = tr_truth$effect_crime_total
)
#>            estimator   estimate      truth
#> 1 lamp_did_staggered -0.2331457 -0.2734435
#> 2          lamp_twfe -0.2728181 -0.2734435
```

Two-way fixed effects uses already-treated areas as controls. It is
closer to zero here, and there are data-generating processes where it
has the wrong sign entirely.
[`lamp_twfe()`](https://blackthrive.github.io/streetlamp/reference/lamp_twfe.md)
warns when the treatment has several adoption dates, and
[`lamp_event_study()`](https://blackthrive.github.io/streetlamp/reference/lamp_event_study.md)
refuses outright.

## Failure two: ignoring a spillover

``` r

sp <- lamp_simulate(
  n_areas = 100, n_months = 30, design = "spillover",
  effect = -0.3, spillover_effect = 0.2, base_rate = 40, seed = 22
)
sp_truth <- attr(sp, "truth")
adj <- lamp_adjacency_from_nb(sp_truth$nb, sp_truth$lattice$area)
tr_sp <- lamp_treatment(sp, "event", date = sp_truth$event_date, scope = sp_truth$treated_areas)

with_spill <- lamp_spillover(sp, "crime_total", tr_sp, adjacency = adj, rings = 1)
without <- lamp_twfe(sp, "crime_total", tr_sp)
data.frame(
  estimator = c("lamp_spillover (own area)", "lamp_twfe (no spillover term)"),
  estimate = c(with_spill$coefficients$estimate[1], without$coefficients$estimate[1])
)
#>                       estimator    estimate
#> 1     lamp_spillover (own area) -0.16489810
#> 2 lamp_twfe (no spillover term) -0.09837556
```

When the intervention pushes crime into the control areas, the
comparison group moves the wrong way and the plain estimate understates
the effect.

## Failure three: treating an allocation response as an effect

Police surge where crime is spiking now, so searching and crime are
determined together. That is simultaneity, and it biases the elasticity
upward: areas and months with unusually high crime also have unusually
high searching.

``` r

ec <- lamp_simulate(n_areas = 60, n_months = 40, design = "continuous", effect = -0.2, base_rate = 30, seed = 23)
clean <- lamp_elasticity(ec, "crime_total", lags = 0)$diagnostics$long_run$estimate

# the same panel, with officers sent to this month's hot spots
responsive <- ec
responsive$stops <- as.integer(responsive$stops + round(0.6 * responsive$crime_total))
contaminated <- lamp_elasticity(responsive, "crime_total", lags = 0)$diagnostics$long_run$estimate

data.frame(
  panel = c("searching independent of crime", "searching sent to this month's hot spots"),
  elasticity = c(clean, contaminated),
  allocation_response = c(
    lamp_allocation(ec, crime_lags = 1)$diagnostics$total$estimate,
    lamp_allocation(responsive, crime_lags = 1)$diagnostics$total$estimate
  )
)
#>                                      panel elasticity allocation_response
#> 1           searching independent of crime -0.1544429         0.049056850
#> 2 searching sent to this month's hot spots  0.9243121         0.002690155
```

The true deterrent effect is identical in both panels: the second one
simply has police responding to crime as well. The estimated elasticity
moves sharply toward zero, and can cross it, because the regression
reports the net of the deterrent effect and the deployment response. The
allocation column is the warning sign, which is why
[`lamp_allocation()`](https://blackthrive.github.io/streetlamp/reference/lamp_allocation.md)
belongs beside every elasticity.

## Missing force-months are not zeros

A force changes its records system and stops submitting for a stretch of
months. The archive simply has no file, and what is done with that
absence decides what the panel says.

``` r

gappy <- lamp_simulate(
  n_areas = 100, n_months = 30, design = "event", effect = -0.25,
  base_rate = 30, seed = 24
)
g_truth <- attr(gappy, "truth")

# one force submits nothing for the last eight months
late <- sort(unique(gappy$month))[23:30]
gone <- gappy$force_id == "sim-south" & gappy$month %in% late
count_cols <- setdiff(lamp_crime_types()$key, "anti_social_behaviour")
for (k in c(count_cols, "crime_total")) gappy[[k]][gone] <- NA_integer_
gappy$coverage_status[gone] <- "missing"

as_zero <- gappy
for (k in c(count_cols, "crime_total")) as_zero[[k]][is.na(as_zero[[k]])] <- 0L
as_zero$coverage_status <- "submitted"

south <- function(d) {
  s <- d[d$force_id == "sim-south", ]
  round(tapply(s$crime_total, s$month, mean, na.rm = TRUE)[c(20, 24, 28)], 1)
}
rbind(`NA` = south(gappy), `zero-filled` = south(as_zero))
#>             2019-08-01 2019-12-01 2020-04-01
#> NA                25.5        NaN        NaN
#> zero-filled       25.5          0          0
```

Zero-filling invents a collapse in that force’s crime. Any level
statistic, any trend line, any map of the last eight months is now
wrong, and nothing in the table says so.

``` r

tr_g <- lamp_treatment(gappy, "event", date = g_truth$event_date, scope = g_truth$treated_areas)
data.frame(
  handling = c("NA, dropped and counted", "zero-filled"),
  estimate = c(
    lamp_twfe(gappy, "crime_total", tr_g)$coefficients$estimate[1],
    lamp_twfe(as_zero, "crime_total", tr_g)$coefficients$estimate[1]
  ),
  truth = g_truth$effect_crime_total,
  rows_dropped = c(lamp_twfe(gappy, "crime_total", tr_g)$diagnostics$n_dropped_coverage, 0)
)
#>                  handling   estimate      truth rows_dropped
#> 1 NA, dropped and counted -0.2187129 -0.2283871          400
#> 2             zero-filled -0.2212403 -0.2283871            0
```

The difference-in-differences estimate survives here, but only by luck:
this force holds treated and control areas in equal measure, so the
fictitious drop cancels. When a surge is force-wide, which is the usual
case, the gap falls entirely on one side of the comparison and the
estimate goes with it. The package does not rely on that luck:
[`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md)
writes `NA`, never zero, for a month with no file, and every estimator
reports how many rows it dropped.

## Do the intervals mean what they say?

``` r

covered <- vapply(seq_len(40), function(i) {
  s <- lamp_simulate(
    n_areas = 60, n_months = 24, design = "event", effect = -0.2,
    base_rate = 25, seed = 500 + i
  )
  t_i <- attr(s, "truth")
  tr_i <- lamp_treatment(s, "event", date = t_i$event_date, scope = t_i$treated_areas)
  f <- lamp_twfe(s, "crime_total", tr_i)
  f$coefficients$conf_low[1] <= t_i$effect_crime_total &&
    t_i$effect_crime_total <= f$coefficients$conf_high[1]
}, logical(1))
c(replications = length(covered), covered = sum(covered), rate = mean(covered))
#> replications      covered         rate 
#>       40.000       37.000        0.925
```

A 95 percent interval should contain the truth about 95 times in 100.
The full study across all designs, with and without missingness, is in
`inst/scripts/01-simulation-study.R`, and its output in
`inst/validation/`.

## Which estimator when

| Situation | Use | Why not the others |
|----|----|----|
| One date, one set of treated areas | [`lamp_event_study()`](https://blackthrive.github.io/streetlamp/reference/lamp_event_study.md), then [`lamp_twfe()`](https://blackthrive.github.io/streetlamp/reference/lamp_twfe.md) for a summary | Nothing else is needed |
| Areas adopt at different dates | [`lamp_did_staggered()`](https://blackthrive.github.io/streetlamp/reference/lamp_did_staggered.md) | Two-way fixed effects uses already-treated areas as controls |
| Treatment may move crime next door | [`lamp_spillover()`](https://blackthrive.github.io/streetlamp/reference/lamp_spillover.md), [`lamp_displacement_quotient()`](https://blackthrive.github.io/streetlamp/reference/lamp_displacement_quotient.md) | Others count the displacement as a success |
| One treated force or area, many donors | [`lamp_synth()`](https://blackthrive.github.io/streetlamp/reference/lamp_synth.md) | Fixed effects cannot build a counterfactual from one unit |
| Continuous intensity, no discrete event | [`lamp_elasticity()`](https://blackthrive.github.io/streetlamp/reference/lamp_elasticity.md) with [`lamp_allocation()`](https://blackthrive.github.io/streetlamp/reference/lamp_allocation.md) | Read the pair, never the elasticity alone |
| Areas move together over time | `lamp_elasticity(method = "cce_mg")` | Fixed effects standard errors are too small |

Every row assumes the treatment is not simply a response to the outcome.
When it is, and for stop and search it usually is, none of these
estimators recovers an effect, and the honest output is the association
plus the allocation model that explains why it is not more than that.

# Displacement and spillovers

If searching one area pushes offending into the next street rather than
preventing it, a study that compares the searched area with its
neighbours will report a success that did not happen. This vignette
shows what that looks like and how to measure it.

``` r

library(streetlamp)
```

## A panel where displacement is real

``` r

sim <- lamp_simulate(
  n_areas = 100, n_months = 30, design = "spillover",
  effect = -0.3, spillover_effect = 0.2, base_rate = 40, seed = 7
)
truth <- attr(sim, "truth")
c(own = truth$effect_crime_total, spillover = truth$spillover_effect)
#>        own  spillover 
#> -0.2734435  0.2000000
```

Areas sit on a lattice. Treating an area reduces its own crime and
raises crime in the areas next to it.

``` r

adj <- lamp_adjacency_from_nb(truth$nb, truth$lattice$area)
adj
#> streetlamp adjacency: 100 areas, supplied contiguity, 360 links, 0 islands.
tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
```

## What ignoring the spillover does

``` r

plain <- lamp_twfe(sim, "crime_total", tr)
plain$coefficients[, c("term", "estimate", "conf_low", "conf_high")]
#> # A tibble: 1 × 4
#>   term  estimate conf_low conf_high
#>   <chr>    <dbl>    <dbl>     <dbl>
#> 1 treat   -0.102   -0.123   -0.0803
```

The estimate is far too small. The control areas are next to treated
ones, so their crime went up; comparing against a comparison group that
the intervention pushed upward understates the reduction.

## Estimating both effects together

``` r

fit <- lamp_spillover(sim, "crime_total", tr, adjacency = adj, rings = 1)
fit
#> 
#> ── streetlamp estimate: lamp_spillover
#> Outcome: crime_total; family: Poisson pseudo-likelihood on counts
#> Treatment: event; clustered by area
#> Identifying assumption: Parallel trends, and no spillover beyond the rings
#> included: if there is any, control areas are treated too and every coefficient
#> is pulled toward zero.
#> Sample: 3000 area-months in 100 areas; 0 rows dropped for coverage.
#> Dispersion: 0.953
#>   Term                Estimate  Std. error            95% CI       p
#>   ──────────────────  ────────  ──────────  ────────────────  ──────
#>   Own area              −0.323      0.0227  [−0.368, −0.279]  <0.001
#>   Neighbours, ring 1     0.248      0.0292    [0.191, 0.305]  <0.001
#> Net effect (own plus neighbours): -0.0756 [-0.0976, -0.0535]
```

Now the own-area effect is negative and the neighbour effect positive,
and the net effect, the change across a treated area and its neighbours
together, is what the intervention achieved overall.

``` r

net_truth <- truth$effect_crime_total + log((12 * exp(truth$spillover_effect) + 1) / 13)
c(net_estimate = fit$diagnostics$net$estimate, net_truth = net_truth)
#> net_estimate    net_truth 
#>  -0.07557441  -0.08748546
```

The individual coefficients are less precise than the net, because when
treated areas are contiguous an area’s own treatment and its neighbours’
treatment move together. The net effect is the quantity this design pins
down.

A second ring asks whether the effect reaches further out:

``` r

two_rings <- lamp_spillover(sim, "crime_total", tr, adjacency = adj, rings = 1:2)
two_rings$coefficients[, c("term", "estimate", "conf_low", "conf_high")]
#> # A tibble: 3 × 4
#>   term               estimate conf_low conf_high
#>   <chr>                 <dbl>    <dbl>     <dbl>
#> 1 own area            -0.333   -0.402     -0.264
#> 2 neighbours, ring 1   0.281    0.0836     0.479
#> 3 neighbours, ring 2  -0.0257  -0.175      0.124
```

## The weighted displacement quotient

The quotient of Bowers and Johnson (2003) answers the same question with
arithmetic rather than a regression: it compares the buffer’s change
with the treated area’s, both measured against controls.

The three sets have to be defined properly: the buffer is the untreated
areas that touch a treated one, and the controls are the untreated areas
that do not.

``` r

areas <- truth$lattice$area
treated <- truth$treated_areas
neighbours_of_treated <- unique(areas[unlist(truth$nb[match(treated, areas)])])
buffer <- setdiff(neighbours_of_treated, treated)
controls <- setdiff(areas, union(treated, buffer))
c(treated = length(treated), buffer = length(buffer), control = length(controls))
#> treated  buffer control 
#>      50      10      40
```

``` r

wdq <- lamp_displacement_quotient(
  sim, "crime_total",
  treated_areas = treated,
  buffer_areas = buffer,
  control_areas = controls,
  pre = c("2018-01", "2018-08"),
  post = c("2019-04", "2019-11"),
  n_boot = 200, seed = 3
)
wdq
#> 
#> ── Weighted displacement quotient
#> Outcome: crime_total
#> WDQ: -0.373 [-0.893, -0.194] from 200 of 200 bootstrap draws
#> Treated-area change net of controls: -0.08447
#> WDQ -0.37 is negative: crime rose in the buffer as it fell in the treated
#> areas, which is what displacement looks like.
```

A negative quotient is displacement: crime rose in the buffer as it fell
in the treated areas. Between zero and one is a diffusion of benefit.
The bootstrap interval is wide whenever the treated area’s own change is
small, which is the quotient warning you that its denominator is near
zero.

## Spatial correlation in the residuals

Even without a spillover term, the panel leaves a trace of spatial
structure in the residuals, and the package reports it whenever the
panel carries adjacency.

``` r

panel <- lamp_sample_panel()
real_tr <- lamp_treatment(panel, "continuous", measure = "stop_rate", transform = "ihs")
real_fit <- lamp_twfe(panel, "crime_total", real_tr)
real_fit$diagnostics$moran[c("statistic", "p_value", "n_areas")]
#> $statistic
#> [1] -0.001036074
#> 
#> $p_value
#> [1] 0.9644108
#> 
#> $n_areas
#> [1] 1710
```

Positive spatial correlation means neighbouring areas’ residuals move
together, so observations are not independent and the standard errors
are too small. Clustering at force level, or modelling the spillover, is
the response.

# A presentation-ready table from a streetlamp object

Formats an estimate, a diagnostic or a coverage audit as a tibble of
character columns with readable headers, rounded figures, confidence
intervals in brackets and p values as `<0.001` where they are that
small. The result is meant to be passed to
[`knitr::kable()`](https://rdrr.io/pkg/knitr/man/kable.html) or a
similar table renderer; the unrounded numbers remain available from
[`tidy()`](https://generics.r-lib.org/reference/tidy.html) and from the
object itself.

## Usage

``` r
lamp_table(x, ...)

# S3 method for class 'lamp_estimate'
lamp_table(x, digits = 3, ...)

# S3 method for class 'lamp_event_study'
lamp_table(x, digits = 3, ...)

# S3 method for class 'lamp_did_staggered'
lamp_table(x, digits = 3, ...)

# S3 method for class 'lamp_pretrends'
lamp_table(x, digits = 3, ...)

# S3 method for class 'lamp_synth'
lamp_table(x, digits = 3, ...)

# S3 method for class 'lamp_coverage'
lamp_table(x, ...)
```

## Arguments

- x:

  An estimate from any of the package's estimators, a
  [`lamp_pretrends()`](https://blackthrive.github.io/streetlamp/reference/lamp_pretrends.md)
  result, a
  [`lamp_synth()`](https://blackthrive.github.io/streetlamp/reference/lamp_synth.md)
  fit, or a
  [`lamp_coverage()`](https://blackthrive.github.io/streetlamp/reference/lamp_coverage.md)
  audit.

- ...:

  Unused.

- digits:

  Significant figures for estimates and intervals.

## Value

A tibble of character columns. For estimates: the term, the estimate,
its standard error, the 95 percent confidence interval and the p value.
Event studies and staggered fits show months relative to the event in
place of the term. For a pre-trend diagnostic: the power table. For a
synthetic control: donor weights. For a coverage audit: counts of
force-months by file type and status.

## See also

Other presentation:
[`lamp_colours()`](https://blackthrive.github.io/streetlamp/reference/lamp_colours.md),
[`lamp_theme()`](https://blackthrive.github.io/streetlamp/reference/lamp_theme.md)

## Examples

``` r
sim <- lamp_simulate(n_areas = 24, n_months = 24, design = "event", effect = -0.2, seed = 2)
truth <- attr(sim, "truth")
tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
lamp_table(lamp_twfe(sim, "crime_total", tr))
#> # A tibble: 1 × 5
#>   Term            Estimate `Std. error` `95% CI`         p     
#>   <chr>           <chr>    <chr>        <chr>            <chr> 
#> 1 Treated × after −0.276   0.0572       [−0.388, −0.164] <0.001
lamp_table(lamp_coverage(sim))
#> # A tibble: 3 × 2
#>   `File type`           Submitted
#>   <chr>                 <chr>    
#> 1 Outcome files         48       
#> 2 Stop and search files 48       
#> 3 Street crime files    48       
```

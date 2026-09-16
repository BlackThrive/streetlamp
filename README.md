
<!-- README.md is generated from README.Rmd. Please edit that file -->

# streetlamp

`streetlamp` is an R package for estimating the effects of police stop
and search activity on recorded crime in England and Wales, published by
Black Thrive Global. It builds an area-by-month panel of recorded crime
from the data.police.uk archive, attaches stop and search intensity as a
treatment variable, and provides a panel-econometrics toolkit for
evaluating policing interventions: event studies,
difference-in-differences with staggered adoption, synthetic control,
spatial spillover and displacement models, and stop-crime elasticities
by offence type.

`streetlamp` is about what stops achieve, not who is stopped. It never
computes an ethnic disparity measure and reads stop and search files
only to count stops by area and month.

## Installation

The package is under development and not yet on CRAN.

``` r
# install.packages("pak")
pak::pak("black-thrive-global/streetlamp")
```

## Status

Milestone M0 (skeleton) is complete: package infrastructure, continuous
integration, and the bundled reference tables below. Ingestion of the
data.police.uk archive (M1), panel construction and coverage audit (M2),
treatment definitions and estimators (M3 and M4) and reporting (M5)
follow.

## Bundled reference tables

Everything in the package runs without network access at check time. The
reference tables shipped with it are verified against their sources, as
recorded in `inst/NOTES/data_sources.md`.

``` r
library(streetlamp)

# The fourteen data.police.uk categories with package groupings
lamp_crime_types()
#> # A tibble: 14 × 7
#>    crime_type             key   api_slug is_asb in_crime_total group broad_group
#>    <chr>                  <chr> <chr>    <lgl>  <lgl>          <chr> <chr>      
#>  1 Anti-social behaviour  anti… anti-so… TRUE   FALSE          asb   asb        
#>  2 Bicycle theft          bicy… bicycle… FALSE  TRUE           theft acquisitive
#>  3 Burglary               burg… burglary FALSE  TRUE           theft acquisitive
#>  4 Criminal damage and a… crim… crimina… FALSE  TRUE           crim… damage     
#>  5 Drugs                  drugs drugs    FALSE  TRUE           drugs drugs      
#>  6 Other crime            othe… other-c… FALSE  TRUE           other other      
#>  7 Other theft            othe… other-t… FALSE  TRUE           theft acquisitive
#>  8 Possession of weapons  poss… possess… FALSE  TRUE           poss… violent    
#>  9 Public order           publ… public-… FALSE  TRUE           publ… violent    
#> 10 Robbery                robb… robbery  FALSE  TRUE           robb… violent    
#> 11 Shoplifting            shop… shoplif… FALSE  TRUE           theft acquisitive
#> 12 Theft from the person  thef… theft-f… FALSE  TRUE           theft acquisitive
#> 13 Vehicle crime          vehi… vehicle… FALSE  TRUE           theft acquisitive
#> 14 Violence and sexual o… viol… violent… FALSE  TRUE           viol… violent

# Dated national shocks for use as default intervention definitions
shocks <- lamp_shocks()
shocks[shocks$kind == "stop_search_policy", c("name", "start", "end", "scope")]
#> # A tibble: 11 × 4
#>    name                                 start      end        scope   
#>    <chr>                                <date>     <date>     <chr>   
#>  1 stop_search_reform_announcement      2014-04-30 NA         national
#>  2 buss_launch                          2014-08-26 2021-07-27 national
#>  3 pace_code_a_2015                     2015-03-19 2023-01-16 national
#>  4 met_violent_crime_task_force         2018-04-01 NA         forces  
#>  5 s60_pilot_seven_forces               2019-04-01 2019-08-10 forces  
#>  6 s60_relaxation_all_forces            2019-08-11 NA         national
#>  7 beating_crime_plan_s60_permanent     2021-07-27 NA         national
#>  8 home_secretary_s60_letter_2022       2022-05-16 NA         national
#>  9 pace_code_a_2023                     2023-01-17 NA         national
#> 10 svro_pilot                           2023-04-19 2025-04-18 forces  
#> 11 public_order_act_2023_protest_search 2023-12-20 NA         national

# Bank holidays in England and Wales, for seasonality controls
range(lamp_bank_holidays()$date)
#> [1] "2010-01-01" "2028-12-26"

# ONS LSOA code lists and the 2011 to 2021 lookup
length(lamp_lsoa_codes("lsoa11"))
#> [1] 34753
length(lamp_lsoa_codes("lsoa21"))
#> [1] 35672
table(lamp_lsoa_lookup()$change)
#> 
#>     U     S     M     X 
#> 33647  1900   239    10
```

## Design principles

- Every panel carries a **panel contract** recording provenance,
  coverage, LSOA vintage and treatment definition. Estimators read it
  and refuse or warn when their assumptions are violated.
- “Force did not submit” is never a zero.
- Anti-social behaviour is not a crime: it is kept in a separate series
  and excluded from crime totals by default.
- Every estimator names its identifying assumption in its output and
  ships with a placebo or pre-trend diagnostic.

## Data attribution

Contains public sector information licensed under the Open Government
Licence v3.0: recorded crime, outcomes and stop and search data from
[data.police.uk](https://data.police.uk/), geography from the [Office
for National Statistics](https://geoportal.statistics.gov.uk/), and bank
holidays from [GOV.UK](https://www.gov.uk/bank-holidays).

## Licence

MIT, copyright Black Thrive Global.

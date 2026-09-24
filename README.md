
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
pak::pak("BlackThrive/streetlamp")
```

## Status

All milestones are complete: acquisition and versioning, geography and
population, the panel and its coverage audit, treatment definitions, the
estimators and their diagnostics, and reporting. `R CMD check --as-cran`
is clean. Before a CRAN submission the repository still needs to exist
so that the continuous integration matrix can run; see
`RELEASE_READY.md`.

## What it estimates

| Question | Function |
|----|----|
| Did crime fall after a dated intervention? | `lamp_event_study()`, `lamp_twfe()` |
| Areas adopted at different dates | `lamp_did_staggered()` |
| Did crime move next door instead? | `lamp_spillover()`, `lamp_displacement_quotient()` |
| One treated force, many comparison areas | `lamp_synth()` |
| How does crime respond to search intensity? | `lamp_elasticity()` |
| How does searching follow crime? | `lamp_allocation()` |
| How many crimes per thousand searches? | `lamp_crimes_prevented()` |
| Is the estimate worth anything? | `lamp_pretrends()`, `lamp_placebo()` |

## Quick start on the bundled panel

The package ships a ready-made panel: every 2021 LSOA in West Yorkshire
and Dyfed-Powys over August 2024 to July 2026, with crime by type,
anti-social behaviour, stops, population and deprivation deciles, and a
contract that records where every number came from.

``` r
library(streetlamp)

panel <- lamp_sample_panel()
panel
#> streetlamp panel: 1710 lsoa21 area x 24 months; see `lamp_contract()` and
#> `lamp_coverage()`.
#> # A tibble: 41,040 × 27
#>    area  month      force_id bicycle_theft burglary criminal_damage_and_…¹ drugs
#>    <chr> <date>     <chr>            <int>    <int>                  <int> <int>
#>  1 E010… 2024-08-01 west-yo…             0        0                      2     0
#>  2 E010… 2024-09-01 west-yo…             0        0                      0     0
#>  3 E010… 2024-10-01 west-yo…             0        0                      1     0
#>  4 E010… 2024-11-01 west-yo…             0        4                      2     0
#>  5 E010… 2024-12-01 west-yo…             0        0                      1     0
#>  6 E010… 2025-01-01 west-yo…             0        2                      1     0
#>  7 E010… 2025-02-01 west-yo…             0        1                      1     0
#>  8 E010… 2025-03-01 west-yo…             0        2                      0     0
#>  9 E010… 2025-04-01 west-yo…             0        2                      0     0
#> 10 E010… 2025-05-01 west-yo…             0        0                      0     0
#> # ℹ 41,030 more rows
#> # ℹ abbreviated name: ¹​criminal_damage_and_arson
#> # ℹ 20 more variables: other_crime <int>, other_theft <int>,
#> #   possession_of_weapons <int>, public_order <int>, robbery <int>,
#> #   shoplifting <int>, theft_from_the_person <int>, vehicle_crime <int>,
#> #   violence_and_sexual_offences <int>, crime_total <int>, asb <int>,
#> #   stops <int>, stops_s60 <int>, population <dbl>, stop_rate <dbl>, …
lamp_contract(panel)

# Coverage: which force-months exist, and where stop files are missing while
# crime files are present
cov <- lamp_coverage(panel)
table(cov$file_type, cov$status)
#>                  
#>                   missing submitted
#>   stop-and-search       8        40
#>   street                0        48
lamp_coverage_compare(cov, c("2024-08", "2025-07"), c("2025-08", "2026-07"))
#> # A tibble: 2 × 12
#>   force_id   n_months_a n_usable_a n_months_b n_usable_b n_partial_a n_partial_b
#>   <chr>           <int>      <int>      <int>      <int>       <int>       <int>
#> 1 dyfed-pow…         12         12         12         12           0           0
#> 2 west-york…         12         12         12         12           0           0
#> # ℹ 5 more variables: n_refreshed_a <int>, n_refreshed_b <int>,
#> #   n_mismatch_a <int>, n_mismatch_b <int>, comparable <lgl>

# Spatial structure for the spillover estimators
adj <- lamp_adjacency(lamp_sample_boundaries())
adj
#> streetlamp adjacency: 1710 areas, queen contiguity, 8214 links, 0 islands.
```

The plot methods draw force-month totals with missing months shaded
(`plot(panel)`) and the coverage grid as a heat map (`plot(cov)`).

## Estimating, and checking the estimate

``` r
# a dated intervention on a simulated panel whose true effect is known
sim <- lamp_simulate(n_areas = 60, n_months = 24, design = "event", effect = -0.25, seed = 1)
truth <- attr(sim, "truth")
tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)

fit <- lamp_twfe(sim, "crime_total", tr)
fit
#> 
#> ── streetlamp estimate: lamp_twfe
#> Outcome: crime_total; family: Poisson pseudo-likelihood on counts
#> Treatment: event; clustered by area
#> Identifying assumption: Parallel trends: treated and control areas would have
#> moved together in the outcome, net of area and month fixed effects.
#> Sample: 1440 area-months in 60 areas; 0 rows dropped for coverage.
#> Dispersion: 0.942
#>   Term             Estimate  Std. error            95% CI       p
#>   ───────────────  ────────  ──────────  ────────────────  ──────
#>   Treated × after    −0.242      0.0386  [−0.318, −0.166]  <0.001

# the true effect on the crime total, for comparison
truth$effect_crime_total
#> [1] -0.2283871
```

Every estimate prints the assumption it rests on and the force-months it
had to drop. The diagnostics are the point of the package as much as the
estimators are:

``` r
es <- lamp_event_study(sim, "crime_total", tr, window = c(-6, 6))

# how large a pre-trend would this test have missed, and what would it cost?
lamp_pretrends(es)$power
#> # A tibble: 2 × 3
#>   power  slope bias_mean_post
#>   <dbl>  <dbl>          <dbl>
#> 1   0.5 0.0376          0.150
#> 2   0.8 0.0509          0.204

# does the specification produce effects where none exist?
lamp_placebo(fit, type = "space", n = 50, seed = 1)$p_value
#> [1] 0
```

## Reading the results honestly

Police send officers where crime has risen, so searching responds to
crime as well as possibly reducing it. `lamp_allocation()` measures that
channel, and nothing else in the package should be read without it.

``` r
lamp_allocation(sim, crime_lags = 1:3)$diagnostics$interpretation
#> [1] "Searching falls where recent crime has risen, which is the opposite of the usual allocation pattern and worth checking before relying on it."
```

`inst/NOTES/methods.md` sets out the equations, the assumption behind
each estimator, and the limits that apply to all of them: recording
practice, anonymised locations, and the fact that recorded crime is what
the police wrote down.

## Reading the archive

The data.police.uk archive publishes one zip per month, each 1 to 2.6
GB. `streetlamp` reads a zip’s table of contents with an HTTP byte-range
request and fetches only the force-month files you ask for, so a
three-year pull for two forces is tens of megabytes. The package ships
two miniature archive snapshots (real records for a subset of West
Yorkshire and Dyfed-Powys neighbourhoods, May to July 2026), so
everything below runs offline.

``` r
cache <- tempfile("streetlamp-cache-")
zips <- list.files(
  system.file("extdata", "archive", package = "streetlamp"),
  pattern = "zip$", full.names = TRUE
)
for (z in zips) lamp_archive_register(z, dir = cache)
#> Registered archive "2026-06" from
#> 'C:/Users/musta/AppData/Local/Temp/Rtmpy87S3Y/temp_libpath295c318b155a/streetlamp/extdata/archive/2026-06.zip'.
#> Registered archive "2026-07" from
#> 'C:/Users/musta/AppData/Local/Temp/Rtmpy87S3Y/temp_libpath295c318b155a/streetlamp/extdata/archive/2026-07.zip'.
snap <- lamp_archive_snapshot(cache)
snap
#> 
#> ── streetlamp archive snapshot 
#> Cache:
#> 'C:\Users\musta\AppData\Local\Temp\Rtmpms2tIT\streetlamp-cache-8ba86d5c2eb2'
#> 2 archives: "2026-06" and "2026-07"
#> 25 force-month files covering 2 forces, 2026-05 to 2026-07; 25 available
#> locally.
#>   outcomes: 10 of 10 available
#>   stop-and-search: 5 of 5 available
#>   street: 10 of 10 available

# The same force-month can appear in several snapshots with different content
versions <- lamp_list_versions(snap)
versions[versions$differs, c("force_id", "month", "file_type", "n_versions")]
#> # A tibble: 7 × 4
#>   force_id       month      file_type n_versions
#>   <chr>          <date>     <chr>          <int>
#> 1 dyfed-powys    2026-05-01 outcomes           2
#> 2 dyfed-powys    2026-05-01 street             2
#> 3 dyfed-powys    2026-06-01 outcomes           2
#> 4 dyfed-powys    2026-06-01 street             2
#> 5 west-yorkshire 2026-05-01 outcomes           2
#> 6 west-yorkshire 2026-05-01 street             2
#> 7 west-yorkshire 2026-06-01 street             2
lamp_version_diff(snap, "west-yorkshire", "2026-05", "outcomes")
#> # A tibble: 2 × 5
#>   archive n_rows n_ids ids_not_in_others crc32   
#>   <chr>    <int> <int>             <int> <chr>   
#> 1 2026-06   1761  1728                 3 efe93414
#> 2 2026-07   1756  1725                 0 34133345

# Readers return tibbles with a fixed schema and a contract
crime <- lamp_read_crime(snap, forces = "dyfed-powys")
table(crime$crime_type)
#> 
#>        Anti-social behaviour                Bicycle theft 
#>                          317                           16 
#>                     Burglary    Criminal damage and arson 
#>                           99                          286 
#>                        Drugs                  Other crime 
#>                           77                           71 
#>                  Other theft        Possession of weapons 
#>                          170                           29 
#>                 Public order                      Robbery 
#>                          227                            8 
#>                  Shoplifting        Theft from the person 
#>                          169                           14 
#>                Vehicle crime Violence and sexual offences 
#>                           47                         1342 
#>  Public disorder and weapons 
#>                            0
lamp_contract(crime)$coverage
#> # A tibble: 3 × 8
#>   force_id    month      file_type status    archive n_records n_versions
#>   <chr>       <date>     <chr>     <chr>     <chr>       <int>      <int>
#> 1 dyfed-powys 2026-05-01 street    submitted 2026-07       968          2
#> 2 dyfed-powys 2026-06-01 street    submitted 2026-07       925          2
#> 3 dyfed-powys 2026-07-01 street    submitted 2026-07       979          1
#> # ℹ 1 more variable: versions_differ <lgl>

stops <- lamp_read_stop_counts(snap)
stops
#> streetlamp records with a contract; see `lamp_contract()`.
#> # A tibble: 3 × 8
#>   area           force_id   month      archive stops stops_s60 stops_no_location
#>   <chr>          <chr>      <date>     <chr>   <int>     <int>             <int>
#> 1 west-yorkshire west-york… 2026-05-01 2026-07  1254         0                10
#> 2 west-yorkshire west-york… 2026-06-01 2026-07  1095         0                10
#> 3 west-yorkshire west-york… 2026-07-01 2026-07  1130         0                10
#> # ℹ 1 more variable: stops_no_legislation <int>
```

With network access, `lamp_archive_download()` fetches force-month files
from the live archive into the cache, `lamp_boundaries()` and
`lamp_population()` fetch ONS boundaries and Census 2021 population
once, and `lamp_panel()` builds the balanced panel:

``` r
snap <- lamp_archive_download(
  archives = "latest",
  months = c("2026-05", "2026-06", "2026-07"),
  forces = c("west-yorkshire", "dyfed-powys")
)
crime <- lamp_read_crime(snap)
stops <- lamp_read_stop_counts(snap, area = "lsoa21", boundaries = lamp_boundaries("lsoa21"))
panel <- lamp_panel(crime, stops = stops, population = lamp_population("lsoa21"))
```

## Bundled reference tables

Everything in the package runs without network access at check time. The
reference tables shipped with it are verified against their sources, as
recorded in `inst/NOTES/data_sources.md`.

``` r
library(streetlamp)

# The fourteen data.police.uk categories with package groupings
lamp_crime_types()
#> # A tibble: 14 × 8
#>    crime_type  key   api_slug is_asb in_crime_total group broad_group since     
#>    <chr>       <chr> <chr>    <lgl>  <lgl>          <chr> <chr>       <date>    
#>  1 Anti-socia… anti… anti-so… TRUE   FALSE          asb   asb         2010-12-01
#>  2 Bicycle th… bicy… bicycle… FALSE  TRUE           theft acquisitive 2013-05-01
#>  3 Burglary    burg… burglary FALSE  TRUE           theft acquisitive 2010-12-01
#>  4 Criminal d… crim… crimina… FALSE  TRUE           crim… damage      2011-09-01
#>  5 Drugs       drugs drugs    FALSE  TRUE           drugs drugs       2011-09-01
#>  6 Other crime othe… other-c… FALSE  TRUE           other other       2010-12-01
#>  7 Other theft othe… other-t… FALSE  TRUE           theft acquisitive 2011-09-01
#>  8 Possession… poss… possess… FALSE  TRUE           poss… violent     2013-05-01
#>  9 Public ord… publ… public-… FALSE  TRUE           publ… violent     2013-05-01
#> 10 Robbery     robb… robbery  FALSE  TRUE           robb… violent     2010-12-01
#> 11 Shoplifting shop… shoplif… FALSE  TRUE           theft acquisitive 2011-09-01
#> 12 Theft from… thef… theft-f… FALSE  TRUE           theft acquisitive 2013-05-01
#> 13 Vehicle cr… vehi… vehicle… FALSE  TRUE           theft acquisitive 2010-12-01
#> 14 Violence a… viol… violent… FALSE  TRUE           viol… violent     2013-05-01

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

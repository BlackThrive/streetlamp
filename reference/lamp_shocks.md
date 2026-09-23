# National policy shocks affecting stop and search or recorded crime

A curated table of dated national events for use as default intervention
definitions in
[`lamp_treatment()`](https://blackthrive.github.io/streetlamp/reference/lamp_treatment.md):
the Best Use of Stop and Search Scheme, the 2019 and later changes to
Section 60 authorisation conditions, COVID-19 lockdown periods, changes
to crime recording practice, and other verified policy changes. Every
row carries the source that establishes its dates; see
`inst/NOTES/data_sources.md` in the package sources for the verification
record.

## Usage

``` r
lamp_shocks()
```

## Value

A tibble with columns `name` (identifier), `label`, `kind`
(`stop_search_policy`, `crime_policy`, `covid`, `recording_practice` or
`disorder`), `start` and `end` (`Date`; `end` is `NA` for point events
or regimes still in force), `scope` (`national`, `england`, `wales` or
`forces`), `forces` (semicolon-separated police.uk force identifiers
when `scope` is `forces`, otherwise `NA`), `source_url`, `notes` and
`verified` (`Date` the source was checked).

## See also

Other bundled data:
[`lamp_area_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_area_lookup.md),
[`lamp_bank_holidays()`](https://blackthrive.github.io/streetlamp/reference/lamp_bank_holidays.md),
[`lamp_crime_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_crime_types.md),
[`lamp_deprivation()`](https://blackthrive.github.io/streetlamp/reference/lamp_deprivation.md),
[`lamp_forces()`](https://blackthrive.github.io/streetlamp/reference/lamp_forces.md),
[`lamp_lsoa_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_lookup.md),
[`lamp_outcome_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_outcome_types.md),
[`lamp_sample_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_sample_panel.md)

## Examples

``` r
shocks <- lamp_shocks()
shocks[shocks$kind == "stop_search_policy", c("name", "start", "end")]
#> # A tibble: 11 × 3
#>    name                                 start      end       
#>    <chr>                                <date>     <date>    
#>  1 stop_search_reform_announcement      2014-04-30 NA        
#>  2 buss_launch                          2014-08-26 2021-07-27
#>  3 pace_code_a_2015                     2015-03-19 2023-01-16
#>  4 met_violent_crime_task_force         2018-04-01 NA        
#>  5 s60_pilot_seven_forces               2019-04-01 2019-08-10
#>  6 s60_relaxation_all_forces            2019-08-11 NA        
#>  7 beating_crime_plan_s60_permanent     2021-07-27 NA        
#>  8 home_secretary_s60_letter_2022       2022-05-16 NA        
#>  9 pace_code_a_2023                     2023-01-17 NA        
#> 10 svro_pilot                           2023-04-19 2025-04-18
#> 11 public_order_act_2023_protest_search 2023-12-20 NA        
```

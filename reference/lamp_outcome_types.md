# Outcome classification used by data.police.uk

The outcome categories that appear in the `Outcome type` column of the
outcomes files and the `Last outcome category` column of the street
files, with the police.uk API code and a package-defined grouping into
six classes.

## Usage

``` r
lamp_outcome_types()
```

## Value

A tibble with columns `outcome_type`, `api_name`, `code`, `group`
(factor with the six levels above) and `is_court_outcome`.

## Details

The grouping is the package's own:

- `charged_or_summonsed`: the suspect was charged or summonsed,
  including every subsequent court outcome supplied by the Ministry of
  Justice and offences taken into consideration
  (`Suspect charged as part of another case`).

- `out_of_court`: cautions, drugs possession warnings, penalty notices
  and community (local) resolutions.

- `no_suspect`: investigation complete with no suspect identified.

- `evidential_difficulties`: a suspect was identified but the police
  were unable to prosecute.

- `other`: action not in the public interest or taken by another body.

- `unknown`: still under investigation or no status update available.

`is_court_outcome` marks the categories that come from court records
rather than from the police. data.police.uk reports that court outcomes
from June 2019 onwards are unavailable, so these categories are sparse
after that date and `charged_or_summonsed` should be read as the charge
stage.

The category list was verified against the police.uk API documentation
and against archive files on 2026-09-16. `outcome_type` is the string
written in the archive CSV files; where the API documentation names a
category differently (`Offender given penalty notice` appears there as
`Offender given a penalty notice`) the API name is kept in `api_name`
and
[`lamp_read_outcomes()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_outcomes.md)
accepts either.

## See also

[`lamp_crime_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_crime_types.md)

Other bundled data:
[`lamp_area_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_area_lookup.md),
[`lamp_bank_holidays()`](https://blackthrive.github.io/streetlamp/reference/lamp_bank_holidays.md),
[`lamp_crime_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_crime_types.md),
[`lamp_deprivation()`](https://blackthrive.github.io/streetlamp/reference/lamp_deprivation.md),
[`lamp_forces()`](https://blackthrive.github.io/streetlamp/reference/lamp_forces.md),
[`lamp_lsoa_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_lookup.md),
[`lamp_sample_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_sample_panel.md),
[`lamp_shocks()`](https://blackthrive.github.io/streetlamp/reference/lamp_shocks.md)

## Examples

``` r
lamp_outcome_types()
#> # A tibble: 28 × 5
#>    outcome_type                            api_name code  group is_court_outcome
#>    <chr>                                   <chr>    <chr> <fct> <lgl>           
#>  1 Awaiting court outcome                  Awaitin… awai… char… TRUE            
#>  2 Court result unavailable                Court r… cour… char… TRUE            
#>  3 Court case unable to proceed            Court c… unab… char… TRUE            
#>  4 Local resolution                        Local r… loca… out_… FALSE           
#>  5 Investigation complete; no suspect ide… Investi… no-f… no_s… FALSE           
#>  6 Offender deprived of property           Offende… depr… char… TRUE            
#>  7 Offender fined                          Offende… fined char… TRUE            
#>  8 Offender given absolute discharge       Offende… abso… char… TRUE            
#>  9 Offender given a caution                Offende… caut… out_… FALSE           
#> 10 Offender given a drugs possession warn… Offende… drug… out_… FALSE           
#> # ℹ 18 more rows
```

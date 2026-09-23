# Area hierarchy for 2021 LSOAs

One row per 2021 Lower layer Super Output Area in England and Wales with
its 2021 Middle layer Super Output Area, 2022 local authority district,
police force area and the police.uk force identifier. This is how
[`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md)
reaches the `msoa21`, `lad` and `pfa` levels and how it knows which
areas belong to a force.

## Usage

``` r
lamp_area_lookup()
```

## Value

A tibble with columns `lsoa21`, `lsoa21_name`, `msoa21`, `msoa21_name`,
`lad22`, `lad22_name`, `pfa`, `pfa_name` and `force_id`.

## Details

Source: Office for National Statistics lookups licensed under the Open
Government Licence v3.0; see `inst/NOTES/data_sources.md` for the
products and retrieval dates.

## See also

Other bundled data:
[`lamp_bank_holidays()`](https://blackthrive.github.io/streetlamp/reference/lamp_bank_holidays.md),
[`lamp_crime_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_crime_types.md),
[`lamp_deprivation()`](https://blackthrive.github.io/streetlamp/reference/lamp_deprivation.md),
[`lamp_forces()`](https://blackthrive.github.io/streetlamp/reference/lamp_forces.md),
[`lamp_lsoa_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_lookup.md),
[`lamp_outcome_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_outcome_types.md),
[`lamp_sample_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_sample_panel.md),
[`lamp_shocks()`](https://blackthrive.github.io/streetlamp/reference/lamp_shocks.md)

## Examples

``` r
lk <- lamp_area_lookup()
table(lk$force_id[lk$pfa_name == "West Yorkshire"])
#> 
#> west-yorkshire 
#>           1404 
length(unique(lk$msoa21))
#> [1] 7264
```

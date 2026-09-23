# ONS LSOA code lists and the 2011 to 2021 lookup

The Office for National Statistics lookup between 2011 and 2021 Lower
layer Super Output Areas (LSOAs) in England and Wales, with the ONS
change indicator, the 2022 local authority district, and a flag marking
the single 2021 LSOA that the ONS best-fit lookup assigns to each 2011
LSOA. `lamp_lsoa_codes()` returns the complete code list for either
vintage, which is what
[`lamp_lsoa_vintage()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_vintage.md)
matches against.

## Usage

``` r
lamp_lsoa_lookup()

lamp_lsoa_codes(vintage = c("lsoa21", "lsoa11"))
```

## Arguments

- vintage:

  Which code list: `"lsoa21"` (default) or `"lsoa11"`.

## Value

`lamp_lsoa_lookup()` returns a tibble with columns `lsoa11`,
`lsoa11_name`, `lsoa21`, `lsoa21_name`, `change` (factor), `lad22`,
`lad22_name` and `best_fit`. `lamp_lsoa_codes()` returns a sorted
character vector of codes.

## Details

`lamp_lsoa_lookup()` is the ONS exact-fit lookup (version 3): one row
per 2011 to 2021 pair, so a 2011 LSOA that was split appears on several
rows and a merged 2021 LSOA appears on several rows. `change` is the ONS
change indicator: `U` unchanged, `S` split, `M` merged, `X` complex.
`best_fit` is `TRUE` on the row chosen by the ONS best-fit lookup
(version 2), which assigns every 2011 LSOA to exactly one 2021 LSOA;
re-vintaging counts with the `best_fit` rows is deterministic but leaves
the 2021 LSOAs that no 2011 LSOA best-fits to without data.

Source: Office for National Statistics licensed under the Open
Government Licence v3.0. Retrieved 2026-09-16; see
`inst/NOTES/data_sources.md`.

## See also

Other bundled data:
[`lamp_area_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_area_lookup.md),
[`lamp_bank_holidays()`](https://blackthrive.github.io/streetlamp/reference/lamp_bank_holidays.md),
[`lamp_crime_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_crime_types.md),
[`lamp_deprivation()`](https://blackthrive.github.io/streetlamp/reference/lamp_deprivation.md),
[`lamp_forces()`](https://blackthrive.github.io/streetlamp/reference/lamp_forces.md),
[`lamp_outcome_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_outcome_types.md),
[`lamp_sample_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_sample_panel.md),
[`lamp_shocks()`](https://blackthrive.github.io/streetlamp/reference/lamp_shocks.md)

## Examples

``` r
length(lamp_lsoa_codes("lsoa21"))
#> [1] 35672
length(lamp_lsoa_codes("lsoa11"))
#> [1] 34753
table(lamp_lsoa_lookup()$change)
#> 
#>     U     S     M     X 
#> 33647  1900   239    10 
```

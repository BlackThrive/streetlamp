# Small-area deprivation indices for England and Wales

The English Indices of Deprivation 2025 (IoD2025, 33,755 LSOAs) and the
Welsh Index of Multiple Deprivation 2025 (WIMD2025, 1,917 LSOAs), both
on 2021 LSOAs, as a compact table for covariates and heterogeneity
analysis. The two indices are separate national rankings built from
different indicators, so ranks and deciles are comparable only within a
country; `rank / n_lsoas` gives a within-country percentile. Domain
deciles cover the seven domains the two indices share; Wales's community
safety domain is held in `decile_crime` and its physical environment
domain in `decile_environment`. England's domain deciles are as
published; Wales's are formed within Wales from the published domain
ranks, with the same thresholds as its published overall decile.

## Usage

``` r
lamp_deprivation()
```

## Value

A tibble with columns `lsoa21`, `country`, `index`, `score` (IMD score,
England only), `rank`, `decile` (1 is most deprived), `decile_income`,
`decile_employment`, `decile_education`, `decile_health`,
`decile_crime`, `decile_housing`, `decile_environment` and `n_lsoas`.

## Details

Sources: MHCLG, English indices of deprivation 2025, File 7 (published
30 October 2025, corrected 19 November 2025); Welsh Government, WIMD
2025 index and domain ranks by small area (published 27 November 2025).
Both Open Government Licence v3.0; retrieved 2026-09-16.

## See also

Other bundled data:
[`lamp_area_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_area_lookup.md),
[`lamp_bank_holidays()`](https://blackthrive.github.io/streetlamp/reference/lamp_bank_holidays.md),
[`lamp_crime_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_crime_types.md),
[`lamp_forces()`](https://blackthrive.github.io/streetlamp/reference/lamp_forces.md),
[`lamp_lsoa_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_lookup.md),
[`lamp_outcome_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_outcome_types.md),
[`lamp_sample_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_sample_panel.md),
[`lamp_shocks()`](https://blackthrive.github.io/streetlamp/reference/lamp_shocks.md)

## Examples

``` r
dep <- lamp_deprivation()
table(dep$country, dep$decile)[, 1:3]
#>          
#>              1    2    3
#>   england 3375 3376 3375
#>   wales    191  191  192
```

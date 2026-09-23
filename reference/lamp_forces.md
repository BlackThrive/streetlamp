# Police forces in the data.police.uk archive

The 45 forces whose files appear in the archive: the 43 territorial
forces of England and Wales, the Police Service of Northern Ireland and
British Transport Police, with the identifier used in archive file
names, the force name as published by the police.uk API, and the ONS
police force area code (December 2025) where one exists.

## Usage

``` r
lamp_forces()
```

## Value

A tibble with columns `force_id`, `name`, `pfa_code`, `pfa_name`,
`country` (`england`, `wales`, `northern_ireland` or `NA`) and `notes`.

## Details

British Transport Police has no police force area; its records carry
`British Transport Police` in the `Falls within` column rather than the
territorial force in whose area the offence occurred. Greater Manchester
Police has submitted no data since 2019 and is absent from recent
archive snapshots.

Sources: <https://data.police.uk/api/forces> and the ONS Police Force
Areas (December 2025) Names and Codes in the United Kingdom, both
retrieved 2026-09-16; Open Government Licence v3.0.

## See also

Other bundled data:
[`lamp_area_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_area_lookup.md),
[`lamp_bank_holidays()`](https://blackthrive.github.io/streetlamp/reference/lamp_bank_holidays.md),
[`lamp_crime_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_crime_types.md),
[`lamp_deprivation()`](https://blackthrive.github.io/streetlamp/reference/lamp_deprivation.md),
[`lamp_lsoa_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_lookup.md),
[`lamp_outcome_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_outcome_types.md),
[`lamp_sample_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_sample_panel.md),
[`lamp_shocks()`](https://blackthrive.github.io/streetlamp/reference/lamp_shocks.md)

## Examples

``` r
lamp_forces()
#> # A tibble: 45 × 6
#>    force_id           name                       pfa_code pfa_name country notes
#>    <chr>              <chr>                      <chr>    <chr>    <chr>   <chr>
#>  1 avon-and-somerset  Avon and Somerset Constab… E230000… Avon an… england NA   
#>  2 bedfordshire       Bedfordshire Police        E230000… Bedford… england NA   
#>  3 btp                British Transport Police   NA       NA       NA      No p…
#>  4 cambridgeshire     Cambridgeshire Constabula… E230000… Cambrid… england NA   
#>  5 cheshire           Cheshire Constabulary      E230000… Cheshire england NA   
#>  6 city-of-london     City of London Police      E230000… London,… england NA   
#>  7 cleveland          Cleveland Police           E230000… Clevela… england NA   
#>  8 cumbria            Cumbria Constabulary       E230000… Cumbria  england NA   
#>  9 derbyshire         Derbyshire Constabulary    E230000… Derbysh… england NA   
#> 10 devon-and-cornwall Devon & Cornwall Police    E230000… Devon &… england NA   
#> # ℹ 35 more rows
```

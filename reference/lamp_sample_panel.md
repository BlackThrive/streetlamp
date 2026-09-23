# The bundled sample panel and boundaries

A ready-made
[`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md)
for West Yorkshire and Dyfed-Powys: every 2021 LSOA in the two police
force areas over the 24 most recent complete months in the July 2026
archive snapshot (August 2024 to July 2026), with crime by type,
anti-social behaviour, stops and Section 60 stops assigned by location,
Census 2021 population, stop rate, and deprivation deciles as
covariates. Its contract records the archive versions, coverage,
geography and adjacency it was built with. `lamp_sample_boundaries()`
returns the matching ONS generalised boundaries, simplified to 50 m for
bundling, as an `sf` layer in British National Grid.

## Usage

``` r
lamp_sample_panel()

lamp_sample_boundaries()
```

## Value

`lamp_sample_panel()` returns a `lamp_panel`; `lamp_sample_boundaries()`
an `sf` object with columns `area`, `name` and `geometry`.

## Details

The panel is aggregated counts, not records, and is meant for examples,
tests and the vignettes. Data: data.police.uk, Office for National
Statistics and NOMIS, Open Government Licence v3.0; see
`inst/extdata/README.md`.

## See also

Other bundled data:
[`lamp_area_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_area_lookup.md),
[`lamp_bank_holidays()`](https://blackthrive.github.io/streetlamp/reference/lamp_bank_holidays.md),
[`lamp_crime_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_crime_types.md),
[`lamp_deprivation()`](https://blackthrive.github.io/streetlamp/reference/lamp_deprivation.md),
[`lamp_forces()`](https://blackthrive.github.io/streetlamp/reference/lamp_forces.md),
[`lamp_lsoa_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_lookup.md),
[`lamp_outcome_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_outcome_types.md),
[`lamp_shocks()`](https://blackthrive.github.io/streetlamp/reference/lamp_shocks.md)

## Examples

``` r
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
lamp_coverage(panel)
#> streetlamp coverage: 2 forces, 2 file types, 16 mismatched force-months.
#> # A tibble: 96 × 10
#>    force_id    month      file_type       status    n_records archive n_versions
#>    <chr>       <date>     <chr>           <chr>         <int> <chr>        <int>
#>  1 dyfed-powys 2024-08-01 stop-and-search submitted       279 2026-07          2
#>  2 dyfed-powys 2024-09-01 stop-and-search submitted       280 2026-07          2
#>  3 dyfed-powys 2024-10-01 stop-and-search submitted       355 2026-07          2
#>  4 dyfed-powys 2024-11-01 stop-and-search submitted       320 2026-07          2
#>  5 dyfed-powys 2024-12-01 stop-and-search submitted       221 2026-07          2
#>  6 dyfed-powys 2025-01-01 stop-and-search submitted       270 2026-07          2
#>  7 dyfed-powys 2025-02-01 stop-and-search submitted       271 2026-07          2
#>  8 dyfed-powys 2025-03-01 stop-and-search submitted       315 2026-07          2
#>  9 dyfed-powys 2025-04-01 stop-and-search submitted       273 2026-07          2
#> 10 dyfed-powys 2025-05-01 stop-and-search submitted       275 2026-07          2
#> # ℹ 86 more rows
#> # ℹ 3 more variables: versions_differ <lgl>, note <chr>, mismatch <lgl>
bnd <- lamp_sample_boundaries()
nrow(bnd)
#> [1] 1710
```

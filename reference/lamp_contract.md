# The panel contract

Every table streetlamp derives from the archive carries a contract as an
attribute: the archive snapshots and versions it was built from, the
coverage status of every force-month, the LSOA vintage, the crime scope,
the stop-count definition and the treatment definition.
`lamp_contract()` returns it; the contract survives subsetting with `[`
and dplyr verbs.

## Usage

``` r
lamp_contract(x)
```

## Arguments

- x:

  A table produced by a `lamp_read_*()` function or by
  [`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md),
  or a contract.

## Value

A list of class `lamp_contract` with elements `source`, `snapshots`,
`versions`, `coverage`, `geography`, `population`, `crime_scope`,
`stops`, `treatment` and `created`. Elements not yet applicable are
`NULL`.

## Examples

``` r
cache <- tempfile("streetlamp-cache-")
zip <- system.file("extdata", "archive", "2026-07.zip", package = "streetlamp")
lamp_archive_register(zip, dir = cache)
#> Registered archive "2026-07" from
#> /home/runner/work/_temp/Library/streetlamp/extdata/archive/2026-07.zip.
crime <- lamp_read_crime(cache, forces = "dyfed-powys")
contract <- lamp_contract(crime)
contract
#> 
#> ── streetlamp contract 
#> Source: data.police.uk archive
#> Archives: "2026-07"
#> Coverage, street force-months: submitted 3
#> Source LSOA vintage: "lsoa21"
#> Crime category sets: "fourteen"
#> Treatment: not defined
#> Created 2026-09-24 20:24 with streetlamp 0.1.0
contract$coverage
#> # A tibble: 3 × 8
#>   force_id    month      file_type status    archive n_records n_versions
#>   <chr>       <date>     <chr>     <chr>     <chr>       <int>      <int>
#> 1 dyfed-powys 2026-05-01 street    submitted 2026-07       968          1
#> 2 dyfed-powys 2026-06-01 street    submitted 2026-07       925          1
#> 3 dyfed-powys 2026-07-01 street    submitted 2026-07       979          1
#> # ℹ 1 more variable: versions_differ <lgl>
```

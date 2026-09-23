# Bank holidays in England and Wales

Bank and public holidays in England and Wales from 2010 onwards, for
seasonality controls. Rows from 2012 onwards are taken verbatim from the
GOV.UK bank holidays feed (the current feed for 2019 onwards and
archived copies of the same feed for 2012 to 2018); 2010 and 2011 are
transcribed from the archived Directgov bank holidays page. Apostrophes
are normalised to ASCII.

## Usage

``` r
lamp_bank_holidays()
```

## Value

A tibble with columns `date` (`Date`), `title`, `notes` (for example
`Substitute day`), `bunting` (logical, as published; `NA` for the
transcribed 2010 and 2011 rows), `source` and `source_url`.

## See also

Other bundled data:
[`lamp_area_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_area_lookup.md),
[`lamp_crime_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_crime_types.md),
[`lamp_deprivation()`](https://blackthrive.github.io/streetlamp/reference/lamp_deprivation.md),
[`lamp_forces()`](https://blackthrive.github.io/streetlamp/reference/lamp_forces.md),
[`lamp_lsoa_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_lookup.md),
[`lamp_outcome_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_outcome_types.md),
[`lamp_sample_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_sample_panel.md),
[`lamp_shocks()`](https://blackthrive.github.io/streetlamp/reference/lamp_shocks.md)

## Examples

``` r
bh <- lamp_bank_holidays()
range(bh$date)
#> [1] "2010-01-01" "2028-12-26"
bh[format(bh$date, "%Y") == "2023", c("date", "title")]
#> # A tibble: 9 × 2
#>   date       title                                              
#>   <date>     <chr>                                              
#> 1 2023-01-02 New Year's Day                                     
#> 2 2023-04-07 Good Friday                                        
#> 3 2023-04-10 Easter Monday                                      
#> 4 2023-05-01 Early May bank holiday                             
#> 5 2023-05-08 Bank holiday for the coronation of King Charles III
#> 6 2023-05-29 Spring bank holiday                                
#> 7 2023-08-28 Summer bank holiday                                
#> 8 2023-12-25 Christmas Day                                      
#> 9 2023-12-26 Boxing Day                                         
```

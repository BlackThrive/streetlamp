# Crime type classification used by data.police.uk

data.police.uk assigns every record in the street-level files to one of
fourteen categories: anti-social behaviour plus thirteen crime types.
This table gives the labels exactly as they appear in the `Crime type`
column of the archive CSV files, a snake_case key used for panel
columns, the slug used by the police.uk API, and two package-defined
groupings.

## Usage

``` r
lamp_crime_types()
```

## Value

A tibble with one row per category and columns `crime_type`, `key`,
`api_slug`, `is_asb`, `in_crime_total`, `group` and `broad_group`.

## Details

Anti-social behaviour (ASB) is not a crime: ASB incidents carry no Crime
ID and no outcome, so `is_asb` is `TRUE` and `in_crime_total` is `FALSE`
for that row and
[`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md)
keeps ASB in its own series.

The category set was verified against the police.uk API and archive
files on 2026-09-16. It has been stable since the May 2013 data, when
data.police.uk introduced bicycle theft and theft from the person
(previously within other theft), split public disorder and weapons into
possession of weapons and public order, and renamed violent crime to
violence and sexual offences. Files for September 2011 to April 2013 use
eleven categories and files for December 2010 to August 2011 only six,
with a very broad other crime. `since` gives the first data month of
each current category;
[`lamp_read_crime()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_crime.md)
maps legacy labels where the mapping is one to one and keeps
`Public disorder and weapons` as its own level.

`group` follows the Home Office offence groups with the six theft
categories combined; `broad_group` collapses further into `violent`,
`acquisitive`, `drugs`, `damage`, `other` and `asb`. Both groupings are
the package's own and are documented here so that results by offence
group can be reproduced.

## See also

[`lamp_outcome_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_outcome_types.md)

Other bundled data:
[`lamp_area_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_area_lookup.md),
[`lamp_bank_holidays()`](https://blackthrive.github.io/streetlamp/reference/lamp_bank_holidays.md),
[`lamp_deprivation()`](https://blackthrive.github.io/streetlamp/reference/lamp_deprivation.md),
[`lamp_forces()`](https://blackthrive.github.io/streetlamp/reference/lamp_forces.md),
[`lamp_lsoa_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_lookup.md),
[`lamp_outcome_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_outcome_types.md),
[`lamp_sample_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_sample_panel.md),
[`lamp_shocks()`](https://blackthrive.github.io/streetlamp/reference/lamp_shocks.md)

## Examples

``` r
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
```

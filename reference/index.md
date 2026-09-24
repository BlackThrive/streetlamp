# Package index

## Ingest

Acquire force-month files from the data.police.uk archive without
downloading whole snapshots, choose one version per force-month, and
read crime, outcome and stop-count tables that carry a panel contract.

- [`lamp_archive_download()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_download.md)
  : Download force-month files from the data.police.uk archive
- [`lamp_archive_index()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_index.md)
  : Index of the data.police.uk archive
- [`lamp_archive_register()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_register.md)
  : Register a locally downloaded archive zip
- [`lamp_archive_snapshot()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_snapshot.md)
  : Snapshot of the archive files held locally
- [`lamp_list_versions()`](https://blackthrive.github.io/streetlamp/reference/lamp_list_versions.md)
  : List the archive versions of every force-month file
- [`lamp_lsoa_vintage()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_vintage.md)
  : Detect whether LSOA codes are 2011 or 2021 vintage
- [`lamp_read_crime()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_crime.md)
  : Read street-level crime records from the archive
- [`lamp_read_outcomes()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_outcomes.md)
  : Read outcome records from the archive
- [`lamp_read_stop_counts()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_stop_counts.md)
  : Count stops by area and month
- [`lamp_s60_legislation()`](https://blackthrive.github.io/streetlamp/reference/lamp_s60_legislation.md)
  : Legislation label for Section 60 searches
- [`lamp_select_version()`](https://blackthrive.github.io/streetlamp/reference/lamp_select_version.md)
  : Select one archive version per force-month file
- [`lamp_version_diff()`](https://blackthrive.github.io/streetlamp/reference/lamp_version_diff.md)
  : Compare the archive versions of one force-month file

## Panel and coverage

Geography, population, the balanced area-by-month panel and the coverage
audit.

- [`lamp_adjacency()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency.md)
  : Spatial adjacency for a set of areas
- [`lamp_adjacency_from_nb()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency_from_nb.md)
  : Build an adjacency object from a neighbour list
- [`lamp_boundaries()`](https://blackthrive.github.io/streetlamp/reference/lamp_boundaries.md)
  : ONS digital boundaries as an sf layer
- [`lamp_changelog()`](https://blackthrive.github.io/streetlamp/reference/lamp_changelog.md)
  : The data.police.uk changelog as a table of refresh and gap notes
- [`lamp_coverage()`](https://blackthrive.github.io/streetlamp/reference/lamp_coverage.md)
  [`lamp_coverage_compare()`](https://blackthrive.github.io/streetlamp/reference/lamp_coverage.md)
  : Coverage audit: which force-months exist, and can be compared
- [`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md)
  : Build an area-by-month panel of crime and stops
- [`lamp_population()`](https://blackthrive.github.io/streetlamp/reference/lamp_population.md)
  : Census 2021 usual resident population by area
- [`lamp_revintage()`](https://blackthrive.github.io/streetlamp/reference/lamp_revintage.md)
  : Re-vintage LSOA codes between 2011 and 2021

## Treatment

Define what is being evaluated: a continuous stop intensity, an
intervention in named areas, staggered adoption dates, or a dated shock.

- [`lamp_detect_surges()`](https://blackthrive.github.io/streetlamp/reference/lamp_detect_surges.md)
  : Detect surges in stop and search activity
- [`lamp_treatment()`](https://blackthrive.github.io/streetlamp/reference/lamp_treatment.md)
  : Define the treatment

## Estimators

Panel estimators, each reporting its identifying assumption, clustered
standard errors and the force-months it excluded.

- [`lamp_allocation()`](https://blackthrive.github.io/streetlamp/reference/lamp_allocation.md)
  : How stop and search activity follows recorded crime
- [`lamp_crimes_prevented()`](https://blackthrive.github.io/streetlamp/reference/lamp_crimes_prevented.md)
  : Convert an estimate into crimes prevented per thousand searches
- [`lamp_did_staggered()`](https://blackthrive.github.io/streetlamp/reference/lamp_did_staggered.md)
  : Difference-in-differences with staggered adoption
- [`lamp_displacement_quotient()`](https://blackthrive.github.io/streetlamp/reference/lamp_displacement_quotient.md)
  : Weighted displacement quotient
- [`lamp_elasticity()`](https://blackthrive.github.io/streetlamp/reference/lamp_elasticity.md)
  : Elasticity of crime with respect to stop and search
- [`lamp_event_study()`](https://blackthrive.github.io/streetlamp/reference/lamp_event_study.md)
  : Event study around a dated intervention
- [`lamp_spillover()`](https://blackthrive.github.io/streetlamp/reference/lamp_spillover.md)
  : Own-area and neighbour effects estimated together
- [`lamp_synth()`](https://blackthrive.github.io/streetlamp/reference/lamp_synth.md)
  : Synthetic control for a single treated area or force
- [`lamp_twfe()`](https://blackthrive.github.io/streetlamp/reference/lamp_twfe.md)
  : Two-way fixed effects estimate of the effect of stops on crime
- [`tidy(`*`<lamp_estimate>`*`)`](https://blackthrive.github.io/streetlamp/reference/tidy.lamp_estimate.md)
  : Tidy a streetlamp estimate

## Diagnostics

What the estimates are worth: pre-trend testing with power, and placebo
tests in time, space and outcome.

- [`lamp_placebo()`](https://blackthrive.github.io/streetlamp/reference/lamp_placebo.md)
  : Placebo tests for a streetlamp estimate
- [`lamp_pretrends()`](https://blackthrive.github.io/streetlamp/reference/lamp_pretrends.md)
  : Test and interpret pre-trends

## Simulation

- [`lamp_simulate()`](https://blackthrive.github.io/streetlamp/reference/lamp_simulate.md)
  : Simulate a panel with a known treatment effect

## Reporting

- [`lamp_report()`](https://blackthrive.github.io/streetlamp/reference/lamp_report.md)
  : Build a report on a panel and the estimates made from it

## Plots and tables

The colours and theme every plot method draws with, and presentation
tables with terms in words, intervals in brackets and rounded p values.

- [`lamp_colours()`](https://blackthrive.github.io/streetlamp/reference/lamp_colours.md)
  : The colours streetlamp draws with
- [`lamp_table()`](https://blackthrive.github.io/streetlamp/reference/lamp_table.md)
  : A presentation-ready table from a streetlamp object
- [`lamp_theme()`](https://blackthrive.github.io/streetlamp/reference/lamp_theme.md)
  : The ggplot2 theme streetlamp plots use

## Contract

- [`lamp_contract()`](https://blackthrive.github.io/streetlamp/reference/lamp_contract.md)
  : The panel contract

## Bundled reference tables

Curated tables shipped with the package: crime and outcome
classifications, national policy shocks, bank holidays and the ONS LSOA
code lists and 2011 to 2021 best-fit lookup.

- [`lamp_area_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_area_lookup.md)
  : Area hierarchy for 2021 LSOAs
- [`lamp_bank_holidays()`](https://blackthrive.github.io/streetlamp/reference/lamp_bank_holidays.md)
  : Bank holidays in England and Wales
- [`lamp_crime_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_crime_types.md)
  : Crime type classification used by data.police.uk
- [`lamp_deprivation()`](https://blackthrive.github.io/streetlamp/reference/lamp_deprivation.md)
  : Small-area deprivation indices for England and Wales
- [`lamp_forces()`](https://blackthrive.github.io/streetlamp/reference/lamp_forces.md)
  : Police forces in the data.police.uk archive
- [`lamp_lsoa_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_lookup.md)
  [`lamp_lsoa_codes()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_lookup.md)
  : ONS LSOA code lists and the 2011 to 2021 lookup
- [`lamp_outcome_types()`](https://blackthrive.github.io/streetlamp/reference/lamp_outcome_types.md)
  : Outcome classification used by data.police.uk
- [`lamp_sample_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_sample_panel.md)
  [`lamp_sample_boundaries()`](https://blackthrive.github.io/streetlamp/reference/lamp_sample_panel.md)
  : The bundled sample panel and boundaries
- [`lamp_shocks()`](https://blackthrive.github.io/streetlamp/reference/lamp_shocks.md)
  : National policy shocks affecting stop and search or recorded crime

## Cache

- [`lamp_cache_dir()`](https://blackthrive.github.io/streetlamp/reference/lamp_cache_dir.md)
  [`lamp_cache_clear()`](https://blackthrive.github.io/streetlamp/reference/lamp_cache_dir.md)
  : Location of the streetlamp cache

## Package

- [`streetlamp`](https://blackthrive.github.io/streetlamp/reference/streetlamp-package.md)
  [`streetlamp-package`](https://blackthrive.github.io/streetlamp/reference/streetlamp-package.md)
  : streetlamp: Panel Econometrics for the Effect of Police Stop and
  Search on Recorded Crime

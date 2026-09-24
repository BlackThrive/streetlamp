# Changelog

## streetlamp 0.1.0

- The [`plot()`](https://rdrr.io/r/graphics/plot.default.html) methods
  for estimates and staggered fits wrap the identifying assumption in
  the subtitle instead of letting it run off the panel, and
  [`lamp_elasticity()`](https://blackthrive.github.io/streetlamp/reference/lamp_elasticity.md)
  no longer leaves a stray space before the full stop in its assumption
  text.
- First release. Builds an area-by-month panel of recorded crime in
  England and Wales from the data.police.uk archive, attaches stop and
  search intensity as a treatment, and estimates its effect with panel
  econometrics. Every panel carries a contract recording provenance and
  coverage; every estimator names its identifying assumption and reports
  the force-months it excluded.
- M5: the report builder
  ([`lamp_report()`](https://blackthrive.github.io/streetlamp/reference/lamp_report.md)),
  the methods note in `inst/NOTES/methods.md`, validation scripts in
  `inst/scripts/` for the simulation study, placebo battery, benchmark
  and fixed-specification reproduction, and five precomputed vignettes.
- M4: difference-in-differences with staggered adoption over three
  backends
  ([`lamp_did_staggered()`](https://blackthrive.github.io/streetlamp/reference/lamp_did_staggered.md));
  synthetic control with permutation inference and a dependency-free
  solver
  ([`lamp_synth()`](https://blackthrive.github.io/streetlamp/reference/lamp_synth.md));
  joint own-area and neighbour effects
  ([`lamp_spillover()`](https://blackthrive.github.io/streetlamp/reference/lamp_spillover.md))
  and the weighted displacement quotient
  ([`lamp_displacement_quotient()`](https://blackthrive.github.io/streetlamp/reference/lamp_displacement_quotient.md));
  stop-crime elasticities with common correlated effects and Pesaran’s
  CD test
  ([`lamp_elasticity()`](https://blackthrive.github.io/streetlamp/reference/lamp_elasticity.md));
  the allocation model that measures how searching follows crime
  ([`lamp_allocation()`](https://blackthrive.github.io/streetlamp/reference/lamp_allocation.md));
  and the conversion to crimes prevented per thousand searches with its
  assumption chain
  ([`lamp_crimes_prevented()`](https://blackthrive.github.io/streetlamp/reference/lamp_crimes_prevented.md)).
- M3: treatment definitions for continuous intensity, binary
  interventions, staggered adoption and dated shocks
  ([`lamp_treatment()`](https://blackthrive.github.io/streetlamp/reference/lamp_treatment.md)),
  with surge detection
  ([`lamp_detect_surges()`](https://blackthrive.github.io/streetlamp/reference/lamp_detect_surges.md))
  documented as endogenous; two-way fixed effects
  ([`lamp_twfe()`](https://blackthrive.github.io/streetlamp/reference/lamp_twfe.md))
  and event studies
  ([`lamp_event_study()`](https://blackthrive.github.io/streetlamp/reference/lamp_event_study.md))
  over four families, with clustered standard errors, dispersion and
  Moran’s I of the residuals; pre-trend testing with the power to detect
  a linear trend and the bias it would leave
  ([`lamp_pretrends()`](https://blackthrive.github.io/streetlamp/reference/lamp_pretrends.md));
  placebo tests in time, space and outcome
  ([`lamp_placebo()`](https://blackthrive.github.io/streetlamp/reference/lamp_placebo.md));
  and a simulator with known effects, spillovers on a lattice and
  force-month missingness
  ([`lamp_simulate()`](https://blackthrive.github.io/streetlamp/reference/lamp_simulate.md)).
- M2: ONS boundaries by paged FeatureServer requests
  ([`lamp_boundaries()`](https://blackthrive.github.io/streetlamp/reference/lamp_boundaries.md)),
  spatial adjacency
  ([`lamp_adjacency()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency.md)),
  Census 2021 population from NOMIS
  ([`lamp_population()`](https://blackthrive.github.io/streetlamp/reference/lamp_population.md)),
  LSOA re-vintaging
  ([`lamp_revintage()`](https://blackthrive.github.io/streetlamp/reference/lamp_revintage.md)),
  the area hierarchy
  ([`lamp_area_lookup()`](https://blackthrive.github.io/streetlamp/reference/lamp_area_lookup.md))
  and deprivation deciles
  ([`lamp_deprivation()`](https://blackthrive.github.io/streetlamp/reference/lamp_deprivation.md));
  the balanced area-by-month panel
  ([`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md))
  with NA, never zero, for force-months without a file; the coverage
  audit
  ([`lamp_coverage()`](https://blackthrive.github.io/streetlamp/reference/lamp_coverage.md),
  [`lamp_coverage_compare()`](https://blackthrive.github.io/streetlamp/reference/lamp_coverage.md),
  [`lamp_changelog()`](https://blackthrive.github.io/streetlamp/reference/lamp_changelog.md))
  with partial, refreshed and mismatched-file-type flags and a heat map;
  and the bundled sample panel and boundaries
  ([`lamp_sample_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_sample_panel.md),
  [`lamp_sample_boundaries()`](https://blackthrive.github.io/streetlamp/reference/lamp_sample_panel.md)).
- M1: selective download from the data.police.uk archive by HTTP byte
  range
  ([`lamp_archive_index()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_index.md),
  [`lamp_archive_download()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_download.md),
  [`lamp_archive_register()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_register.md),
  [`lamp_archive_snapshot()`](https://blackthrive.github.io/streetlamp/reference/lamp_archive_snapshot.md));
  one archive version per force-month file with alternatives recorded
  ([`lamp_list_versions()`](https://blackthrive.github.io/streetlamp/reference/lamp_list_versions.md),
  [`lamp_select_version()`](https://blackthrive.github.io/streetlamp/reference/lamp_select_version.md),
  [`lamp_version_diff()`](https://blackthrive.github.io/streetlamp/reference/lamp_version_diff.md));
  readers with a fixed schema and a panel contract
  ([`lamp_read_crime()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_crime.md),
  [`lamp_read_outcomes()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_outcomes.md),
  [`lamp_read_stop_counts()`](https://blackthrive.github.io/streetlamp/reference/lamp_read_stop_counts.md),
  [`lamp_contract()`](https://blackthrive.github.io/streetlamp/reference/lamp_contract.md));
  LSOA vintage detection
  ([`lamp_lsoa_vintage()`](https://blackthrive.github.io/streetlamp/reference/lamp_lsoa_vintage.md));
  the forces table
  ([`lamp_forces()`](https://blackthrive.github.io/streetlamp/reference/lamp_forces.md));
  and two bundled miniature archive snapshots for offline examples and
  tests.
- M0: package skeleton, MIT licence, continuous integration, testthat,
  pkgdown, lintr; bundled crime and outcome classifications, national
  policy shocks table, bank holidays table, and ONS LSOA 2011 and 2021
  code lists with the 2011 to 2021 best-fit lookup.

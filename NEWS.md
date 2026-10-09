# streetlamp 0.2.0.9000

* `lamp_map()` draws the geography the package has carried since the start and
  never showed: a choropleth of any panel column, of the per-area slopes of a
  mean group elasticity, or of the donor weights behind a synthetic control.
  The rule that governs the rest of the package governs the map too. An area
  with no usable data is filled in a neutral grey and counted in the caption,
  never shaded as though it were quiet, and an area the panel never covered is
  counted separately from one whose files were missing, because they are not
  the same thing. Fills are sequential, or diverging and centred on zero where
  the values cross it, from the same palette as every other figure.

* `lamp_elasticity()` defaults to clustered Poisson pseudo-likelihood for the
  fixed-effects method. This estimates the conditional count mean and avoids
  treating log-one-plus observed counts as log expected counts. Use
  `family = "ols_log"` for the former response scale; CCE still uses that scale.
  Calendar lags now preserve missing-month gaps. Lag-sum intervals use joint
  covariance and the backend's reference distribution.
* `lamp_simulate()` supports cohort-specific effects, dynamic effect paths,
  overdispersed counts, selective missing submissions, and deliberate trend
  violations. An additive count design supports count-level parallel trends.
  `lamp_simulation_truth()` exposes exact area-month counterfactual means on
  either the count-difference or log-mean scale.
* `lamp_effect_summary()` uses joint covariance for effect combinations and
  each staggered backend's own overall ATT. `lamp_trend_sensitivity()` reports
  conditional sensitivity to specified differential linear trends.
* `lamp_design_audit()` records data support and identification questions.
  `lamp_elasticity_robustness()` retains complete specification grids,
  failures, and optional leave-one-area-out results.
* Crimes-prevented conversions account for log-one-plus stops, use the fitted
  sample, preserve covariance in event averages, distinguish count-level
  effects, and transform intervals directly. IHS effects require predictions
  and are rejected by the simple conversion.
* New research validation and a hash-verified London association study are
  separate from historical 0.1.0 results. London is explicitly observational;
  its comparison-outcome and future-exposure diagnostics are retained.

# streetlamp 0.1.0

* One visual system for every figure and table. `lamp_theme()` and
  `lamp_colours()` are exported and every `plot()` method uses them: a
  recessive hairline grid, left-aligned titles, forces and outcomes named in
  words, thousands separators on axes, and a palette checked as a set for
  colour-vision deficiency. Event studies, staggered fits and pre-trend
  diagnostics draw an interval ribbon with the reference period hollow;
  coefficient plots print the estimate and interval beside each mark; the
  placebo histogram labels the actual estimate and reports its p value; the
  synthetic control path labels both series at the line ends and shades the
  pre-period like the event study does.
* `lamp_table()` formats any estimate, pre-trend diagnostic, synthetic
  control or coverage audit as a presentation table: terms in words, the
  95 percent interval in brackets, p values as `<0.001` where they are that
  small, ready for `knitr::kable()`. The print methods and the report use
  it, so a console print no longer shows p values in scientific notation.
* `lamp_report()` HTML output is styled by a bundled stylesheet, embeds each
  estimate's plot (new `figures` argument), and renders tables with numeric
  columns right-aligned.
* The `plot()` methods for estimates and staggered fits wrap the identifying
  assumption in the subtitle instead of letting it run off the panel, and
  `lamp_elasticity()` no longer leaves a stray space before the full stop in
  its assumption text.
* First release. Builds an area-by-month panel of recorded crime in England
  and Wales from the data.police.uk archive, attaches stop and search
  intensity as a treatment, and estimates its effect with panel econometrics.
  Every panel carries a contract recording provenance and coverage; every
  estimator names its identifying assumption and reports the force-months it
  excluded.
* M5: the report builder (`lamp_report()`), the methods note in
  `inst/NOTES/methods.md`, validation scripts in `inst/scripts/` for the
  simulation study, placebo battery, benchmark and fixed-specification
  reproduction, and five precomputed vignettes.
* M4: difference-in-differences with staggered adoption over three backends
  (`lamp_did_staggered()`); synthetic control with permutation inference and
  a dependency-free solver (`lamp_synth()`); joint own-area and neighbour
  effects (`lamp_spillover()`) and the weighted displacement quotient
  (`lamp_displacement_quotient()`); stop-crime elasticities with common
  correlated effects and Pesaran's CD test (`lamp_elasticity()`); the
  allocation model that measures how searching follows crime
  (`lamp_allocation()`); and the conversion to crimes prevented per thousand
  searches with its assumption chain (`lamp_crimes_prevented()`).
* M3: treatment definitions for continuous intensity, binary interventions,
  staggered adoption and dated shocks (`lamp_treatment()`), with surge
  detection (`lamp_detect_surges()`) documented as endogenous; two-way fixed
  effects (`lamp_twfe()`) and event studies (`lamp_event_study()`) over four
  families, with clustered standard errors, dispersion and Moran's I of the
  residuals; pre-trend testing with the power to detect a linear trend and
  the bias it would leave (`lamp_pretrends()`); placebo tests in time, space
  and outcome (`lamp_placebo()`); and a simulator with known effects,
  spillovers on a lattice and force-month missingness (`lamp_simulate()`).
* M2: ONS boundaries by paged FeatureServer requests (`lamp_boundaries()`),
  spatial adjacency (`lamp_adjacency()`), Census 2021 population from NOMIS
  (`lamp_population()`), LSOA re-vintaging (`lamp_revintage()`), the area
  hierarchy (`lamp_area_lookup()`) and deprivation deciles
  (`lamp_deprivation()`); the balanced area-by-month panel (`lamp_panel()`)
  with NA, never zero, for force-months without a file; the coverage audit
  (`lamp_coverage()`, `lamp_coverage_compare()`, `lamp_changelog()`) with
  partial, refreshed and mismatched-file-type flags and a heat map; and the
  bundled sample panel and boundaries (`lamp_sample_panel()`,
  `lamp_sample_boundaries()`).
* M1: selective download from the data.police.uk archive by HTTP byte range
  (`lamp_archive_index()`, `lamp_archive_download()`,
  `lamp_archive_register()`, `lamp_archive_snapshot()`); one archive version
  per force-month file with alternatives recorded (`lamp_list_versions()`,
  `lamp_select_version()`, `lamp_version_diff()`); readers with a fixed
  schema and a panel contract (`lamp_read_crime()`, `lamp_read_outcomes()`,
  `lamp_read_stop_counts()`, `lamp_contract()`); LSOA vintage detection
  (`lamp_lsoa_vintage()`); the forces table (`lamp_forces()`); and two
  bundled miniature archive snapshots for offline examples and tests.
* M0: package skeleton, MIT licence, continuous integration, testthat,
  pkgdown, lintr; bundled crime and outcome classifications, national policy
  shocks table, bank holidays table, and ONS LSOA 2011 and 2021 code lists
  with the 2011 to 2021 best-fit lookup.

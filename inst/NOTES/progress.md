# Progress log

One entry per session, three lines: what was done, check status, next step.

## 2026-09-16, session 1 (M0)

- Done: package skeleton (DESCRIPTION, MIT licence, NAMESPACE, README), CI workflows (check matrix, coverage gate, pkgdown, lint/spelling/urlchecker), lintr and pkgdown config, classed conditions, cache helpers, crime and outcome classifications, and bundled tables verified against sources: 29 policy shocks, England and Wales bank holidays 2010 to 2028, ONS LSOA 2011 to 2021 lookup with both code lists; 134 tests.
- Check: `R CMD check --as-cran` clean (0 errors, 0 warnings, 0 notes) on R 4.5.2 Windows; lintr, spelling and styler clean.
- Next: M1 ingestion and versioning (archive index and download with httptest2 fixtures, `lamp_read_crime()`, `lamp_read_outcomes()`, `lamp_read_stop_counts()`, `lamp_contract()`); first verify archive zip layout, CSV headers and the 2011 to 2013 legacy category strings (TODO(source) items in data_sources.md).

## 2026-09-16, session 2 (M1)

- Done: archive index parser, selective download by HTTP byte range with a pure-R zip reader (`lamp_archive_index()`, `lamp_archive_download()`, `lamp_archive_register()`, `lamp_archive_snapshot()`), version listing, selection and diff (`lamp_list_versions()`, `lamp_select_version()`, `lamp_version_diff()`), readers with fixed schemas and contracts (`lamp_read_crime()`, `lamp_read_outcomes()`, `lamp_read_stop_counts()`, `lamp_contract()`), vintage detection (`lamp_lsoa_vintage()`), forces table, two bundled mini archives built from real data, 440 tests; archive layout, category phases, s60 string, BTP attribution, version differences and outcome labels verified against live files.
- Check: `R CMD check --as-cran` clean (0 errors, 0 warnings, 0 notes); lintr, spelling and styler clean; live smoke test against the 2026-06 and 2026-07 archives passed (25 files, 63 MB, 63 s).
- Next: M2 (`lamp_boundaries()`, `lamp_adjacency()`, `lamp_population()`, LSOA re-vintaging, `lamp_panel()`, `lamp_coverage()`, `lamp_coverage_compare()`); first verify ONS boundary products and the NOMIS Census 2021 population API, and check `Falls within` strings for all forces (TODO items in data_sources.md).

## 2026-09-16, session 3 (M2)

- Done: ONS boundaries by paged FeatureServer requests (`lamp_boundaries()`), adjacency (`lamp_adjacency()`), NOMIS Census 2021 population with paging and caching (`lamp_population()`), re-vintaging (`lamp_revintage()`), the LSOA to MSOA to district to force hierarchy (`lamp_area_lookup()`), deprivation deciles for England and Wales (`lamp_deprivation()`), the balanced panel (`lamp_panel()`, NA for missing force-months, re-vintaging in the contract, plot with shaded gaps), the coverage audit (`lamp_coverage()`, `lamp_coverage_compare()`, heat map, partial and mismatch flags) with a changelog parser (`lamp_changelog()`), and the bundled 24-month sample panel and boundaries (`lamp_sample_panel()`, `lamp_sample_boundaries()`); 743 tests; sources verified and recorded.
- Check: `R CMD check --as-cran` clean (0 errors, 0 warnings, 0 notes); lintr, spelling and styler clean; examples under five seconds; tests 176 s.
- Next: M3 (`lamp_treatment()`, `lamp_detect_surges()`, `lamp_twfe()`, `lamp_event_study()`, `lamp_pretrends()`, `lamp_placebo()`, `lamp_simulate()`); add fixest and did to Imports as they are used; consider `skip_on_cran()` for the slowest tests to keep the suite short.

## 2026-09-18, session 4 (M3)

- Done: the simulator with known effects, spillovers on a lattice and force-month missingness (`lamp_simulate()`); treatment definitions for continuous intensity, binary interventions, staggered adoption and dated shocks (`lamp_treatment()`), with endogenous surge detection (`lamp_detect_surges()`); the shared estimate class with clustered errors, exclusion table and identifying assumption; two-way fixed effects and the event study over four families with dispersion and Moran's I; pre-trend testing with Roth-style power (`lamp_pretrends()`); placebo tests in time, space and outcome (`lamp_placebo()`).
- Check: clean; 227 new tests. `lamp_twfe()` matches `fixest` to machine precision; the event design is recovered; the event study refuses staggered adoption.
- Next: M4 (staggered DiD, synthetic control, spillovers, elasticities, allocation, crimes prevented) and vignettes 2 to 4.

## 2026-09-18, session 5 (M4)

- Done: staggered difference-in-differences over three backends (`lamp_did_staggered()`, with the event study delegating to it on request); synthetic control with a dependency-free simplex solver and permutation inference (`lamp_synth()`); joint own-area and neighbour effects (`lamp_spillover()`) and the weighted displacement quotient (`lamp_displacement_quotient()`); elasticities with common correlated effects and Pesaran's CD test (`lamp_elasticity()`); the allocation model (`lamp_allocation()`); crimes prevented with its assumption chain (`lamp_crimes_prevented()`); four precomputed vignettes.
- Check: clean; 204 new tests. Matches `did::att_gt()` on the did package's example data to machine precision; the mean group estimator matches a hand-computed two-area example; the displacement quotient reproduces a hand-computed -1; the biased-TWFE demonstration works.
- Next: M5 (report builder, methods note, validation scripts, release documents).

## 2026-09-18, session 6 (M5)

- Done: the report builder (`lamp_report()`, Markdown or HTML, with coverage, assumptions, diagnostics and standing caveats); `inst/NOTES/methods.md` with the equations, assumptions and limits of every estimator; four validation scripts in `inst/scripts/` (simulation study, placebo battery, benchmark, fixed-specification reproduction); the fifth vignette on simulation evidence; `cran-comments.md` and `RELEASE_READY.md`; README rewritten for the finished package.
- Check: `R CMD check --as-cran` clean (0 errors, 0 warnings, 0 notes) with all five vignettes; 1,180 tests pass; lintr, spelling and styler clean; examples 28 s in total; installed size well under the limit.
- Next: the maintainer's tasks listed in `RELEASE_READY.md`: create the GitHub repository so the CI matrix runs, rhub and win-builder, confirm coverage at or above 85 percent, settle the maintainer email and repository owner, deploy pkgdown, and run the validation scripts once with network access.

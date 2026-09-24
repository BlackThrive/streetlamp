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

## 2026-09-20 to 2026-09-21, session 7 (validation runs and release blockers)

- Done: all four validation scripts run and their output committed under `inst/validation/` with a README explaining what each shows and where the package does badly; coverage measured at 92.36 percent; `R CMD check --as-cran` run with CRAN's incoming and remote checks actually switched on, which devtools disables by default; repository URLs pointed at the maintainer's own GitHub account; `cran-comments.md` corrected to say what has and has not been checked. Three performance defects fixed, each verified against the old implementation (bit-identical for the placebo and the month keys; for the CD test, identical to within floating-point reassociation, because the vectorised form sums through BLAS): Pesaran's CD test built pair by pair (77 s at 400 areas, impossible at national LSOA scale) is now one `cor()` call at 3.6 s with a sampling cap above 2,000 areas; the spatial placebo scanned the panel once per treated area (3 h 20 min for the default 200 draws on the bundled sample) and now reassigns by row key in 1.1 min; `lamp_month_id()` used `format()` on a Date, which was four fifths of every `lamp_twfe()` call and would have been minutes per call on a national panel.
- Check: 0 errors, 0 warnings, 1 note. The note is "New submission" plus the three repository URLs, which return 404 until the repository is created. 1,190 tests pass, 0 skipped. The London reproduction fixture reproduced exactly after all of the above, which is the regression test those changes needed.
- Benchmark: a 36-month national LSOA panel, all 45 forces, 17,828,114 records over 35,672 areas, built in 68 minutes with a peak of about 9 GB; two thirds of that is downloading 7.5 GB of archive members. Two attempts died on reset connections first, which is why `httr2::req_retry()` now has `retry_on_failure = TRUE` and the benchmark script resumes the whole download call as well. A Poisson model with area and month effects over the finished 1.28 million row panel takes 12 seconds.
- Next: the maintainer creates `github.com/BlackThrive/streetlamp` and pushes, publishes the pkgdown site, then rhub and win-builder. Nothing else is outstanding.

## 2026-09-23, session 8 (authorship and repository owner)

- Done: Souci Frissa and Sarah Hamed added to `Authors@R` as authors, with Mustapha Wasseja staying as author and maintainer and Black Thrive Global as copyright holder and funder; `inst/CITATION` written, because without it the generated citation carries no year and reads "(????)"; every repository URL moved to `github.com/BlackThrive/streetlamp` and `blackthrive.github.io/streetlamp/`, replacing both the specification's placeholder and the personal account chosen two days earlier.
- Check: 0 errors, 0 warnings, 1 note, with CRAN's incoming and remote checks on. The note is "New submission" plus the same three URLs, which return 404 until the repository is created; `BlackThrive` itself exists and the maintainer belongs to it. 1,195 tests pass; styler, lintr and spelling clean.
- Next: unchanged. Create the repository under `BlackThrive` and push, publish the pkgdown site, then win-builder and rhub.

## 2026-09-23, session 9 (repository, continuous integration, release state)

- Done: the repository created at `github.com/BlackThrive/streetlamp` and pushed, pkgdown published at `blackthrive.github.io/streetlamp/`, and the nine-configuration check matrix run for the first time. It found two things. A test written on 2026-09-20 asserted `tolerance = 0` between the vectorised CD test and a pair-by-pair reference and failed on all three macOS configurations, because Apple's Accelerate BLAS reassociates the sums; the tolerance is now 1e-10, which is the right claim. macOS on R-devel fails before the package's code runs, because CRAN ships no macOS binaries for R-devel and `sf` and `spdep` cannot build from source on the runner, so that one configuration is `continue-on-error`. The quality workflow's URL gate now reads the URL table rather than letting `urlchecker` abort on it, and fails on an HTTP status rather than on a timeout: GitHub's runners time out on data.police.uk every time, while it answers fine from elsewhere.
- Check: 0 errors, 0 warnings, 1 note, with CRAN's incoming and remote checks on. The note is "New submission" and nothing else; the three repository URLs now resolve. All four workflows green.
- Next: win-builder and rhub, then the maintainer submits.

## 2026-09-24, session 10 (snapshot tests, win-builder)

- Done: `streetlamp_0.1.0.tar.gz` submitted to win-builder on devel and release from a clean tree at 3722dfd; results go to the maintainer. The specification's snapshot tests for plots, which had never been written, now cover all eight plot methods against stored SVG baselines with `vdiffr` in Suggests, skipped on CRAN. They immediately found one: `plot.lamp_did_staggered()` discarded the reference period, which `did` returns with a zero estimate and no standard error, and warned "Removed 1 row containing missing values" on every render; it is now drawn as a hollow point with a caption. The empty `inst/templates/` is gone, the report having always been built in code rather than from a template file. The `lamp_did_staggered()` example is smaller, because loading the `did` package pushed it past the five second note when the machine was busy.
- Check: 0 errors, 0 warnings, 1 note ("New submission"); examples 26 s, tests 79 s. 1,203 tests pass, 0 warnings. styler, lintr and spelling clean.
- win-builder, R 4.6.1 release: 1 note. "New submission", plus `elasticities` and `pre` flagged as possibly misspelled in `DESCRIPTION`; the second is `pre-trend` split at the hyphen. Both are correct, both are explained in `cran-comments.md`, and both are now in `inst/WORDLIST`. Install 15 s, check 236 s, everything else OK.
- Next: the win-builder devel result, then rhub, then the maintainer submits.

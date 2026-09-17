# Release readiness: streetlamp 0.1.0

Evidence that the package meets the acceptance criteria in the build
specification. Written at the end of milestone M5; see
`inst/NOTES/progress.md` for the session-by-session record and
`inst/NOTES/decisions.md` for every choice made without the maintainer.

## Milestones

| Milestone | Content | Status |
|---|---|---|
| M0 | Skeleton, licence, continuous integration, testthat, pkgdown, lintr; bundled shocks, bank holidays, crime and outcome classifications, LSOA code lists | Complete |
| M1 | Archive acquisition and versioning; readers for crime, outcomes and stop counts; the panel contract | Complete |
| M2 | Boundaries, adjacency, population, re-vintaging, the area-by-month panel, the coverage audit | Complete |
| M3 | Treatment definitions, surge detection, two-way fixed effects, event study, pre-trends, placebo tests, simulator | Complete |
| M4 | Staggered difference-in-differences, synthetic control, spillovers and displacement, elasticities, allocation, crimes prevented | Complete |
| M5 | Reporting, methods notes, validation scripts, release documents | Complete |

## Acceptance criteria, milestone by milestone

**M1.** Fixture-backed tests pass offline against two bundled archive
snapshots. Both sample forces read end to end. A force-month present in two
snapshots with different content is reported by `lamp_version_diff()` and one
version is selected and recorded in the contract. Anti-social behaviour rows
carry no crime identifier and are flagged (`test-read-crime.R`).

**M2.** The panel holds `NA`, never zero, for force-months with no file
(`test-panel.R`). Re-vintaging from 2011 to 2021 LSOAs is recorded in the
contract with the split and merge shares (`test-geography.R`,
`test-panel.R`). The coverage heat map renders, and the mismatched-file-type
flag fires on the real gap in the bundled sample, where Dyfed-Powys submitted
crime files but no stop-and-search files from December 2025
(`test-coverage.R`, `test-sample.R`).

**M3.** `lamp_twfe()` matches `fixest` called directly, to machine precision
(`test-twfe.R`). The simulated event design is recovered, and intervals cover
the truth at roughly the nominal rate over replications. `lamp_event_study()`
refuses plain two-way fixed effects under staggered adoption and names the
estimator that replaces it (`test-eventstudy.R`).

**M4.** `lamp_did_staggered()` matches `did::att_gt()` on the `did` package's
own example data, to machine precision, for both the overall effect and the
group-time table (`test-staggered.R`). The spillover design recovers own and
neighbour effects and their net, and a two-way fixed effects model omitting
the spillover term is shown to be biased toward zero (`test-spillover.R`).
The common correlated effects mean group estimator matches a hand-computed
two-area example, coefficient by coefficient and in its standard error
(`test-elasticity.R`). The weighted displacement quotient reproduces a
hand-computed value of exactly -1 on constructed totals
(`test-spillover.R`). `lamp_crimes_prevented()` returns its assumption chain
and prints it (`test-elasticity.R`). Vignettes 2 to 4 render.

**M5.** `lamp_report()` runs end to end on the bundled panel with no network
access (`test-report.R`). Validation scripts are in `inst/scripts/`. Check is
clean; lintr, spelling and styler are clean.

## Checks

* `R CMD check --as-cran`: 0 errors, 0 warnings, 0 notes on R 4.5.2, Windows.
* Tests: see `inst/NOTES/progress.md` for the count at the last run. Heavy
  estimator studies are behind `skip_on_cran()`.
* lintr, spelling and styler: clean.
* Examples: each under five seconds.
* No network in examples, tests or vignettes; vignettes precomputed.

## Still to do before submission

These need the repository and a maintainer decision, and are outside what
could be done here:

1. Create the GitHub repository so that the continuous integration matrix
   (Ubuntu, macOS and Windows, on release, devel and oldrel-1) actually runs.
   The workflows are written and committed.
2. Run rhub and win-builder, and record the results in `cran-comments.md`.
3. Confirm test coverage is at or above 85 percent once the coverage workflow
   has run; the gate is configured to fail below that.
4. Decide the maintainer email (currently the personal address) and the
   repository owner, then update `DESCRIPTION`, `_pkgdown.yml` and
   `README.Rmd`.
5. Deploy the pkgdown site from the repository.
6. Run the validation scripts in `inst/scripts/` once, with network access,
   and commit their output under `inst/validation/`. They take roughly half
   an hour in total.

The maintainer submits to CRAN; this package does not do that.

## What this package does not claim

The estimators recover known effects on simulated data and match reference
implementations on shared examples. That is a statement about the code, not
about stop and search. No result in the documentation is a finding about any
police force: the specifications shown are the package's own, the sample panel
is two forces over two years, and every estimate carries the identifying
assumption it depends on. The limits that apply to all of it, recording
practice, anonymised locations, and the fact that police send officers where
crime has risen, are set out in `inst/NOTES/methods.md`.

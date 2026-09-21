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
access (`test-report.R`). All four validation scripts have been run and their
output is committed under `inst/validation/`, described in
`inst/validation/README.md`. Check is clean; lintr, spelling and styler are
clean.

## Checks

* `R CMD check --as-cran`: 0 errors, 0 warnings, 1 note on R 4.5.2,
  Windows, run on 2026-09-21 with `_R_CHECK_CRAN_INCOMING_` and
  `_R_CHECK_CRAN_INCOMING_REMOTE_` both `true`, so CRAN's own incoming,
  URL and DOI checks ran. The note is "New submission" plus the three
  repository URLs, which return 404 until the repository is published.
  Everything else `urlchecker::url_check()` looks at passes.
* Test coverage: 92.36 percent (`covr`, 2026-09-21), against the 85 percent
  the specification requires. The thinnest files are `R/utils-http.R` at
  61 percent and `R/utils-zip.R` at 68 percent, both of which are the
  network and zip plumbing whose failure paths are hard to reach offline.
* Tests: 1,190 passing, 0 failures, 0 errors, 0 warnings, 0 skipped
  (2026-09-21, `NOT_CRAN=true`). Heavy
  estimator studies are behind `skip_on_cran()`.
* lintr, spelling and styler: clean.
* Examples: each under five seconds.
* No network in examples, tests or vignettes; vignettes precomputed.

## What validation showed, including the awkward parts

`inst/validation/README.md` has the detail. Three things belong here because
they qualify what the package should be used for:

* **Ignoring displacement costs nearly half the effect.** In the spillover
  design, a two-way fixed effects model that leaves out the neighbour term is
  biased by +0.104 on a true -0.228, and its interval covers the truth in
  none of 200 replications. `lamp_spillover()` recovers both parts.
* **`lamp_elasticity()` is slightly conservative, and its intervals are too
  narrow.** Over 200 replications it is biased towards zero by about 0.005 on
  a target near -0.22, and covers the truth 66 to 70 percent of the time
  rather than 95. The cause is its response: `log(1 + a noisy count)` rather
  than the log mean. This is a property of the estimator, documented, not a
  defect to be fixed before release.
* **The simulator cannot show heterogeneity bias.** Every treated area gets
  the same effect, so the study cannot demonstrate why two-way fixed effects
  are unsafe under staggered adoption. The row labelled `lamp_twfe (wrong
  here)` is close to the truth for that reason alone.

## Still to do before submission

These need the repository and a maintainer decision, and are outside what
could be done here:

1. **Create `https://github.com/Mustapha-Wasseja/streetlamp` and push.**
   This is the only thing between the package and a clean CRAN incoming
   check: the three URLs in `DESCRIPTION` return 404 until it exists, and
   the check names all three. Creating it also lets the continuous
   integration matrix (Ubuntu, macOS and Windows, on release, devel and
   oldrel-1) run, and gives the pkgdown site somewhere to deploy. The
   workflows are written and committed. The repository owner was settled on
   2026-09-21: the maintainer's own account, movable to a Black Thrive
   Global organisation later. Black Thrive Global remains the copyright
   holder in `DESCRIPTION`.
2. Publish the pkgdown site from that repository, which clears the third
   URL.
3. Run rhub and win-builder on devel and release, and record the results in
   `cran-comments.md`. Nothing has run anywhere but this Windows machine on
   R 4.5.2.
4. Delete the comment at the top of `cran-comments.md` once 1 to 3 hold.

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

# Release readiness: streetlamp 0.1.0

Evidence that the package meets the acceptance criteria in the build
specification. Written at the end of milestone M5; see
`inst/NOTES/progress.md` for the session-by-session record and
`inst/NOTES/decisions.md` for every choice made without the maintainer.

## Milestones

| Milestone | Content | Status |
|----|----|----|
| M0 | Skeleton, licence, continuous integration, testthat, pkgdown, lintr; bundled shocks, bank holidays, crime and outcome classifications, LSOA code lists | Complete |
| M1 | Archive acquisition and versioning; readers for crime, outcomes and stop counts; the panel contract | Complete |
| M2 | Boundaries, adjacency, population, re-vintaging, the area-by-month panel, the coverage audit | Complete |
| M3 | Treatment definitions, surge detection, two-way fixed effects, event study, pre-trends, placebo tests, simulator | Complete |
| M4 | Staggered difference-in-differences, synthetic control, spillovers and displacement, elasticities, allocation, crimes prevented | Complete |
| M5 | Reporting, methods notes, validation scripts, release documents | Complete |

## Acceptance criteria, milestone by milestone

**M1.** Fixture-backed tests pass offline against two bundled archive
snapshots. Both sample forces read end to end. A force-month present in
two snapshots with different content is reported by
[`lamp_version_diff()`](https://blackthrive.github.io/streetlamp/reference/lamp_version_diff.md)
and one version is selected and recorded in the contract. Anti-social
behaviour rows carry no crime identifier and are flagged
(`test-read-crime.R`).

**M2.** The panel holds `NA`, never zero, for force-months with no file
(`test-panel.R`). Re-vintaging from 2011 to 2021 LSOAs is recorded in
the contract with the split and merge shares (`test-geography.R`,
`test-panel.R`). The coverage heat map renders, and the
mismatched-file-type flag fires on the real gap in the bundled sample,
where Dyfed-Powys submitted crime files but no stop-and-search files
from December 2025 (`test-coverage.R`, `test-sample.R`).

**M3.**
[`lamp_twfe()`](https://blackthrive.github.io/streetlamp/reference/lamp_twfe.md)
matches `fixest` called directly, to machine precision (`test-twfe.R`).
The simulated event design is recovered, and intervals cover the truth
at roughly the nominal rate over replications.
[`lamp_event_study()`](https://blackthrive.github.io/streetlamp/reference/lamp_event_study.md)
refuses plain two-way fixed effects under staggered adoption and names
the estimator that replaces it (`test-eventstudy.R`).

**M4.**
[`lamp_did_staggered()`](https://blackthrive.github.io/streetlamp/reference/lamp_did_staggered.md)
matches
[`did::att_gt()`](https://bcallaway11.github.io/did/reference/att_gt.html)
on the `did` package’s own example data, to machine precision, for both
the overall effect and the group-time table (`test-staggered.R`). The
spillover design recovers own and neighbour effects and their net, and a
two-way fixed effects model omitting the spillover term is shown to be
biased toward zero (`test-spillover.R`). The common correlated effects
mean group estimator matches a hand-computed two-area example,
coefficient by coefficient and in its standard error
(`test-elasticity.R`). The weighted displacement quotient reproduces a
hand-computed value of exactly -1 on constructed totals
(`test-spillover.R`).
[`lamp_crimes_prevented()`](https://blackthrive.github.io/streetlamp/reference/lamp_crimes_prevented.md)
returns its assumption chain and prints it (`test-elasticity.R`).
Vignettes 2 to 4 render.

**M5.**
[`lamp_report()`](https://blackthrive.github.io/streetlamp/reference/lamp_report.md)
runs end to end on the bundled panel with no network access
(`test-report.R`). All four validation scripts have been run and their
output is committed under `inst/validation/`, described in
`inst/validation/README.md`. Check is clean; lintr, spelling and styler
are clean.

## Checks

- `R CMD check --as-cran`: 0 errors, 0 warnings, 1 note on R 4.5.2,
  Windows, run on 2026-09-23 with `_R_CHECK_CRAN_INCOMING_` and
  `_R_CHECK_CRAN_INCOMING_REMOTE_` both `true`, so CRAN’s own incoming,
  URL and DOI checks ran. The note is “New submission” and nothing else.
  Every URL in the package resolves.
- The continuous integration matrix is green: Ubuntu, macOS and Windows
  on R release and oldrel-1, and R devel on Ubuntu and Windows. macOS on
  R devel is `continue-on-error`, because CRAN ships no macOS binaries
  for R devel and `sf` and `spdep` cannot build from source on the
  runner; CRAN’s own macOS builders are release and oldrel, both of
  which pass.
- Test coverage: 92.36 percent (`covr`, 2026-09-21), against the 85
  percent the specification requires. The thinnest files are
  `R/utils-http.R` at 61 percent and `R/utils-zip.R` at 68 percent, both
  of which are the network and zip plumbing whose failure paths are hard
  to reach offline.
- Tests: 1,195 passing, 0 failures, 0 errors, 0 warnings, 0 skipped
  (2026-09-21, `NOT_CRAN=true`). Heavy estimator studies are behind
  `skip_on_cran()`.
- lintr, spelling and styler: clean.
- Examples: each under five seconds.
- No network in examples, tests or vignettes; vignettes precomputed.

## What validation showed, including the awkward parts

`inst/validation/README.md` has the detail. Three things belong here
because they qualify what the package should be used for:

- **Ignoring displacement costs nearly half the effect.** In the
  spillover design, a two-way fixed effects model that leaves out the
  neighbour term is biased by +0.104 on a true -0.228, and its interval
  covers the truth in none of 200 replications.
  [`lamp_spillover()`](https://blackthrive.github.io/streetlamp/reference/lamp_spillover.md)
  recovers both parts.
- **[`lamp_elasticity()`](https://blackthrive.github.io/streetlamp/reference/lamp_elasticity.md)
  is slightly conservative, and its intervals are too narrow.** Over 200
  replications it is biased towards zero by about 0.005 on a target near
  -0.22, and covers the truth 66 to 70 percent of the time rather
  than 95. The cause is its response: `log(1 + a noisy count)` rather
  than the log mean. This is a property of the estimator, documented,
  not a defect to be fixed before release.
- **The simulator cannot show heterogeneity bias.** Every treated area
  gets the same effect, so the study cannot demonstrate why two-way
  fixed effects are unsafe under staggered adoption. The row labelled
  `lamp_twfe (wrong here)` is close to the truth for that reason alone.
- **A national panel is a 7.5 GB download and a 9 GB peak in memory.**
  The benchmark built one: 36 months, all 45 forces, 17.8 million
  records over 35,672 LSOAs, 68 minutes end to end, two thirds of it
  downloading. Estimation afterwards is cheap, 12 seconds for a Poisson
  model over 1.28 million area-months. A machine with less than 16 GB
  should build the panel a few forces at a time.

## Still to do before submission

1.  Run rhub, then record the result in `cran-comments.md` and delete
    the comment at the top of it. It is the only check that has not run.
    win-builder came back clean on 2026-09-24, on R 4.6.1 and on R devel
    (2026-09-21 r90579): one note on each, identical, “New submission”
    plus two words in `DESCRIPTION` that a spell checker does not know
    (`elasticities`, and `pre` from `pre-trend` split at the hyphen).
2.  Submit. The maintainer does that; this package does not.

Done on 2026-09-23: the repository exists at
`https://github.com/BlackThrive/streetlamp` with the nine-configuration
check matrix running on every push, the pkgdown site is published at
`https://blackthrive.github.io/streetlamp/`, and the incoming check’s
note is down to “New submission”.

## What this package does not claim

The estimators recover known effects on simulated data and match
reference implementations on shared examples. That is a statement about
the code, not about stop and search. No result in the documentation is a
finding about any police force: the specifications shown are the
package’s own, the sample panel is two forces over two years, and every
estimate carries the identifying assumption it depends on. The limits
that apply to all of it, recording practice, anonymised locations, and
the fact that police send officers where crime has risen, are set out in
`inst/NOTES/methods.md`.

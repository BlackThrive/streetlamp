<!--
Not submitted yet. One thing below is still ahead of the evidence: neither
win-builder nor rhub has run. Everything else in this file is a result that
has actually happened. Delete this comment once they have.
-->

## R CMD check results

0 errors, 0 warnings, 1 note. The note is the usual one for a first
submission:

```
* checking CRAN incoming feasibility ... NOTE
Maintainer: 'Mustapha Wasseja <muswaseja@gmail.com>'

New submission
```

The local check ran with `_R_CHECK_CRAN_INCOMING_` and
`_R_CHECK_CRAN_INCOMING_REMOTE_` both set to `true`, so the URL and DOI
checks ran. Every URL in the package resolves.

## Test environments

Checked on 2026-09-23, all with 0 errors and 0 warnings:

* local: Windows 11, R 4.5.2
* GitHub Actions: ubuntu-latest, macOS-latest and windows-latest, on R
  release and R oldrel-1; and R devel on ubuntu-latest and windows-latest

macOS on R devel is the one configuration that does not run. It fails before
reaching this package: there are no CRAN macOS binaries for R devel, so `sf`
and `spdep` would have to build from source against GDAL, GEOS and PROJ,
which the runner does not carry. macOS release and oldrel-1 both pass.

Still to run: win-builder (devel and release) and rhub.

## Notes for the reviewer

* This is a first submission.
* No example, test or vignette uses the network. Every network function is
  guarded by the `STREETLAMP_OFFLINE` environment variable, which the
  continuous integration workflows set, and falls back to a cached copy with
  a classed warning when a source is unreachable. Vignettes are precomputed
  from `.Rmd.orig` sources, so no code runs at build time.
* Downloads are cached in `tools::R_user_dir("streetlamp", "cache")` only,
  and never at load, check or test time. Tests write to
  `withr::local_tempdir()`.
* The bundled data are aggregated counts and small reference tables, not
  personal records. Two miniature archive zips hold anonymised
  published records so that the readers can be tested offline; they
  contain no personal data. Everything derives from data.police.uk, the
  Office for National Statistics, NOMIS, GOV.UK and the Welsh Government
  under the Open Government Licence v3.0, and is attributed in
  `inst/extdata/README.md`.
* The heavier estimators (`did`, synthetic control permutations, the
  common correlated effects mean group estimator) are exercised on tiny
  simulated panels in the routine tests; the full recovery and coverage
  studies are behind `skip_on_cran()`.
* `inst/validation/` holds the output of the validation scripts in
  `inst/scripts/`. Those scripts need the network and are never run at check
  time; the committed results are evidence, described in
  `inst/validation/README.md`.

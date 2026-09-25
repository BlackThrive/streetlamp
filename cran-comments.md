<!--
Not submitted yet. win-builder R devel is confirmed on this tree; the R
release run of the same tree has been processed but its log has not been
read. Read it, and delete this comment.
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

win-builder adds two possibly misspelled words in `DESCRIPTION`. Both are
spelled as intended:

* **elasticities** is the standard term for what the package estimates: the
  proportional response of recorded crime to a proportional change in
  searches.
* **pre** is the first half of **pre-trend**, which the spell checker splits
  at the hyphen. A pre-trend is the movement in the outcome before an
  intervention, and testing for one is a standard part of a
  difference-in-differences design.

## Test environments

Checked on 2026-09-23 and 2026-09-24, all with 0 errors and 0 warnings:

* local: Windows 11, R 4.5.2
* win-builder, R devel (2026-09-21 r90579): 1 note, the one above. Examples
  26 s, tests 67 s, vignettes and both manuals OK. R 4.6.1 (release) returned
  the same single note on an earlier tree; the release run of this tree is
  still to be read.
* GitHub Actions: ubuntu-latest, macOS-latest and windows-latest, on R
  release and R oldrel-1; and R devel on ubuntu-latest and windows-latest
* R-hub v2: `linux` and `windows` on R devel, and the `donttest`, `atlas` and
  `mkl` containers, all clean; `nosuggests` and `macos` are discussed below.
  `atlas` and `mkl` were included deliberately:
  the package has no compiled code, but it does sum through BLAS in Pesaran's
  CD test, and those two are where an alternative BLAS would show up.

macOS on R devel does not run, on either system, and in both cases it fails
before reaching this package. There are no CRAN macOS binaries for R devel,
so `sf`'s compiled dependency chain has to build from source: on GitHub
Actions the runner has no GDAL, GEOS or PROJ and dependency setup gives up;
on R-hub, `s2` spent eleven minutes compiling abseil-cpp and then failed.
macOS release and oldrel-1 both pass on GitHub Actions, and those are the
versions CRAN's own macOS builders use.

R-hub's `nosuggests` container reports one ERROR, in re-building the
vignettes: `there is no package called 'rmarkdown'`. Examples and tests both
pass there, which is the part that matters, so nothing in the package's code
needs a suggested package without checking for it first. The vignettes are
`.Rmd` and their engine is `knitr::rmarkdown`, so rebuilding them without
`rmarkdown` installed cannot work, for this or any package built the same
way.

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

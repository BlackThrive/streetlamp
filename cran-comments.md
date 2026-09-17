## R CMD check results

`R CMD check --as-cran` gives 0 errors, 0 warnings, 0 notes locally on
R 4.5.2, Windows.

## Test environments

To be completed before submission:

* local: Windows 11, R 4.5.2
* GitHub Actions: ubuntu-latest, macOS-latest, windows-latest, each on
  R release, R devel and R oldrel-1
* win-builder: devel and release
* rhub

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

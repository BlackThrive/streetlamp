## R CMD check results

0 errors | 0 warnings | 1 note

```
* checking CRAN incoming feasibility ... NOTE
Maintainer: 'Mustapha Wasseja <muswaseja@gmail.com>'

New submission

Possibly misspelled words in DESCRIPTION:
  elasticities (17:16)
  pre (20:23)
```

* This is a first submission: no version of the package has been on CRAN.
* Both flagged words are spelled as intended. **elasticities** is the
  standard term for what the package estimates, the proportional response of
  recorded crime to a proportional change in searches. **pre** is the first
  half of **pre-trend**, which the spell checker splits at the hyphen: the
  movement in an outcome before an intervention, which a
  difference-in-differences design tests for.

## Test environments

* win-builder: R devel (2026-10-13 r90668) and R 4.6.1. The note above on
  each, identical, and nothing else. Examples 27 to 29 s, tests 69 to 71 s.
* local: Windows 11, R 4.5.2, with `_R_CHECK_CRAN_INCOMING_` and
  `_R_CHECK_CRAN_INCOMING_REMOTE_` both set to `true`, so the URL and DOI
  checks ran. Every URL in the package resolves.
* GitHub Actions: ubuntu-latest, macOS-latest and windows-latest on R release
  and R oldrel-1, and R devel on ubuntu-latest and windows-latest. All pass.
* R-hub v2: `linux`, `windows` and `macos` on R devel, and the `donttest`,
  `atlas` and `mkl` containers. All pass. `atlas` and `mkl` were included
  although the package has no compiled code, because it sums through BLAS in
  Pesaran's CD test, where a reference and an optimised implementation
  reassociate differently.

Two configurations do not pass, neither for a reason in this package:

* GitHub Actions on macOS with R devel fails while installing dependencies.
  There are no CRAN macOS binaries for R devel, so `sf`'s compiled dependency
  chain has to build from source and the runner lacks GDAL, GEOS and PROJ.
  R-hub's macOS R devel image passes, as do macOS release and oldrel-1.
* R-hub's `nosuggests` container fails in re-building the vignettes, with
  `there is no package called 'rmarkdown'`. Examples and tests both pass
  there, so no code in the package reaches for a suggested package without
  checking first. The vignettes use `knitr::rmarkdown` as their engine and
  cannot be rebuilt without it.

## Notes for the reviewer

* No example, test or vignette uses the network. Every network function is
  guarded by the `STREETLAMP_OFFLINE` environment variable, which the
  continuous integration workflows set, and falls back to a cached copy with
  a classed warning when a source is unreachable. Vignettes are precomputed
  from `.Rmd.orig` sources, so no code runs at build time.
* Downloads are cached in `tools::R_user_dir("streetlamp", "cache")` only,
  and never at load, check or test time. Tests write to
  `withr::local_tempdir()`.
* The bundled data are aggregated counts and small reference tables, not
  personal records. Two miniature archive zips hold anonymised published
  records so that the readers can be tested offline; they contain no personal
  data. Everything derives from data.police.uk, the Office for National
  Statistics, NOMIS, GOV.UK and the Welsh Government under the Open
  Government Licence v3.0, and is attributed in `inst/extdata/README.md`.
* The heavier estimators (`did`, synthetic control permutations, the common
  correlated effects mean group estimator) are exercised on tiny simulated
  panels in the routine tests. The full recovery and coverage studies, and
  the visual regression tests, are behind `skip_on_cran()`.
* The `lamp_did_staggered()` example has occasionally exceeded five seconds
  of elapsed time on a loaded machine, though never on win-builder. Nearly
  all of it is the first load of the `did` package; the fit itself takes
  under half a second.
* `inst/validation/` holds the output of the validation scripts in
  `inst/scripts/`, described in `inst/validation/README.md` and
  `inst/validation/research-upgrade/README.md`. Those scripts need the network
  and never run at check time. The per-replication data behind the summaries
  is in the public repository but excluded from the tarball, which keeps the
  installed size near 4 MB.

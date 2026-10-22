## Resubmission

This is a resubmission. Following the review of 0.2.0, this version:

* Links every web service the package uses in the Description field, in
  angle brackets: the data.police.uk archive and change log, the Office for
  National Statistics Open Geography Portal, and the 'Nomis' API.
* Replaces the five examples that were wrapped in `if (FALSE) {}`, in
  `lamp_archive_index()`, `lamp_archive_download()`, `lamp_changelog()`,
  `lamp_boundaries()` and `lamp_population()`. These are the functions that
  download data. Their examples now run inside `\donttest{}`, fetch little
  (the largest is one month of files for one police force), write only to
  `tempdir()`, and print a message instead of failing when the network is
  unavailable.
* No longer writes to the user's file space by default. The download cache
  used to default to `tools::R_user_dir("streetlamp", "cache")`; it now
  defaults to a directory inside `tempdir()`, and a persistent location is
  used only when the user sets the `streetlamp.cache_dir` option or the
  `STREETLAMP_CACHE_DIR` environment variable. `lamp_report()`, the one
  function that writes a file the user asks for, writes to `tempfile()`
  unless given a path. Examples, vignettes and tests write only to
  `tempdir()`.

## R CMD check results

0 errors | 0 warnings | 1 note

```
* checking CRAN incoming feasibility ... NOTE
Maintainer: 'Mustapha Wasseja <muswaseja@gmail.com>'

New submission

Possibly misspelled words in DESCRIPTION:
  elasticities (18:16)
  pre (26:23)
```

* This is a first submission: no version of the package has been on CRAN.
* Both flagged words are spelled as intended. **elasticities** is the
  standard term for what the package estimates, the proportional response of
  recorded crime to a proportional change in searches. **pre** is the first
  half of **pre-trend**, which the spell checker splits at the hyphen: the
  movement in an outcome before an intervention, which a
  difference-in-differences design tests for.

## Test environments

* local, this version: Windows 11, R 4.5.2, `--as-cran` with the network
  on, so the five `\donttest{}` examples downloaded for real (83 s in all),
  and with `_R_CHECK_CRAN_INCOMING_REMOTE_` set to `true`, so the URL checks
  ran. Every URL in the package resolves, including the new ones in the
  Description. The same examples were also run offline, where each prints
  its message and continues.
* GitHub Actions, this version: ubuntu-latest, macOS-latest and
  windows-latest on R release and R oldrel-1, and R devel on ubuntu-latest
  and windows-latest. All pass.
* win-builder, this version: R devel (2026-10-21 r90733). The note above,
  and nothing else.
* win-builder, first submission: R devel (2026-10-13 r90668) and R 4.6.1.
  The same note on each, and nothing else.
* R-hub v2, first submission: `linux`, `windows` and `macos` on R devel,
  and the `donttest`, `atlas` and `mkl` containers. All pass. `atlas` and
  `mkl` were included although the package has no compiled code, because it
  sums through BLAS in Pesaran's CD test, where a reference and an optimised
  implementation reassociate differently.

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

* No test or vignette uses the network; only the five `\donttest{}`
  examples above do. When a source is unreachable, every network function
  falls back to a cached copy with a classed warning, or raises a classed
  error with an informative message when there is none, which those examples
  catch. Setting the `STREETLAMP_OFFLINE` environment variable makes every
  network call fail at once; the continuous integration workflows set it.
  Vignettes are precomputed from `.Rmd.orig` sources, so no code runs at
  build time.
* Tests write to `withr::local_tempdir()`.
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
  `inst/validation/research-upgrade/README.md`. They are development scripts,
  run by hand from a clone of the repository; they need the network and never
  run at check time. The per-replication data behind the summaries
  is in the public repository but excluded from the tarball, which keeps the
  installed size near 4 MB.

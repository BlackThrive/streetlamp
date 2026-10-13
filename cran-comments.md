<!--
Not submitted yet. Two things to do first, both tracked in RELEASE_READY.md:

  1. Run win-builder on devel and release, and R-hub, against this tree, and
     replace the entries below. The recorded runs are from before the research
     upgrade, lamp_map() and the build-size change, so they describe a
     different package.
  2. Settle the repository history question: the pre-rewrite commits are
     still fetchable by SHA.

Delete this comment when both hold.
-->

## R CMD check results

0 errors, 0 warnings, 1 note:

```
* checking CRAN incoming feasibility ... NOTE
Maintainer: 'Mustapha Wasseja <muswaseja@gmail.com>'

New submission
```

This is a first submission: no version of the package has been on CRAN. The
check ran with `_R_CHECK_CRAN_INCOMING_` and
`_R_CHECK_CRAN_INCOMING_REMOTE_` both set to `true`, so the URL and DOI
checks ran, and every URL in the package resolves.

Earlier win-builder runs reported two possibly misspelled words in
`DESCRIPTION`. Both are spelled as intended:

* **elasticities** is the standard term for what the package estimates: the
  proportional response of recorded crime to a proportional change in
  searches.
* **pre** is the first half of **pre-trend**, which the spell checker splits
  at the hyphen. A pre-trend is the movement in the outcome before an
  intervention, and testing for one is a standard part of a
  difference-in-differences design.

## Test environments

* local: Windows 11, R 4.5.2. 0 errors, 0 warnings, 2 notes.
* GitHub Actions: ubuntu-latest, macOS-latest and windows-latest on R release
  and R oldrel-1, and R devel on ubuntu-latest and windows-latest. All pass.
* R-hub v2: `linux` and `windows` on R devel, and the `donttest`, `atlas` and
  `mkl` containers. All clean. `atlas` and `mkl` were included although the
  package has no compiled code, because it sums through BLAS in Pesaran's CD
  test and a reference implementation and an optimised one reassociate
  differently.
* win-builder, devel and release: submitted against this tree; results
  pending.

macOS on R devel is the one configuration that does not run, and it fails
before reaching this package. CRAN publishes no macOS binaries for R devel, so
`sf`'s compiled dependency chain must build from source, and the runner has
neither the system libraries nor, on R-hub, time enough to compile
abseil-cpp. macOS release and oldrel-1 both pass, and those are the versions
CRAN's own macOS builders use.

R-hub's `nosuggests` container reports one ERROR, in re-building the
vignettes: `there is no package called 'rmarkdown'`. Examples and tests both
pass there, so no code in the package reaches for a suggested package without
checking for it first. The vignettes are `.Rmd` with `knitr::rmarkdown` as
their engine, so rebuilding them without `rmarkdown` installed cannot work,
for this package or any other built the same way.

The second note is `lamp_did_staggered`, at 3.9 seconds of processor time and
6.1 elapsed. Almost all of it is loading the `did` package, which whichever
example reaches it first has to pay; the fit itself is under half a second and
a second call in the same session takes 0.4.

Still to record on this tree: the two win-builder results.

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
* `inst/validation/` holds the output of the validation scripts in
  `inst/scripts/`, described in `inst/validation/README.md` and
  `inst/validation/research-upgrade/README.md`. Those scripts need the network
  and never run at check time. The per-replication data behind the summaries
  is in the public repository but excluded from the tarball, which keeps the
  installed size near 4 MB.

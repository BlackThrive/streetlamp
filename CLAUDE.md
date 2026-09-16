# streetlamp: build specification for a coding agent

Save this file as `CLAUDE.md` (Claude Code) or `AGENTS.md` (Codex) at the root of an empty repository named `streetlamp`. Read it in full before writing any code. Every section is a requirement unless marked "optional".

---

## 1. What this package is

`streetlamp` is an R package for estimating the effects of police stop and search activity on recorded crime in England and Wales, published by Black Thrive Global (BTG). It builds an area-by-month panel of recorded crime from the data.police.uk archive, attaches stop and search intensity as a treatment variable, and provides a panel-econometrics toolkit for evaluating policing interventions: event studies, difference-in-differences with staggered adoption, synthetic control, spatial spillover and displacement models, and stop-crime elasticities by offence type.

`streetlamp` is about what stops achieve, not who is stopped. It uses the street-level crime and outcomes files and causal panel econometrics.

### Scope boundary

- `streetlamp` never computes an ethnic disparity measure. It does not map ethnicity codes.
- `streetlamp` reads stop-and-search CSVs only to count stops by area and month. It does not parse ethnicity, object, outcome or legislation fields beyond a legislation flag for Section 60.
- `streetlamp` is fully standalone with no dependency on any other stop and search package. A user may supply externally computed stop counts through a plain tibble interface (section 2.2).

### Independence constraint (non-negotiable)

Original work only. Do not read, copy or adapt code from `policedatR`, `ExtractSS`, `ukpolice`, `crimedata`, or `crimemappingdata`. Do not add them as dependencies. Published papers (section 13) may be cited for method context; their replication code must not be consulted.

### Design principles

- Acquisition is via the bulk archive. Geography comes from the LSOA code already present in the crime files, cross-checked and re-vintaged locally; no per-polygon API calls.
- Every panel carries a **panel contract** (section 4) recording provenance, coverage, LSOA vintage and treatment definition. Estimators read it and refuse or warn when assumptions are violated.
- "Force did not submit" is never a zero.
- Anti-social behaviour is not a crime, has no Crime ID and no outcome; it is kept in a separate series and excluded from crime totals by default.
- Treatment effects are reported with the identifying assumption named in the output object, and every estimator ships with a placebo or pre-trend diagnostic.
- No network access during `R CMD check`, tests or examples.

---

## 2. Data sources (verify every URL, file layout and column before use)

Record what was verified, and when, in `inst/NOTES/data_sources.md`.

### 2.1 Recorded crime and outcomes: data.police.uk archive

- Archive index: https://data.police.uk/data/archive/ . Each archive zip holds monthly folders with, per force, `YYYY-MM-<force>-street.csv`, `YYYY-MM-<force>-outcomes.csv`, and `YYYY-MM-<force>-stop-and-search.csv`. Confirm the layout and how far back street files exist (December 2010 is the published start; verify).
- About page and anonymisation: https://data.police.uk/about/ . Crime locations are snapped to a fixed set of anonymised points; the `LSOA code` field is supplied by the publisher. Verify which LSOA vintage the publisher uses (historically 2011). If 2011, bundle the ONS LSOA 2011 to 2021 best-fit lookup and provide both.
- Changelog: https://data.police.uk/changelog/ .
- Expected street CSV columns (verify): Crime ID, Month, Reported by, Falls within, Longitude, Latitude, Location, LSOA code, LSOA name, Crime type, Last outcome category, Context.
- Expected outcomes CSV columns (verify): Crime ID, Month, Reported by, Falls within, Longitude, Latitude, Location, LSOA code, LSOA name, Outcome type.
- Crime type categories (verify the current list; the published set is fourteen): anti-social behaviour, bicycle theft, burglary, criminal damage and arson, drugs, other crime, other theft, possession of weapons, public order, robbery, shoplifting, theft from the person, vehicle crime, violence and sexual offences.
- Note `Reported by` versus `Falls within` (British Transport Police records fall within territorial force areas). Default: count by `Falls within`; expose the alternative.
- Licence: Open Government Licence v3.0. Attribute.

### 2.2 Stop counts

- From the same archive's stop-and-search CSVs. `streetlamp` reads only Date, Latitude, Longitude, Legislation and (for area assignment) coordinates. It counts stops per area-month and a Section 60 flag. Nothing else.
- Alternatively accept any user-supplied tibble with columns `area`, `month`, `stops` and optional `stops_s60` and `coverage_status`; tag it `user_supplied` in the contract.

### 2.3 Boundaries and lookups: ONS Open Geography Portal

- https://geoportal.statistics.gov.uk/ . LSOA 2011 and LSOA 2021 boundaries, LSOA 2011 to 2021 lookup, LSOA to MSOA to LAD to PFA lookups, and adjacency (queen contiguity computed locally with `spdep`).

### 2.4 Population and area characteristics

- Census 2021 usual resident population by LSOA and MSOA via NOMIS (https://www.nomisweb.co.uk/api/v01/), for exposure offsets and rates.
- English Indices of Deprivation 2025 (or latest) at LSOA (https://www.gov.uk/government/statistics/english-indices-of-deprivation-2025) and the Welsh Index of Multiple Deprivation for Wales, for covariates and heterogeneity analysis. Bundle a compact table with source and retrieval date; do not download at runtime.

### 2.5 Known national shocks (bundled table, `inst/extdata/shocks.csv`)

Bundle a curated table of dated policy events with sources, for use as default intervention definitions: Best Use of Stop and Search Scheme (2014), the 2019 relaxation of Section 60 authorisation conditions, COVID-19 lockdown periods (2020 to 2021), and any subsequent national policy changes you verify. Each row: name, start, end (NA if none), scope (national, force list), source URL, notes.

### 2.6 Astronomical and calendar data

- Bank holidays (bundled table from gov.uk), UK daylight saving transitions, and month lengths, for seasonality controls.

---

## 3. Package skeleton

```
streetlamp/
  DESCRIPTION, NAMESPACE, LICENSE, LICENSE.md, NEWS.md, README.Rmd
  R/
    lamp-package.R
    ingest-archive.R       lamp_archive_index(), lamp_archive_download(), lamp_archive_snapshot()
    ingest-versions.R      lamp_list_versions(), lamp_select_version()
    ingest-crime.R         lamp_read_crime(), lamp_read_outcomes()
    ingest-stops.R         lamp_read_stop_counts()
    ingest-geography.R     lamp_lsoa_vintage(), lamp_boundaries(), lamp_adjacency()
    ingest-population.R    lamp_population()
    panel-build.R          lamp_panel()
    panel-contract.R       lamp_contract(), print/summary, validators
    audit-coverage.R       lamp_coverage(), lamp_coverage_compare()
    treatment-define.R     lamp_treatment(), lamp_detect_surges(), lamp_shocks()
    est-twfe.R             lamp_twfe()
    est-eventstudy.R       lamp_event_study()
    est-staggered.R        lamp_did_staggered()
    est-synth.R            lamp_synth()
    est-spillover.R        lamp_spillover(), lamp_displacement_quotient()
    est-elasticity.R       lamp_elasticity()
    est-allocation.R       lamp_allocation()
    est-costbenefit.R      lamp_crimes_prevented()
    diag-pretrends.R       lamp_pretrends(), lamp_placebo()
    report.R               lamp_report()
    simulate.R             lamp_simulate()
    cache.R                lamp_cache_dir(), lamp_cache_clear()
    classifications.R      crime type groupings, outcome groupings
    utils-*.R
  inst/extdata/            bundled sample panel, shocks table, bank holidays, IoD extract, LSOA lookup extract
  inst/templates/          report template
  inst/scripts/            validation and benchmark scripts
  inst/NOTES/
  tests/testthat/
  vignettes/
  data-raw/
  .github/workflows/
  _pkgdown.yml
```

Function prefix: `lamp_`. Every exported function has roxygen documentation and `@examples` that run on the bundled sample without network.

---

## 4. The panel contract

Every panel is a tibble of class `c("lamp_panel", "tbl_df", "tbl", "data.frame")` with attribute `contract` (class `lamp_contract`), a named list with at least:

| Field | Content |
|---|---|
| `source` | "data.police.uk archive" |
| `snapshots` | archive file, sha256, download timestamp, URL |
| `versions` | per force-month: archive selected, alternatives seen, selection rule |
| `coverage` | per force-month and file type (street, outcomes, stop-and-search): status in {`submitted`, `missing`, `refreshed`, `partial_suspected`}, n_records, changelog note |
| `geography` | area type (lsoa11, lsoa21, msoa21, lad, pfa), LSOA vintage of the source, lookup used, boundary vintage, adjacency method |
| `population` | NOMIS table, Census vintage, geography, retrieval date; or `user_supplied` |
| `crime_scope` | which crime types are in `crime_total`; whether ASB is included (default FALSE); `Falls within` or `Reported by` |
| `stops` | origin (`streetlamp` own count or `user_supplied`), definition (raw count, per 1000 population, per 100 prior-year crimes) |
| `treatment` | definition object from `lamp_treatment()` (section 7), or NULL |
| `created` | timestamp, package version, R version |

Requirements: `lamp_contract(x)` returns it; contracts survive `dplyr` verbs and subsetting; aggregated and model outputs carry a copy; estimators check it (e.g. `lamp_did_staggered()` refuses a panel whose treatment is undefined; every estimator drops force-months with status `missing` and reports the count; `lamp_spillover()` requires adjacency to be present).

---

## 5. Layer 1: ingest, panel, audit

### 5.1 Archive acquisition and versioning

`lamp_archive_index()`, `lamp_archive_download(months, forces, dir)`, `lamp_archive_snapshot(dir)`, `lamp_list_versions()`, `lamp_select_version(rule = "latest")`. Never deduplicate rows across archive versions; select one version per force-month per file type and record alternatives. Cache under `tools::R_user_dir("streetlamp", "cache")`.

### 5.2 Reading

- `lamp_read_crime(dir, versions)`: fixed schema, snake_case, `month` as Date (first of month), `force_id` from filename, `crime_type` as factor with the verified level set, `is_asb` flag, `lsoa_code` retained as supplied plus `lsoa_vintage`. Missing coordinates retained. Keep `crime_id` (may be NA for ASB).
- `lamp_read_outcomes(dir, versions)`: same conventions; `outcome_type` factor; outcome grouping into `charged_or_summonsed`, `out_of_court`, `no_suspect`, `evidential_difficulties`, `other`, `unknown` (verify categories).
- `lamp_read_stop_counts(dir, versions, area = "lsoa21")`: reads stop-and-search CSVs, assigns area by point-in-polygon in EPSG:27700, returns area-month counts with `stops` and `stops_s60`. No other fields.

### 5.3 Geography

- `lamp_lsoa_vintage(records)`: detect whether supplied LSOA codes are 2011 or 2021 by matching against bundled code lists; write to contract.
- `lamp_boundaries(type, vintage, dir)`: fetch and cache ONS boundaries as `sf`.
- `lamp_adjacency(boundaries, method = c("queen", "rook", "knn"), k = 6)`: `spdep` neighbour list and row-standardised weights; stored with the panel.
- Re-vintaging: when the source uses LSOA 2011 and the user requests LSOA 2021, apply the ONS best-fit lookup and record the share of areas that split or merged.

### 5.4 Panel construction

- `lamp_panel(crime, outcomes = NULL, stops = NULL, area = c("lsoa21", "lsoa11", "msoa21", "lad", "pfa"), population = NULL, covariates = NULL, include_asb = FALSE)`: balanced area-by-month panel with columns: `area`, `month`, `force_id`, one column per crime type, `crime_total`, `asb`, `stops`, `stops_s60`, `population`, `stop_rate` (per 1000 population), and any covariates. Zero-fill only for submitted force-months; leave `NA` for missing ones and mark `coverage_status`. Attach contract.
- `plot()` method: small-multiple time series by force with missing months shaded.

### 5.5 Coverage audit

- `lamp_coverage(panel)`: force × month × file type grid with statuses; heatmap `plot()`.
- `lamp_coverage_compare(coverage, period_a, period_b)`: comparability per force.
- The audit must flag force-months where stop-and-search files are submitted but street files are missing (or the reverse), because such months break the treatment-outcome link.

---

## 6. Treatment definitions

- `lamp_treatment(panel, type = c("continuous", "binary", "staggered", "event"), ...)` returns a `lamp_treatment` object stored in the contract. Types:
  - `continuous`: stop intensity (`stops`, `stop_rate`, or stops per 100 prior-year crimes), optionally log or inverse-hyperbolic-sine transformed.
  - `binary`: user-supplied area set and window (e.g. a surge operation).
  - `staggered`: area-level adoption dates (e.g. first month above a threshold intensity, or a user table).
  - `event`: a dated shock from `lamp_shocks()` or a user table, with an event window in months.
- `lamp_shocks()`: returns the bundled shocks table.
- `lamp_detect_surges(panel, method = c("threshold", "cusum", "breakpoints"), k = 2)`: flags area-months where stops exceed k standard deviations above the area's trailing 12-month mean, or detects regime changes with `strucchange` (in Suggests). Output is a candidate `staggered` treatment table with diagnostics; documentation warns that surges detected from the outcome-adjacent series are endogenous and should be used for exploration, not as a primary design.

---

## 7. Layer 2: estimators

Every estimator returns an object of class `c("lamp_estimate", "<estimator>")` with: point estimates, standard errors clustered at the level named in the call (default area, with force as alternative), confidence intervals, the identifying assumption as a character string, sample counts after each exclusion step, and a `diagnostics` list. All have `print()`, `summary()`, `tidy()` (via `generics`), and `plot()` methods. All accept `outcome` as a crime type, `crime_total`, or a user column, and `family = c("poisson", "negbin", "ols_log", "ols_ihs")`.

### 7.1 Two-way fixed effects

- `lamp_twfe(panel, outcome, treatment, controls = NULL, cluster = "area")`: `fixest::fepois` / `feglm` / `feols` with area and month fixed effects, optional force-by-month fixed effects. Returns dispersion diagnostic and Moran's I of residuals if adjacency is present.

### 7.2 Event study

- `lamp_event_study(panel, outcome, event, window = c(-12, 12), reference = -1, cluster = "area")`: relative-time dummies via `fixest::i()`; joint pre-trend test; plot with pre and post periods shaded. For staggered adoption, this function must not use plain TWFE; it calls 7.3 internally and says so.

### 7.3 Staggered DiD

- `lamp_did_staggered(panel, outcome, treatment, estimator = c("callaway_santanna", "sun_abraham", "imputation"), control_group = c("never_treated", "not_yet_treated"), cluster = "area")`: wraps `did::att_gt` and `did::aggte`, `fixest::sunab`, and `didimputation` (Suggests). Returns group-time ATTs, dynamic aggregation, and the pre-trend diagnostic. Count outcomes are handled by log or IHS transformation with explicit warning, or by Poisson pseudo-likelihood where the backend supports it.

### 7.4 Synthetic control

- `lamp_synth(panel, outcome, treated_unit, treatment_start, donors = NULL, method = c("synth", "gsynth", "augsynth"))`: for a single treated force or area. `Synth` and `gsynth` in Imports or Suggests (both on CRAN; verify); `augsynth` is not on CRAN, so support it only via Suggests with a graceful message. In-space and in-time placebo distributions with RMSPE ratios; permutation p-value.

### 7.5 Spillovers and displacement

- `lamp_spillover(panel, outcome, treatment, adjacency, rings = 1:2, cluster = "area")`: adds neighbour-weighted treatment (first- and second-order contiguity rings) to the TWFE or DiD specification, so own-area and neighbour effects are estimated jointly. Reports the implied net effect (own plus spillover) and its interval.
- `lamp_displacement_quotient(panel, outcome, treated_areas, buffer_areas, control_areas, pre, post)`: weighted displacement quotient (Bowers and Johnson 2003) with bootstrap intervals.
- Spatial lag/error variants via `spatialreg` for cross-sectional robustness checks.

### 7.6 Stop-crime elasticity with cross-sectional dependence

- `lamp_elasticity(panel, outcome, stops, lags = 0:3, method = c("fe", "cce_mg", "cce_pooled"), cluster = "area")`: distributed-lag panel regression of log crime on log stops with area and month effects; CCE mean-group and pooled variants implemented internally (cross-sectional averages of dependent and independent variables added as regressors) to handle common shocks; CD test (Pesaran) reported. If the `dcce` package is available (Suggests), offer it as a backend.

### 7.7 Allocation model

- `lamp_allocation(panel, stops, crime_lags = 1:3, cluster = "area")`: regress stops on lagged crime with fixed effects, to characterise how police follow crime. Output is labelled as descriptive of allocation, not as a causal effect, and documentation explains why it is needed to interpret 7.1 to 7.6.

### 7.8 Crimes prevented

- `lamp_crimes_prevented(estimate, panel, per_stops = 1000)`: converts an elasticity or ATT into crimes prevented per 1000 searches at the sample mean, by crime type, with delta-method or bootstrap intervals. Reports the assumption chain in the output.

---

## 8. Diagnostics

- `lamp_pretrends(estimate)`: joint test and plot of pre-period coefficients; power calculation for detecting a linear pre-trend (Roth 2022 style, implemented directly).
- `lamp_placebo(estimate, type = c("time", "space", "outcome"), n = 200)`: placebo distributions by shifting the event date, reassigning treatment to random areas, or using a crime type not plausibly affected (bicycle theft as default placebo outcome for a weapons-focused surge, configurable).
- Every `lamp_estimate` `print()` method shows the identifying assumption, the pre-trend p-value, and the number of force-months excluded for coverage.

---

## 9. Package engineering requirements

### 9.1 DESCRIPTION

- `Package: streetlamp`, `Version: 0.1.0`, `License: MIT + file LICENSE`.
- `Authors@R`: Mustapha Wasseja (aut, cre), Black Thrive Global (cph, fnd).
- `Depends: R (>= 4.1.0)`.
- `Imports` (lean): cli, rlang, dplyr, tibble, tidyr, readr, httr2, jsonlite, sf, spdep, digest, ggplot2, fixest, did, generics, sandwich, MASS.
- `Suggests`: testthat (>= 3.0.0), httptest2, knitr, rmarkdown, withr, vdiffr, spelling, lintr, Synth, gsynth, augsynth, didimputation, strucchange, spatialreg, dcce.
- `Additional_repositories` only if any Suggests package is off-CRAN and hosted in a CRAN-like repository; otherwise document installation in the vignette.
- `URL`, `BugReports`, `Config/testthat/edition: 3`, `Encoding: UTF-8`, `Roxygen: list(markdown = TRUE)`, `VignetteBuilder: knitr`.

### 9.2 CRAN policy compliance

Each must be checked explicitly:

- No internet in tests, examples, vignettes. `httptest2` fixtures for archive, ONS and NOMIS calls; `\donttest{}` for network examples; precomputed vignettes.
- Network functions fail gracefully with a message.
- Cache only in `tools::R_user_dir("streetlamp", "cache")`; tests in `withr::local_tempdir()`.
- Examples under 5 seconds; tests at most 2 cores; heavy estimators (`did`, synthetic control permutations, CCE) tested on tiny simulated panels and full runs `skip_on_cran()`.
- Installed size under 5 MB. Bundled panel is aggregated counts, not records.
- `R CMD check --as-cran` clean on release, devel, oldrel × ubuntu, macOS, windows; rhub and win-builder before submission.
- `urlchecker`, `spelling`, `lintr` clean; `inst/WORDLIST` maintained.
- No `T`/`F`, no `library()` in functions, no `print()` for messages, options and `par()` restored with `on.exit()`.
- `cran-comments.md` written.

### 9.3 Bundled sample data

- `data-raw/sample.R` builds: (a) an aggregated LSOA 2021-by-month panel for two forces over 24 months (crime by type, ASB, stops, stops_s60, population, IoD decile), small enough for `inst/extdata`; (b) three raw force-months of street, outcomes and stop-and-search CSVs for the same forces for reader tests; (c) simplified LSOA boundaries and adjacency for those forces. OGL v3 attribution in `inst/extdata/README.md`.
- `lamp_simulate(n_areas, n_months, design = c("staggered", "event", "continuous", "spillover"), effect, spillover_effect, adoption, seed)`: exported generator with known treatment effects, known spillovers on a lattice, area and month fixed effects, and a known missingness process for force-months. Used by tests and the validation vignette.

### 9.4 Testing

- `testthat` 3e, coverage ≥ 85% enforced in CI.
- Contract propagation tests across `dplyr` verbs and subsetting.
- Known-answer tests: `lamp_twfe()` matches `fixest` called directly; `lamp_did_staggered()` matches `did::att_gt` on the `did` package's example data; `lamp_displacement_quotient()` reproduces a hand-computed WDQ; CCE mean-group estimator matches a hand-computed two-unit example.
- Recovery tests on `lamp_simulate()`: each estimator recovers the known effect within tolerance and its interval covers truth at roughly nominal rate over replications (reduced on CRAN, full in CI). Spillover design: own and neighbour effects both recovered; a TWFE that omits the spillover term is shown to be biased in the expected direction.
- Coverage-status logic tests, including the mismatched-file-type case (stops submitted, street missing).
- LSOA vintage detection and re-vintaging tests.
- Placebo tests return a null distribution centred near zero on simulated data with no effect.
- Snapshot tests for plots, skipped on CRAN.
- Offline test: all network functions return a graceful message under `httptest2::without_internet()`.

### 9.5 Documentation

- roxygen2 for everything; `@family` by layer.
- README with a quick start on the bundled panel.
- Vignettes (precomputed): (1) "From archive to audited crime panel", (2) "Evaluating a stop and search surge: event study and staggered DiD", (3) "Displacement and spillovers", (4) "Stop-crime elasticities under cross-sectional dependence", (5) "Simulation evidence: what each estimator recovers and when it fails".
- `inst/NOTES/methods.md`: model equations, identifying assumptions per estimator, and interpretation limits (allocation endogeneity, recording-practice changes, anonymised locations, ASB exclusion).
- pkgdown site via GitHub Actions; `NEWS.md`.

### 9.6 Code style and tooling

`styler` tidyverse style; `lintr` in CI; `cli` for messages; classed conditions (`streetlamp_error_contract`, `streetlamp_warning_coverage`, etc.); tibbles in and out; conventional commits; one pull request per milestone.

---

## 10. Milestones and acceptance criteria

Do not start a milestone until the previous one passes and `R CMD check` is clean.

**M0: Skeleton.** Package created, licence, CI, testthat, pkgdown, lintr; bundled shocks table, bank holidays, crime type classification, LSOA code lists load with tests. Check clean.

**M1: Ingestion and versioning.** Archive functions, `lamp_read_crime()`, `lamp_read_outcomes()`, `lamp_read_stop_counts()`, `lamp_contract()`. Acceptance: fixture-backed tests pass; the two-force sample reads end to end; a force-month present in two archives with different counts is reported and one version selected; ASB rows carry no crime_id and are flagged.

**M2: Geography, population, panel, coverage.** `lamp_lsoa_vintage()`, `lamp_boundaries()`, `lamp_adjacency()`, `lamp_population()`, `lamp_panel()`, `lamp_coverage()`, `lamp_coverage_compare()`. Acceptance: balanced panel with NA (not zero) for missing force-months; re-vintaging from LSOA 2011 to 2021 documented in the contract; coverage heatmap renders; the mismatched-file-type flag works.

**M3: Treatment definitions and TWFE/event study.** `lamp_treatment()`, `lamp_shocks()`, `lamp_detect_surges()`, `lamp_twfe()`, `lamp_event_study()`, `lamp_pretrends()`, `lamp_placebo()`, `lamp_simulate()`. Acceptance: known-answer test against `fixest`; recovery on simulated event design; event study refuses plain TWFE under staggered adoption.

**M4: Staggered DiD, synthetic control, spillovers, elasticity, allocation, crimes prevented.** All of section 7.3 to 7.8. Acceptance: known-answer test against `did`; spillover recovery test including the biased-TWFE demonstration; CCE known-answer test; crimes-prevented output carries the assumption chain; vignettes 2 to 4 render.

**M5: Reporting and release.** `lamp_report()`; validation scripts run once with outputs under `inst/validation/`; full check matrix, rhub, win-builder clean; coverage ≥ 85%; `urlchecker`, `spelling`, `lintr` clean; `cran-comments.md`, `NEWS.md`; pkgdown deployed; `RELEASE_READY.md` written.

**Later (not 0.1.0):** Section 60 authorisation-register designs once a register exists; mobility-based exposure; joint modelling with externally supplied disparity estimates (disparity-weighted effectiveness).

---

## 11. Validation evidence (in `inst/scripts/`, run on a CI schedule, not at check)

1. **Simulation study** across staggered, event, continuous and spillover designs, with and without force-month missingness: bias, RMSE, interval coverage for each estimator; a table of which estimator to use when. Feeds vignette 5.
2. **Placebo battery** on real sample data: placebo outcomes (bicycle theft), placebo dates, placebo areas; the package must produce null-centred distributions.
3. **Benchmark**: time to build a 36-month national LSOA panel from the archive.
4. **Qualitative reproduction**: an aggregate London-level stop-crime elasticity by offence type for a recent period, stored as a fixture with the exact specification, which the package must reproduce exactly on re-run. Do not claim to replicate published papers; state that the specification is the package's own.

---

## 12. Operating rules for the agent (read before every session)

The maintainer will not be available to answer routine questions. Apply the defaults below, record choices in `inst/NOTES/decisions.md`, and continue.

### 12.1 Defaults

| Decision | Default |
|---|---|
| Licence | MIT + file LICENSE, copyright holder "Black Thrive Global" |
| Maintainer | Mustapha Wasseja, `c("aut", "cre")`; no ORCID until supplied |
| Repository URL | `https://github.com/black-thrive-global/streetlamp` (placeholder) |
| Sample forces | `west-yorkshire` and `dyfed-powys`; 24 most recent complete months for the aggregated panel; 3 most recent months of raw files |
| Area default | `lsoa21` |
| Crime total | all crime types except anti-social behaviour |
| Force attribution | `Falls within` |
| Stop intensity default | stops per 1000 resident population |
| Clustering default | area; force offered |
| Fixed effects default | area and month; force-by-month optional |
| Event window | -12 to +12 months, reference -1 |
| Staggered estimator default | Callaway-Sant'Anna with never-treated controls |
| Spillover rings | first and second order queen contiguity |
| Elasticity lags | 0 to 3 |
| Placebo outcome default | bicycle theft |
| Surge detection | threshold at 2 SD above trailing 12-month mean |
| Partial-submission threshold | count below 20% of the force's trailing 12-month median |
| Version selection rule | `latest` |
| Cache | `tools::R_user_dir("streetlamp", "cache")` |
| Simulation sizes | tests: 36 areas × 24 months; CI: 400 areas × 60 months × 200 replications |

### 12.2 Data source mismatches

Use what the live source provides, write the discrepancy to `inst/NOTES/data_sources.md`, adjust, continue. If a source is unavailable for more than one session, build against fixtures and leave a `TODO(source)`.

### 12.3 Conflicts

Priority: (1) CRAN policy, (2) independence constraint, (3) statistical correctness as specified in sections 6 to 8, (4) everything else. Record resolutions.

### 12.4 Session protocol

Start: read this file and `inst/NOTES/decisions.md`, run `devtools::check()`, continue from the first unfinished item. End: check clean or failure documented with a plan; commit; append a three-line note to `inst/NOTES/progress.md`.

### 12.5 Escalate only for

A licence change found in the repo; a data source that is not OGL v3 or equivalent; a CRAN dependency in Imports that is archived or fails to install on any CI platform (in which case move it to Suggests with a graceful fallback and record it). Write to `inst/NOTES/questions.md` and continue with the default.

### 12.6 Definition of done

`lamp_report()` runs end to end on the bundled panel without network; all milestone acceptance criteria met; validation outputs committed under `inst/validation/`; check clean on the full matrix; `cran-comments.md` and `NEWS.md` complete. Write `RELEASE_READY.md` summarising evidence. Do not submit to CRAN; the maintainer does that.

---

## 13. References to cite in documentation

- Braakmann, N. (2022). Does stop and search reduce crime? Evidence from street-level data and a surge in operations following a high-profile crime. JRSS A 185(3).
- Tiratelli, M., Quinton, P. & Bradford, B. (2018). Does stop and search deter crime? Evidence from ten years of London-wide data. British Journal of Criminology 58(5).
- Callaway, B. & Sant'Anna, P. H. C. (2021). Difference-in-differences with multiple time periods. Journal of Econometrics 225(2).
- Sun, L. & Abraham, S. (2021). Estimating dynamic treatment effects in event studies with heterogeneous treatment effects. Journal of Econometrics 225(2).
- Borusyak, K., Jaravel, X. & Spiess, J. (2024). Revisiting event-study designs: robust and efficient estimation. Review of Economic Studies.
- Roth, J. (2022). Pretest with caution: event-study estimates after testing for parallel trends. AER: Insights 4(3).
- Abadie, A., Diamond, A. & Hainmueller, J. (2010). Synthetic control methods for comparative case studies. JASA 105(490).
- Xu, Y. (2017). Generalized synthetic control method. Political Analysis 25(1).
- Bowers, K. J. & Johnson, S. D. (2003). Measuring the geographical displacement and diffusion of benefit effects of crime prevention activity. Journal of Quantitative Criminology 19(3).
- Pesaran, M. H. (2006). Estimation and inference in large heterogeneous panels with a multifactor error structure. Econometrica 74(4).
- Chudik, A. & Pesaran, M. H. (2015). Common correlated effects estimation of heterogeneous dynamic panel data models with weakly exogenous regressors. Journal of Econometrics 188(2).
- Bergé, L. (2018). Efficient estimation of maximum likelihood models with multiple fixed-effects: the R package FENmlm. (fixest lineage)
- Miles-Wilson, J. & Okoroji, C. (2026). policedatR. Crime Science 15:11. (contrast only)

# Decisions log

Choices made without the maintainer, as required by specification section 12.
Newest session first. Each entry says what was decided and why, so that a
later session (or the maintainer) can reverse it deliberately.

## 2026-09-18, validation runs

49. **Pesaran's CD test is vectorised, and samples areas above a cap.** The
    statistic sums over every pair of areas. Built pair by pair with
    `combn()` it cost 77 seconds for 400 areas, which made the simulation
    study a day's work and would have been impossible on the package's own
    default geography: a national LSOA panel has 636 million pairs, and the
    index matrix alone would not fit in memory. It is now one `cor()` call
    with `use = "pairwise.complete.obs"` and one crossproduct for the shared
    month counts, which reproduces the old statistic to the last bit (tested)
    in 3.6 seconds. Above `max_areas = 2000` the test is computed on a random
    sample of areas drawn with a fixed seed, reported in `n_areas_used` and
    named in the printed note. Pesaran's statistic is asymptotic in the
    number of areas, so a two thousand area sample answers the same question;
    a silently impossible computation would not.
50. **The continuous design now has a target in the simulation study.** It
    had `NA`, so `lamp_elasticity()` was the one estimator with no bias,
    RMSE or coverage figure, which is a gap in the evidence the specification
    asks for. There is no single true elasticity in that design: the outcome
    responds to `log(1 + stops)` with elasticity `effect` on twelve of the
    thirteen crime types, so the elasticity of the total varies with the
    level of stops. The target is now the slope of the noise-free log mean on
    `log(1 + stops)` after area and month effects, computed from the
    data-generating process and the stops actually drawn. The difference
    between that and an estimate is the estimator's own doing, because it
    regresses `log(1 + a noisy count)` rather than the log mean.
51. **The simulation study runs on a cluster and writes each cell as it
    finishes.** One replication of the eight grid cells takes about seven
    minutes at 400 areas and 60 months, so the specification's 200
    replications is about a day on one core. The script now takes a worker
    count, defaulting to two fewer than the machine has, and writes
    `simulation-study.csv` after every design-by-missingness cell, so a run
    stopped early still leaves usable results. The script's claim of "roughly
    10 minutes for 200 replications" was wrong by two orders of magnitude and
    has been corrected.
52. **The spatial placebo reassigns treatment by row key, not area by area.**
    `lamp_placebo(type = "space")` gave each treated area a stand-in by
    scanning the whole panel once per treated area. On the bundled two-force
    sample that is 855 treated areas against 41,040 rows on every draw, and
    the default 200 draws took about three hours and twenty minutes; it was
    the reason the placebo battery never finished. Building the row key once
    and looking the timing up gives the same draws, in the same order, from
    the same seed, in 1.1 minutes. Verified draw for draw against the old
    loop on both a simulated panel and the bundled sample.
53. **Validation downloads go outside the repository.** `03-benchmark.R` and
    `04-reproduction.R` wrote into `data-raw/downloads/`, inside a Dropbox
    folder; the national benchmark pulls several gigabytes. They now use
    `inst/scripts/_cache.R`, which puts downloads in
    `tools::R_user_dir("streetlamp", "cache")/validation` unless
    `STREETLAMP_VALIDATION_CACHE` says otherwise.

## 2026-09-18, milestone M3

41. **Estimate class order is `c("<estimator>", "lamp_estimate")`**, the
    reverse of the order written in the specification. S3 dispatches on the
    first class, so the specification's order would send every
    `print()` and `plot()` call to the shared method and the event-study plot
    would never run. Both classes are present, which is what the
    specification's requirement is for.
42. **`lamp_treatment()` returns a treatment object, not a modified panel.**
    Estimators take it as an argument, join it by area and month, and copy it
    into the estimate's contract. A bare column name is also accepted. This
    satisfies both the specification's "returns a `lamp_treatment` object"
    and the estimators' `treatment` argument.
43. **Estimates carry their model frame** (`x$data`) so that
    `lamp_placebo()` can refit without the caller passing the panel again,
    as the specification's signature `lamp_placebo(estimate, type, n)`
    requires.
44. **The simulator's effect applies to every crime type except bicycle
    theft**, which is therefore a genuine placebo outcome. The implied effect
    on `crime_total` is smaller in size than `effect` and is recorded as
    `truth$effect_crime_total`; tests compare against whichever is right for
    the outcome they use.
45. **Pre-trend power follows Roth (2022) and is implemented directly**: the
    Wald statistic under a linear violation of slope `s` is non-central
    chi-square with non-centrality `s^2 t' V^-1 t`, inverted for the slope
    detected with given probability, and reported with the bias that slope
    would put into the post-period estimates.
46. **Placebo p values are randomisation shares**, not tests of a null:
    the share of placebo estimates at least as large in size as the real
    one. Small is good; the printed interpretation says which way round it
    reads.
47. **`lamp_event_study()` refuses staggered adoption outright in M3** and
    names `lamp_did_staggered()`. In M4, once that function exists, it will
    call it internally as the specification requires.
48. **`withr` moves to Imports** because the simulator and placebo use
    `withr::local_seed()` in package code, not only in tests.

## 2026-09-16, milestone M2

32. **Boundaries are the ONS generalised clipped (BGC) layers, read from the
    FeatureServer in pages.** BGC is a tenth the size of full resolution and
    the only form obtainable for every layer; the misallocation of points
    within a few metres of a boundary is documented and users can pass
    full-resolution polygons to `lamp_read_stop_counts()` themselves.
33. **Area hierarchy is derived from the OA-level ONS lookup** because no
    LSOA-to-MSOA product exists; the district-to-force lookup is deduplicated
    on district (every district has one police force area). 2022 districts
    are used throughout because the LSOA lookups are on that vintage.
34. **Population comes from NOMIS TS001 at 2021 LSOA level only** and is
    summed to coarser levels, accepting the small cell-key perturbation
    differences from published totals, so that one cached download serves
    every level. 2011 LSOAs receive equal shares of merged 2021 LSOAs.
35. **Deprivation is bundled as deciles**, not ranks, for the seven shared
    domains (ranks compressed to 658 KB; deciles to 277 KB) with the overall
    rank, decile and (England) score kept. Welsh domain deciles are formed by
    the package from published ranks.
36. **Panel universe is the whole police force area** of every force in the
    records, so areas with no recorded crime in a submitted month are zeros;
    `areas` restricts the panel when the records cover a subset (as the
    bundled fixtures do).
37. **Force level counts by the attributed force** (`Falls within` by
    default), so records without a location are included there; every finer
    level places records by LSOA code. Cross-border records (attributed force
    differs from the area's force) are counted in the contract.
38. **Coverage statuses:** `partial_suspected` uses the specification's 20
    percent of the trailing 12-month median with at least three prior
    submitted months; `refreshed` comes only from the publisher's changelog
    (`lamp_changelog()`), because checksums differ between snapshots for
    almost every street file. `not_read` marks listed files that were not
    read.
39. **Re-vintaging to 2011 LSOAs maps a merged 2021 LSOA to its first parent
    in code order**; `lsoa21` is the recommended target and the default.
40. **Sample panel spans August 2024 to July 2026** (the 24 most recent
    complete months in the July 2026 snapshot) for the whole of West Yorkshire
    and Dyfed-Powys, with boundaries simplified to 50 m for bundling.

## 2026-09-16, milestone M1

19. **Selective download by HTTP byte range.** Archive zips are 1 to 2.6 GB
    and redirect to S3, which honours `Range` requests. `lamp_archive_download()`
    reads a zip's central directory from its tail, then fetches and inflates
    only the wanted force-month members, in pure R (a gzip envelope around the
    DEFLATE stream and `memDecompress()`, which also verifies the CRC). A
    36-month, two-force pull is about 40 MB instead of 1.7 GB. Whole zips
    downloaded by other means are used in place through
    `lamp_archive_register()`.
20. **Cache layout.** `<cache>/archive/<archive>/` holds `archive.rds`
    (source, size, ETag, published MD5, listing time), `members.rds` (the full
    central directory) and `manifest.csv` (fetched members with CRC32,
    SHA-256 and time), with fetched CSVs under `<month>/`. The published MD5
    of the whole zip is recorded but cannot be checked without a full
    download; per-member CRC32 and SHA-256 are the integrity record.
21. **Base R CSV reading.** `utils::read.csv()` with `colClasses =
    "character"` reads a 26,000-row street file in 0.36 s; readr's first call
    costs 5 s on this machine and would break the example time limit. The
    stop-and-search reader skips every column except Date, Latitude,
    Longitude and Legislation through `colClasses = "NULL"`, which satisfies
    the scope boundary at parse time.
22. **Version selection default is `latest`** (the newest snapshot holding
    the file): later snapshots carry updated outcomes and any re-supplied
    data. `earliest` and `prefer` are offered. Rows are never merged across
    versions; the alternatives are kept in the contract.
23. **Coverage statuses in M1 are `submitted` and `missing`.** `refreshed`
    and `partial_suspected` need cross-version reading or the force's trailing
    median and are assigned by `lamp_coverage()` in M2; the reader contract
    already carries `n_versions` and `versions_differ` per force-month.
24. **Crime type harmonisation.** `Violent crime` is renamed to `Violence and
    sexual offences` (a documented rename); `Public disorder and weapons` is
    kept as a fifteenth factor level because it was split and cannot be
    mapped; the raw label is retained and each file's category set (`six`,
    `eleven`, `fourteen`) is recorded in the contract.
25. **Records carry contracts too.** Reader outputs have class `lamp_records`
    with the contract as an attribute, preserved through `[` and dplyr verbs
    (`dplyr_reconstruct` registered lazily), so that `lamp_panel()` can build
    on them and users can subset without losing provenance.
26. **British Transport Police is attributed to itself**, because its files
    carry `British Transport Police` in `Falls within` (contrary to the
    specification's expectation). Geographic placement of BTP records uses
    the LSOA code, as for any other force.
27. **Stop counts at force level need no boundaries**; area-level counts take
    an `sf` layer with an `area` column, so `lamp_read_stop_counts()` works
    before `lamp_boundaries()` exists (M2) and with any user polygons.
28. **Forces table bundled** (`lamp_forces()`): 45 forces with ONS police
    force area codes, which the panel needs for the `pfa` area level.
29. **Readers never fetch by default.** `fetch = FALSE` reads the files held
    locally and says how many selected files were skipped; nothing is
    available raises an error. A first draft that fetched on demand started
    downloading every force in the archive when called without filters.
30. **Stops are dated by their file's month.** The publisher stores local
    time as UTC, so a few searches after 23:00 on the first night of a
    summer-time month carry the previous month's date; the count of such rows
    is kept in the diagnostics.
31. **Line-length lint applies to package sources only.** Test files are
    exempt (`.lintr` exclusion) because they hold long literal file names and
    expectation strings; every other linter still runs on them.

## 2026-09-16, milestone M0

1. **Imports grow with milestones.** `DESCRIPTION` lists only the packages
   used by code that exists, because `R CMD check` notes every declared
   import that is not used. The specification's full Imports list is reached
   by M4. `augsynth` (not on CRAN) enters Suggests in M4 together with an
   `Additional_repositories` decision; CRAN policy (priority 1) requires that
   Suggests be installable from a declared repository or handled gracefully.
2. **Maintainer email.** CRAN requires an email for the `cre` role. The
   maintainer's personal address (muswaseja@gmail.com) is used until a Black
   Thrive Global address is supplied (see `questions.md`).
3. **LSOA lookup: bundle the ONS exact-fit table with a best-fit flag.** The
   ONS product named "Best Fit" (V2) has no change indicator, which the
   specification needs to report split and merged shares; the "Exact Fit"
   product (V3) has the indicator and its code sets equal the ONS
   names-and-codes lists exactly. One table (35,796 rows; 83 KB as an
   xz-compressed rds) therefore serves as the full code list for both
   vintages and as the re-vintaging lookup. Welsh-language names are dropped.
4. **Bank holidays are England and Wales only, from 2010.** Sources: the live
   GOV.UK feed (2019 onwards), Internet Archive captures of the same feed
   (2012 to 2018) and the archived Directgov table (2010 and 2011). Scotland
   and Northern Ireland are outside the package's geography. Apostrophes are
   normalised to ASCII.
5. **Shocks table schema** extends the specification's columns (name, start,
   end, scope, source URL, notes) with `label`, `kind`, `forces` and
   `verified`. Rows whose dates could not be verified from a fetched primary
   source are excluded rather than guessed; they are listed in
   `data_sources.md`.
6. **COVID-19 lockdown end dates** mark the end of the legal stay-at-home
   requirement (England lockdown 1 ends 31 May 2020; lockdown 3 ends 28 March
   2021; Wales alert level 4 ends 12 March 2021), with the staged relaxations
   recorded in `notes` so that users can define their own windows.
7. **Bundled-table accessors are exported in M0** (`lamp_shocks()`,
   `lamp_bank_holidays()`, `lamp_lsoa_lookup()`, `lamp_lsoa_codes()`,
   `lamp_crime_types()`, `lamp_outcome_types()`): the M0 acceptance criterion
   is that the tables load with tests, `lamp_shocks()` is specified anyway,
   and the tables are useful on their own. Tables are read once per session
   and memoised in the package environment.
8. **Outcome grouping** (documented in `?lamp_outcome_types`): every
   court-supplied outcome and offences taken into consideration sit under
   `charged_or_summonsed`; "Action to be taken by another organisation" and
   the public-interest categories sit under `other`; open cases under
   `unknown`.
9. **Crime groupings**: `group` follows the Home Office offence groups with
   the six theft categories combined; `broad_group` collapses to violent,
   acquisitive, drugs, damage, other and asb. Both are package-defined and
   documented.
10. **Legacy (pre-June-2013) crime labels** are handled by an internal
    mapping pending verification against archive files in M1.
11. **Cache directory override** through the option `streetlamp.cache_dir`
    or the environment variable `STREETLAMP_CACHE_DIR`, so that tests and CI
    never write to the user's home directory; the default remains
    `tools::R_user_dir("streetlamp", "cache")`.
12. **Conditions** all carry classes `streetlamp_error_<class>` and
    `streetlamp_error`, `streetlamp_warning_<class>` and
    `streetlamp_warning`, `streetlamp_message_<class>` and
    `streetlamp_message`, raised through `cli`.
13. **CI matrix** is the specification's nine configurations (devel, release,
    oldrel-1 on Ubuntu, macOS and Windows) with `error-on: warning`; the
    local target is zero notes. Coverage below 85 percent fails the coverage
    job. A separate quality job runs lintr, spelling and urlchecker.
14. **Line length 100** in lintr, because roxygen prose and cli message
    strings read better unbroken; styler tidyverse style otherwise.
15. **No README badges** until the GitHub repository exists, because
    urlchecker would flag the placeholder workflow URLs.
16. **Repository sits inside Dropbox** at the maintainer's choice; the
    `.gitignore` excludes check and build artefacts to limit sync churn.
17. **Bundled CSVs are read with base `utils::read.csv`**, not readr. The
    first `readr::read_csv()` call in a session cost about four seconds of
    elapsed time on the check machine, pushing the `lamp_bank_holidays()`
    example over the five-second limit for three tiny tables. readr enters
    Imports with the archive reader in M1.
18. **Local check environment.** `R CMD check` reports "unable to verify
    current time" when the clock service is unreachable; this is not a
    package issue. Local checks set `_R_CHECK_SYSTEM_CLOCK_=0` and CI uses
    the default. `VignetteBuilder: knitr` stays in `DESCRIPTION` (an INFO
    line until the first vignette lands in M4).

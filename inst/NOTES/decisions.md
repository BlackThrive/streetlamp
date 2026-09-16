# Decisions log

Choices made without the maintainer, as required by specification section 12.
Newest session first. Each entry says what was decided and why, so that a
later session (or the maintainer) can reverse it deliberately.

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

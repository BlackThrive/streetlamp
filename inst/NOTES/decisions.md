# Decisions log

Choices made without the maintainer, as required by specification section 12.
Newest session first. Each entry says what was decided and why, so that a
later session (or the maintainer) can reverse it deliberately.

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

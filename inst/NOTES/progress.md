# Progress log

One entry per session, three lines: what was done, check status, next step.

## 2026-09-16, session 1 (M0)

- Done: package skeleton (DESCRIPTION, MIT licence, NAMESPACE, README), CI workflows (check matrix, coverage gate, pkgdown, lint/spelling/urlchecker), lintr and pkgdown config, classed conditions, cache helpers, crime and outcome classifications, and bundled tables verified against sources: 29 policy shocks, England and Wales bank holidays 2010 to 2028, ONS LSOA 2011 to 2021 lookup with both code lists; 134 tests.
- Check: `R CMD check --as-cran` clean (0 errors, 0 warnings, 0 notes) on R 4.5.2 Windows; lintr, spelling and styler clean.
- Next: M1 ingestion and versioning (archive index and download with httptest2 fixtures, `lamp_read_crime()`, `lamp_read_outcomes()`, `lamp_read_stop_counts()`, `lamp_contract()`); first verify archive zip layout, CSV headers and the 2011 to 2013 legacy category strings (TODO(source) items in data_sources.md).

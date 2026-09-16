# streetlamp 0.1.0

* Initial development version.
* M1: selective download from the data.police.uk archive by HTTP byte range
  (`lamp_archive_index()`, `lamp_archive_download()`,
  `lamp_archive_register()`, `lamp_archive_snapshot()`); one archive version
  per force-month file with alternatives recorded (`lamp_list_versions()`,
  `lamp_select_version()`, `lamp_version_diff()`); readers with a fixed
  schema and a panel contract (`lamp_read_crime()`, `lamp_read_outcomes()`,
  `lamp_read_stop_counts()`, `lamp_contract()`); LSOA vintage detection
  (`lamp_lsoa_vintage()`); the forces table (`lamp_forces()`); and two
  bundled miniature archive snapshots for offline examples and tests.
* M0: package skeleton, MIT licence, continuous integration, testthat,
  pkgdown, lintr; bundled crime and outcome classifications, national policy
  shocks table, bank holidays table, and ONS LSOA 2011 and 2021 code lists
  with the 2011 to 2021 best-fit lookup.

# streetlamp: Panel Econometrics for the Effect of Police Stop and Search on Recorded Crime

`streetlamp` builds an area-by-month panel of recorded crime in England
and Wales from the data.police.uk bulk archive, attaches stop and search
intensity as a treatment variable, and provides estimators for
evaluating policing interventions. It is about what stops achieve, not
who is stopped: it never computes an ethnic disparity measure and reads
stop and search files only to count stops by area and month.

## Design principles

- Every panel carries a **panel contract** recording provenance,
  coverage, LSOA vintage and treatment definition. Estimators read it
  and refuse or warn when their assumptions are violated.

- "Force did not submit" is never a zero.

- Anti-social behaviour is not a crime: it is kept in a separate series
  and excluded from crime totals by default.

- Treatment effects are reported with the identifying assumption named
  in the output, and every estimator ships with a placebo or pre-trend
  diagnostic.

- No network access during `R CMD check`, tests or examples.

## Data attribution

Recorded crime, outcomes and stop and search counts derive from
data.police.uk, and geography from the Office for National Statistics
Open Geography Portal, both published under the Open Government Licence
v3.0. Bank holidays derive from GOV.UK. See `inst/NOTES/data_sources.md`
in the package sources for what was verified and when.

## See also

Useful links:

- <https://github.com/BlackThrive/streetlamp>

- <https://blackthrive.github.io/streetlamp/>

- Report bugs at <https://github.com/BlackThrive/streetlamp/issues>

## Author

**Maintainer**: Mustapha Wasseja <muswaseja@gmail.com>

Authors:

- Souci Frissa

- Sarah Hamed

Other contributors:

- Black Thrive Global \[copyright holder, funder\]

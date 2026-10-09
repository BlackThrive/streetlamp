# London case-study interpretation

This is an association study with area and month fixed effects. No independently assigned intervention is identified.
The seven outcomes, three lag windows and two response families were specified together; every result and failure is retained.
The primary specification is total recorded crime, PPML, lags 0 to 3, borough clustering. The two London forces are too few force clusters for routine asymptotic inference.
Bicycle theft is a comparison outcome, not a proven unaffected negative control. Searching, crime recording, deployment and unobserved local changes can affect several outcomes together.
Drugs and weapons possession are detection-sensitive. A rise in their recorded counts can reflect more detection.
The future-search coefficient probes timing and reverse allocation; neither its significance nor non-significance establishes exogeneity.
Leave-one-borough-out results assess concentration of the association. They cannot resolve confounding or displacement.
The source CSVs were checked against cached SHA-256 hashes. Population is a fixed 2021 census reference, not contemporaneous exposure; it is not used as an offset in these count models.

Panel: 792 rows; 33 areas; 24 months.
Grid failures: 0 of 42
Leave-one-out failures: 0 of 34

A causal article case requires independently documented rollout and assignment, longer pre-period support, appropriate comparison areas, and evidence on recording changes and co-interventions.

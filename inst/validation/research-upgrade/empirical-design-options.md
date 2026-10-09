# Empirical design options for a causal article case

The London 2024-08 to 2026-07 analysis is an audited association study.
It cannot be converted into an intervention evaluation by interpreting a
significant coefficient as causal. The public pilots below are candidates
for further data work, not completed evaluations by streetlamp.

## Precision stop-and-search pilot

The Met documents a July–December 2023 pilot in nine high-risk wards across
Barking & Dagenham and Lambeth. It combined training, consultation and
targeted patrols, and evaluated weapon-enabled harm and encounter quality.
[Metropolitan Police primary report](https://www.met.police.uk/police-forces/metropolitan-police/areas/about-us/about-the-met/research/research-analysis-met/precision-stop-and-search-evaluating-the-impact-of-targeted-enhancements-to-stop-and-search-training/).

Our assessment: this is a documented intervention, but ward selection using
prior harm can induce regression to the mean. Public broad offence counts
do not exactly measure weapon-enabled harm, and a bundled intervention
cannot isolate the effect of search intensity alone. Obtain target ward
boundaries, exact deployment dates, delivery measures, appropriate comparison
wards and pre-pilot outcome data. Evaluate the bundled programme, with
pre-trend, spatial contamination and outcome-definition sensitivity checks.
The existing London fixture starts after the pilot, so it cannot supply its
pre-period. The source report does not show a significant crime impact;
streetlamp must retain findings regardless of their direction.

## Serious Violence Reduction Orders

The official evaluation documents the April 2023–April 2025 four-force pilot
and compares eligible individuals with matched individual comparators.
[Home Office independent evaluation](https://www.gov.uk/government/publications/serious-violence-reduction-orders-independent-evaluation-report/serious-violence-reduction-orders-independent-evaluation-report).

Our assessment: force-level total recorded crime is poorly aligned with an
individual order. Using four pilot-force totals as treatment would dilute
exposure and introduce a different estimand. A credible extension needs
order dates, eligibility and individual outcomes or appropriately aggregated
exposure measures, with access permissions and disclosure controls. Do not
present a force-level ecological analysis as a reproduction of the official
individual evaluation.

## Practical route with independently supplied rollout data

Use a dated intervention table with area code, start date, deployment or
eligibility intensity, assignment mechanism, programme components and source
reference. Choose comparisons and primary outcomes before reviewing effects.
Record concurrent policies, reporting changes and areas exposed to spillovers.
Run `lamp_design_audit()`, fit a suitable staggered or single-event design,
retain pre-trend power and comparison-outcome diagnostics, and assess the
sensitivity to trend violations. Match the outcome scale and aggregation
weights to a stated policy estimand.

If these records cannot be obtained, frame the article around a validated
research infrastructure and an honest empirical association example. That
is a defensible software contribution; it is not new evidence of a policing
effect.

## Position relative to the referenced article

The [policedatR article](https://link.springer.com/article/10.1186/s40163-025-00266-6)
presents data acquisition, geographic/population enrichment, descriptive
analysis and disparity measures. Streetlamp's proposed contribution is a
validated workflow for intervention designs, explicit estimands, uncertainty,
missing submissions and robustness. This extends the published analytical
focus; it does not establish universal superiority over its current software
or substitute for a benchmark or literature review. Existing statistical
methods are attributed to their authors rather than presented as new
estimators.

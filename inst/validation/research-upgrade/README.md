# Streetlamp research upgrade, 0.2.0.9000

This directory contains new evidence, separate from the historical 0.1.0
results in its parent directory. No historical result was replaced. The
article case is strengthened as an audited association study; causal
identification remains a separate requirement.

## What changed

* The FE elasticity method defaults to Poisson pseudo-likelihood for the
  conditional count mean, including zeros. The legacy response scale remains
  explicit, and CCE continues to target log-one-plus observed outcomes.
* Lags follow calendar months, including gaps. Estimator exclusions include
  zero-count fixed-effect groups removed by the backend.
* Simulations support different cohort effects, delayed/dynamic paths,
  overdispersion, selective missing submissions and deliberate trend
  violations. Additive designs support count-level parallel trends, and
  exact area-month counterfactual means are exposed.
* Effect summaries use joint covariance, or the backend's overall ATT.
  Trend sensitivity is conditional on specified linear deviations. Design
  audits and full specification/area-omission ledgers expose limitations.
* Crimes-prevented arithmetic distinguishes response scales, accounts for
  log-one-plus stops, preserves covariance and transforms intervals directly.
* The force-clustered Callaway–Sant'Anna wrapper enables the backend's
  required multiplier bootstrap. Unsupported force clustering is rejected
  by the CCE mean-group and imputation wrappers.

## Simulation evidence

`simulation-summary.csv` contains 200 replications in each of eight
scenarios, 4,000 estimator fits, no failed fits, bias, RMSE, coverage and
Monte Carlo uncertainty. Count scenarios use 100 areas and 36 months;
staggered scenarios use 96 areas and 24 months. Additive staggered cases use
base rate 100 to maintain positive count means under the specified negative
effects; an earlier base-rate-50 run was unsuitable for all seeds and was
replaced, rather than dropping the invalid replication.

| Scenario | Estimator | 95% interval coverage |
|---|---|---:|
| Conditional count mean | PPML | 94.5% |
| Sparse counts | PPML | 95.0% |
| Overdispersion | PPML | 94.0% |
| Selective missingness | PPML | 94.0% |
| Different cohort effects | Callaway–Sant'Anna / Sun–Abraham | 97.5% / 96.5% |
| Different cohort effects | Linear TWFE comparator | 35.5% |
| Dynamic cohort effects | Callaway–Sant'Anna / Sun–Abraham | 95.0% / 95.0% |
| Dynamic cohort effects | Linear TWFE comparator | 16.5% |
| Violated parallel trends | Callaway–Sant'Anna / Sun–Abraham | 85.5% / 86.0% |

Monte Carlo coverage intervals are reported in the CSV. These are finite
designs with area-clustered inference, not a promise of nominal coverage for
every dataset. The selective-missingness scenario depends on untreated
expected counts; it does not exhaust arbitrary outcome-dependent selection.
The violated-trends result is retained because the causal identifying
assumption deliberately fails.

`elasticity-original-design-summary.csv` checks the original study dimensions
of 400 areas and 60 months, total recorded crime mixing affected and
unaffected types, and 0%/10% force-month missingness. The PPML target is its
noise-free expected-count projection. The legacy comparator uses the old
log-mean projection target, which is not the expectation of its transformed
observed response. Changing that estimand mismatch is different from merely
widening confidence intervals.

| Original design | Count-model coverage | Legacy comparator coverage |
|---|---:|---:|
| Complete submissions | 96.0% | 62.5% |
| 10% missing force-months | 95.0% | 66.0% |

Each row uses 200 replications and 400 estimator fits, with no failed fits.
Together with the eight main scenarios, these studies contain 4,800 backend
fits. The count-model bias is 0.00022 and 0.00031 in the two original-design
cells. The targets differ between the count model and legacy comparator;
this table does not compare interchangeable coefficients.

The 200-replication heterogeneous case has a mean error of about 0.35 counts
(Monte Carlo SE 0.12); the dynamic case has mean error about -0.21 (SE 0.13).
`08-staggered-bias-audit.R` investigates these finite-run deviations with an
independent 10,000-replication oracle check per design. It first verifies its
analytic contrast against saved backend estimates and then uses the exact
Poisson-sum distribution and known sampling variance. Oracle coverage is
not a substitute for validation of the backend's reported covariance.
The independent audit finds bias 0.00886 (Monte Carlo SE 0.01788) in the
heterogeneous design and 0.00191 (SE 0.01786) in the dynamic design. Both
Monte Carlo intervals include zero; oracle interval coverage is 94.71%
and 94.82%, respectively. These 20,000 oracle replications are separate
from the backend fit counts above.

## London evidence and limits

The study covers 33 boroughs and 24 months. It verifies SHA-256 hashes for
95 crime/search files; one requested force-month file is absent, leaving
32 area-month stop counts unavailable. Calendar lags reduce the primary
model to 561 observed area-months. The complete ledger retains all seven
outcomes, three lag windows and two response scales (42 specifications),
and 34 fits for the primary specification with each borough omitted in turn.

The primary total-crime count-model slope sum is 0.01339, with interval
[0.00085, 0.02594]. Bicycle theft has a comparison-outcome slope of -0.02004,
with interval [-0.04085, 0.00076]. The future-search coefficient is -0.00441,
with interval [-0.00886, 0.00005]. These checks do not establish exogeneity;
bicycle theft is not a proven unaffected control. Drugs and weapons counts
can respond directly to detection. A non-significant allocation diagnostic
does not establish the absence of reverse allocation.

The OLS and count-mean rows have different estimands. Selecting whichever
row is significant would invalidate this robustness exercise. The primary
specification and grid were selected for this development study; they were
not prospectively preregistered before the historical London results were
seen. A new confirmatory study needs a genuinely prospective protocol.

See `london-report.md`, `london-interpretation.md`, the CSV ledgers, and
`empirical-design-options.md`. The latter evaluates documented public pilots
and lists the intervention records needed for a causal case. These records
have not yet been supplied.

## Reproduction and publication

Run source scripts 05, 05b, 06, 07 and 08 from the package checkout. The
validation scripts require a development R environment with `devtools` and
the package dependencies. Script 05 resumes completed count scenarios and
always reruns the staggered scenarios. Script 06 requires an existing source
cache, verifies its hashes, and refuses network access. Raw downloads,
panel caches and the full oracle audit stay outside the repository.

The strongest proposed article contribution is an auditable infrastructure
for intervention analysis, with explicit estimands and validation. The
statistical estimators are existing methods attributed to their authors.
A causal empirical finding requires independently documented intervention
assignment, suitable pre-periods and comparisons, and evidence on concurrent
changes. Comparative claims should be limited to the published analytical
focus until a reproducible software benchmark and literature review exist.

## Software checks

The development package passes the local Windows/R 4.5.2 check with zero
errors, warnings or notes (`R CMD check --as-cran --no-manual`). All six
vignettes build and rebuild, examples and tests pass, and separate source
tests include the visual snapshots. Lintr and spelling checks are clean.
See `package-check.log` for the package-check output.

This local check uses devtools' default disabled incoming/remote CRAN
checks and does not build the PDF reference manual. It is not a CRAN
submission or a current cross-platform release check. The expanded package
still needs release-version checks on the platform matrix, incoming/URL
checks and manual compilation before submission.

# London: audited stop-crime associations, not an intervention effect

Built 2026-10-06 00:45 with streetlamp 0.2.0.9000.

## The panel

33 areas by 24 months (792 rows), area level `lad`.

### Coverage

Force-months by file type and status. A month a force did not submit is
not a month with no crime, and every estimate below excludes those rows.

| File type | Submitted | Missing |
| --- | ---: | ---: |
| Stop and search files | 47 | 1 |
| Street crime files | 48 | 0 |

2 force-month(s) have a crime file without a stop-and-search file or the reverse, which breaks the link between treatment and outcome in those months.

### Provenance

Archive snapshots: 2026-07.

Population: NOMIS NM_2021_1 (Census 2021 TS001, usual residents).

## Estimates

### Primary: total recorded crime, PPML

- Estimator: `lamp_elasticity`
- Outcome: `crime_total`, modelled as Poisson pseudo-likelihood on counts
- Clustered by: area
- Sample: 561 area-months in 33 areas
- Force-months dropped for coverage: 0

**Identifying assumption.** The association between searching and recorded crime, net of area and month effects. Causal only if the variation in searching has a source outside the crime process; see lamp_allocation().

| Term | Estimate | Std. error | 95% CI | p |
| --- | ---: | ---: | ---: | ---: |
| Log stops, lag 0 | -0.0023 | 0.00278 | [-0.00774, 0.00315] | 0.408 |
| Log stops, lag 1 | 0.00152 | 0.00139 | [-0.00121, 0.00424] | 0.275 |
| Log stops, lag 2 | 0.00834 | 0.00458 | [-0.000635, 0.0173] | 0.069 |
| Log stops, lag 3 | 0.00583 | 0.00374 | [-0.0015, 0.0132] | 0.119 |

**Estimand.** log conditional count mean per log(1 + stops). Calendar months define the lags.

| estimate | std_error | conf_low | conf_high | level | definition |
| --- | ---: | ---: | ---: | ---: | ---: |
| 0.0133928921963767 | 0.00639916878867795 | 0.000850751839575151 | 0.0259350325531783 | 0.95 | 1 * .log_s_lag0 + 1 * .log_s_lag1 + 1 * .log_s_lag2 + 1 * .log_s_lag3 |

### Comparison outcome: bicycle theft, PPML

- Estimator: `lamp_elasticity`
- Outcome: `bicycle_theft`, modelled as Poisson pseudo-likelihood on counts
- Clustered by: area
- Sample: 561 area-months in 33 areas
- Force-months dropped for coverage: 0

**Identifying assumption.** The association between searching and recorded crime, net of area and month effects. Causal only if the variation in searching has a source outside the crime process; see lamp_allocation().

| Term | Estimate | Std. error | 95% CI | p |
| --- | ---: | ---: | ---: | ---: |
| Log stops, lag 0 | -0.00719 | 0.00596 | [-0.0189, 0.0045] | 0.228 |
| Log stops, lag 1 | 0.000512 | 0.00411 | [-0.00754, 0.00857] | 0.901 |
| Log stops, lag 2 | -0.0129 | 0.00393 | [-0.0206, -0.00516] | 0.001 |
| Log stops, lag 3 | -0.00051 | 0.00397 | [-0.00829, 0.00727] | 0.898 |

**Estimand.** log conditional count mean per log(1 + stops). Calendar months define the lags.

| estimate | std_error | conf_low | conf_high | level | definition |
| --- | ---: | ---: | ---: | ---: | ---: |
| -0.0200447102359575 | 0.0106162447092504 | -0.0408521675171522 | 0.000762747045237239 | 0.95 | 1 * .log_s_lag0 + 1 * .log_s_lag1 + 1 * .log_s_lag2 + 1 * .log_s_lag3 |

### Reverse allocation channel

- Estimator: `lamp_allocation`
- Outcome: `stops`, modelled as Poisson pseudo-likelihood on counts
- Clustered by: area
- Sample: 565 area-months in 33 areas
- Force-months dropped for coverage: 0

**Identifying assumption.** None: this is descriptive. It measures how searching has tracked recorded crime, not an effect of crime on searching.

| Term | Estimate | Std. error | 95% CI | p |
| --- | ---: | ---: | ---: | ---: |
| .log_crime_lag1 | -0.102 | 0.38 | [-0.846, 0.643] | 0.789 |
| .log_crime_lag2 | 0.464 | 0.445 | [-0.408, 1.34] | 0.297 |
| .log_crime_lag3 | -0.138 | 0.481 | [-1.08, 0.805] | 0.774 |

Dispersion: 80.5.

## How to read this

- Every estimate above rests on the assumption printed with it. None of them is established by the data.
- Recorded crime is what the police wrote down. A change in recording practice moves these numbers exactly as a change in crime does.
- Crime locations are snapped to anonymised points, so area assignment is approximate near boundaries.
- Anti-social behaviour is excluded from crime totals: it has no crime identifier and no outcome, and is not a crime.
- Police send officers where crime has risen. Unless that channel is measured and argued away, an association between searching and crime is not the effect of searching.


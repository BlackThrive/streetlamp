# Validation evidence

Output of the scripts in `inst/scripts/`, run once with network access. None
of this runs at check time. Each file records what the package does, at the
scale the build specification asks for, including the places where it does
badly.

Run on 2026-09-20 and 2026-09-21, Windows 11, R 4.5.2, 12 cores, 32 GB.

| File | Script | What it is |
|---|---|---|
| `simulation-study.csv` | `01-simulation-study.R` | One row per replication, design, missingness level and estimator |
| `simulation-summary.csv` | `01-simulation-study.R` | Bias, RMSE and interval coverage from those replications |
| `placebo-battery.csv` | `02-placebo-battery.R` | Every placebo estimate on the bundled sample panel |
| `placebo-summary.csv` | `02-placebo-battery.R` | The three placebo families summarised |
| `benchmark.csv` | `03-benchmark.R` | Time and bytes to build a national LSOA panel |
| `reproduction-london.csv` | `04-reproduction.R` | A fixed London specification, stored so that re-running must match it |

## 1. Simulation study

200 replications of each of the four designs, with and without force-month
missingness: 400 areas, 60 months, eight grid cells, 32 minutes on eight
workers. True effect -0.25 log points on the affected crime types, which is
-0.228 on `crime_total` because bicycle theft is never affected.

What it shows:

* **Event design.** `lamp_twfe()` and `lamp_event_study()` recover the effect
  with bias under 0.005 and interval coverage of 0.94 to 0.99. Ten percent
  force-month missingness costs a little precision and nothing else.
* **Staggered design.** Callaway-Sant'Anna and Sun-Abraham both recover it,
  bias 0.004 to 0.005, coverage 0.92 to 0.93.
* **Spillover design.** This is the one that separates the estimators.
  `lamp_twfe()` and `lamp_event_study()`, which ignore the neighbour term,
  are biased by +0.104 on a true -0.228 and their intervals never cover it:
  coverage 0.000. `lamp_spillover()` recovers both the own effect (bias
  -0.002, coverage 0.98) and the net effect (bias -0.002, coverage 0.94).
  That is the specification's "TWFE omitting the spillover term is biased in
  the expected direction", and the size of it is worth seeing: ignoring
  displacement turns nearly half the effect into nothing.
* **Continuous design.** `lamp_elasticity()` is biased towards zero by about
  0.005 on a target near -0.22, the same for all three methods, and its
  intervals cover only 0.66 to 0.70 of the time rather than 0.95. The cause
  is the estimator's own choice of response: it regresses `log(1 + a noisy
  count)` rather than the log mean, and at these count levels that attenuates
  the slope by more than the interval is wide. **Read elasticities from this
  package as slightly conservative, and do not treat their intervals as
  exact.** This is a real limitation, not a coding error, and it is the
  reason the target column exists in `simulation-study.csv`.

Two things the study does not show. The simulator gives every treated area
the same effect, so it cannot demonstrate the heterogeneity-driven bias that
makes two-way fixed effects unsafe under staggered adoption; the row labelled
`lamp_twfe (wrong here)` is close to the truth for that reason, and that is a
property of the simulation, not a defence of the estimator. And nothing here
says anything about stop and search: these are synthetic panels with a known
answer.

## 2. Placebo battery

Run on the bundled two-force sample panel (1,710 LSOAs, 24 months) against an
invented intervention: half the areas, from the middle of the period. Nothing
happened, so nothing should be found.

* **Placebo areas**, 200 random reassignments: mean 0.0009, median 0.0017,
  5th to 95th percentile -0.018 to 0.015. Centred on zero.
* **Placebo dates**, the fake event moved through the pre-period: mean
  -0.0029.
* **Placebo outcomes**, all 13 crime types: 1 of 13 excludes zero, against
  the 1 in 20 expected by chance.

## 3. Benchmark

See `benchmark.csv` for the per-step timings.

## 4. London reproduction

A fixed specification, written down in `04-reproduction.R` and stored in
`reproduction-london.csv`: archive 2026-07, the Metropolitan Police and City
of London, 24 months from August 2024, local authority districts, a
distributed lag of 0 to 3 months, fixed effects, clustered by area. 33 areas,
24 months, 661 usable rows after the coverage exclusions.

Re-running reproduced the stored file exactly, after the estimator changes
made on 2026-09-20 and 2026-09-21. That is what the file is for: a change in
these numbers means either the package changed behaviour or the archive
revised those months, and the script prints which rows moved.

**This is not a finding about stop and search in London.** The specification
is the package's own, chosen to be fixed rather than to be right. Two things
in it should stop anyone reading it as an effect:

* The elasticity of `crime_total` is 0.006, with an interval of -0.005 to
  0.017: nothing.
* Bicycle theft, which the package uses as its default placebo outcome,
  comes out at -0.041 with an interval of -0.072 to -0.009. A placebo outcome
  that moves means the specification is picking up something other than
  searching. The drugs elasticity of +0.046 is the other half of the same
  story: drug offences are largely produced by searching, so that association
  is close to mechanical.

Both are what `lamp_allocation()` exists to warn about, and the allocation
model printed alongside the run says the same thing.

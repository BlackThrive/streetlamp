# Methods: equations, assumptions and limits

What each estimator computes, what it has to assume, and what it cannot tell
you. Notation: `i` indexes areas, `t` months, `Y_it` the outcome (a crime
count unless said otherwise), `D_it` the treatment, `a_i` and `g_t` area and
month fixed effects.

## 1. Two-way fixed effects, `lamp_twfe()`

    E[Y_it] = exp(b * D_it + x_it'c + a_i + g_t)      (family = "poisson")
    log(1 + Y_it) = b * D_it + x_it'c + a_i + g_t + e_it   (family = "ols_log")

`b` is the effect in log points. Standard errors are clustered at area level
by default, force level on request.

**Assumption.** Parallel trends: absent any change in `D`, treated and
control areas would have moved together in `Y` once `a_i` and `g_t` are
removed. With a continuous `D`, additionally that the intensity of searching
is unrelated to whatever else was changing in the area.

**Fails when.** Adoption is staggered (see 3); the treatment responds to the
outcome (see 7); a shock hits treated areas alone; or treatment spills over
onto the controls (see 5), which biases `b` toward zero.

**Diagnostics.** Dispersion, the Pearson chi-square over residual degrees of
freedom: far above 1 means the Poisson variance assumption understates the
spread and a negative binomial or clustered errors are safer. Moran's I of
the area-mean residuals when adjacency is present: positive values mean
neighbouring areas' residuals move together, so the standard errors are too
small.

## 2. Event study, `lamp_event_study()`

    E[Y_it] = exp(sum_{k != r} b_k * 1{t - E_i = k} * T_i + a_i + g_t)

with `E_i` the event month, `T_i` an indicator for treated areas and `r` the
reference month (default -1). Months outside the window are pooled into
endpoint bins so that they still identify the fixed effects.

**Assumption.** As 1, and in addition no anticipation: `Y` does not move
before the event in response to it. The pre-period coefficients `b_k` for
`k < 0` test a consequence of parallel trends, not parallel trends itself.

**Pre-trend power, `lamp_pretrends()`.** Under a linear violation with slope
`s` per month, the expected pre-period coefficients are `s * (k - r)`, so the
Wald statistic is non-central chi-square with

    lambda(s) = s^2 * t' V^-1 t,    t = (k - r) over pre-period k

with `V` the clustered covariance of the pre-period coefficients. Inverting
`P(chi2_df(lambda) > crit) = p` gives the slope detected with probability
`p`, and `s * mean(k - r)` over the post window is the bias such a slope
would leave in the estimates. A test that passes while blind to a slope big
enough to explain the result is not evidence of anything. This follows Roth
(2022) and is implemented directly.

## 3. Staggered adoption, `lamp_did_staggered()`

When areas adopt at different dates, the two-way fixed effects estimator uses
already-treated areas as controls, and its estimate is a weighted average of
group-time effects in which some weights are negative: it can lie outside the
range of every area's true effect. `lamp_event_study()` therefore refuses
staggered designs, and this function is what replaces it.

**Callaway and Sant'Anna (2021), the default.** For cohort `g` (areas
adopting in month `g`) and month `t`,

    ATT(g, t) = E[Y_t - Y_{g-1} | G = g] - E[Y_t - Y_{g-1} | control]

with the control group either never-treated areas or not-yet-treated ones.
The group-time effects are then aggregated: `simple` for one number,
`dynamic` for the event-study path, `group` for one effect per cohort.

**Sun and Abraham (2021).** An interaction-weighted estimator that fits all
cohort-by-relative-time interactions in one regression and averages them with
cohort-share weights.

**Borusyak, Jaravel and Spiess (2024), `imputation`.** Fits the untreated
potential outcome on untreated observations only, then imputes it for treated
ones. Efficient under the same assumptions; needs `didimputation`.

**Assumption.** Parallel trends by cohort against the chosen control group
from `g-1` onward, and no anticipation. `not_yet_treated` uses more data but
assumes that a later adopter's timing carries no information about its
current path.

**Counts.** All three backends model an outcome on an additive scale, so
counts are transformed (`log1p` by default, or the inverse hyperbolic sine).
The package warns when a count outcome meets a transformed scale, because the
coefficients are then effects on that scale.

## 4. Synthetic control, `lamp_synth()`

For one treated unit and `J` donors, weights `w` are chosen to minimise the
pre-period distance

    min_w || Y_treated,pre - Y_donors,pre w ||^2   s.t. w >= 0, sum(w) = 1

solved here by projected gradient descent so that no extra package is needed.
The effect is the post-period gap `Y_treated - Y_donors w`. Inference is by
permutation: the procedure is repeated pretending each donor was treated, and
the treated unit's ratio of post-period to pre-period root mean squared error
is compared with the donors' ratios.

**Assumption.** The weighted donors reproduce the treated unit's untreated
path. Credible only with a close pre-period fit over a long window, no donor
affected by the intervention, and nothing else happening to the treated unit
at the same time.

**Limit.** On a single small area with noisy monthly counts the pre-period
fit is usually poor, and the package says so rather than reporting a gap.
The permutation p value cannot go below `1/(J+1)`.

## 5. Spillovers, `lamp_spillover()`

    E[Y_it] = exp(b * D_it + sum_r d_r * Wbar_r D_it + a_i + g_t)

where `Wbar_r D_it` is the mean treatment of area `i`'s ring-`r` neighbours.
`b` is the own-area effect, `d_r` the neighbour effect, and `b + sum_r d_r`
the net effect across a treated area and its rings, reported with a standard
error from the full covariance matrix.

**Assumption.** As 1, and that the treatment reaches an area only through its
own treatment and the rings included. Spillover beyond the last ring means
the controls are treated too, and every coefficient is pulled toward zero.

**Limit.** When treated areas are contiguous, own and neighbour exposure move
together, so the two coefficients are individually imprecise even though the
net is well identified. Read the net.

## 6. Displacement, `lamp_displacement_quotient()`

    WDQ = ((B1/C1) - (B0/C0)) / ((A1/C1) - (A0/C0))

with `A`, `B`, `C` total crime in treated, buffer and control areas and `0`,
`1` the pre and post periods (Bowers and Johnson 2003). Negative means crime
moved into the buffer; between 0 and 1, the buffer improved by less than the
treated areas (diffusion of benefit); above 1, it improved by more.

**Limit.** A descriptive ratio, not a causal estimate. Its denominator is the
treated area's change net of controls, so when that change is near zero the
quotient is unstable, which the bootstrap interval shows as a very wide
range.

## 7. Elasticity and allocation, `lamp_elasticity()`, `lamp_allocation()`

    log(1 + Y_it) = sum_{l} b_l * log(1 + S_{i,t-l}) + a_i + g_t + e_it

`sum_l b_l` is the cumulative elasticity. Three methods:

* `fe`: as written.
* `cce_pooled`: add the cross-sectional averages of the outcome and
  regressors, with area effects only. The averages proxy for unobserved
  common factors (Pesaran 2006), and month dummies as well would be collinear
  with them.
* `cce_mg`: one regression per area with the same averages, then average the
  slopes. The standard error is the spread of the area slopes, so no common
  slope is assumed.

**Pesaran's CD test.** The scaled mean pairwise correlation of residuals
across areas, standard normal under cross-sectional independence. It is
computed on residuals from an area-effects-only regression, because month
dummies remove the common factor by construction and would force the
statistic negative whatever the data looked like.

**The allocation problem.** Police deploy where crime has risen, so `S`
responds to `Y` as well as possibly causing it. `lamp_allocation()` estimates

    E[S_it] = exp(sum_{l>=1} c_l * log(1 + Y_{i,t-l}) + a_i + g_t)

and is labelled descriptive. A positive `sum_l c_l` is the size of the
reverse channel that must be argued away before any elasticity is called
causal. A regression of crime on searches nets the deterrent effect against
this allocation response and reports the sum of the two.

## 8. Crimes prevented, `lamp_crimes_prevented()`

From an elasticity `e`, at mean crime `C` and mean searches `S`:

    crimes prevented per N searches = -e * C * N / S

From a treatment effect `b` in log points, with `A` searches added by the
intervention:

    crimes prevented per N searches = -C * (exp(b) - 1) * N / A

**Limits, all reported with the number.** Recorded crime only, so unreported
crime is invisible and a recording change counts as a change in crime; the
average effect is applied at the margin, which is the opposite of
diminishing returns; and it inherits every assumption of the estimate it came
from. It counts none of the costs of searching, which fall on the people
searched.

## 9. Limits that apply to everything here

**Recording practice.** These are crimes the police recorded. The 2014
inspection of crime data integrity, the National Crime Recording Standard
changes that followed, and force-level system migrations all moved recorded
crime without moving crime. `lamp_shocks()` carries the dated ones so they
can be controlled for or excluded.

**Anonymised locations.** Crime locations are snapped to a fixed list of map
points, each covering at least eight addresses, and the list was rebuilt in
2022. Area assignment near a boundary is therefore approximate, and the
package's generalised boundaries add to that. Neither is a problem at
district or force level; both matter at LSOA level.

**Anti-social behaviour.** ASB records carry no crime identifier and no
outcome. They are not crimes and are excluded from crime totals by default,
kept in their own series.

**Coverage.** A force-month with no file is not a month with no crime. Every
estimator drops those rows and reports how many, and the coverage audit shows
which force-months have a crime file without a stop-and-search file, since
those months cannot link treatment to outcome.

**What none of this measures.** The effect of being stopped on the person
stopped, the distribution of searches across groups, or the legitimacy costs
of the tactic. `streetlamp` is about what stops achieve in aggregate recorded
crime, and that is a narrow question.

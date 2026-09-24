# Build a report on a panel and the estimates made from it

Renders a document that puts a set of estimates next to the things that
decide whether they mean anything: the coverage of the panel they came
from, the identifying assumption of each estimator, the pre-trend and
placebo diagnostics, and the allocation model. The report is
deliberately hard to read as a simple verdict, because the underlying
question does not have one.

## Usage

``` r
lamp_report(
  panel,
  estimates,
  file = NULL,
  title = "streetlamp report",
  diagnostics = TRUE,
  figures = NULL,
  quiet = FALSE
)
```

## Arguments

- panel:

  A `lamp_panel`.

- estimates:

  A named list of `lamp_estimate` objects, or a single estimate. Names
  become section headings.

- file:

  Output file. The extension decides the format: `.html` or `.md`.
  `NULL` writes an HTML file to a temporary location.

- title:

  Report title.

- diagnostics:

  Include the pre-trend and placebo sections where the estimates support
  them.

- figures:

  Draw each estimate's
  [`plot()`](https://rdrr.io/r/graphics/plot.default.html) as a PNG into
  a `_figures` directory beside the report and include it. `NULL`, the
  default, draws figures for an HTML report (where they are also
  embedded in the page, so the file stands alone) and not for a Markdown
  one. A figure that cannot be drawn is skipped, never an error.

- quiet:

  Suppress rendering output.

## Value

The path to the written file, invisibly.

## Examples

``` r
sim <- lamp_simulate(n_areas = 20, n_months = 20, design = "event", seed = 1)
truth <- attr(sim, "truth")
tr <- lamp_treatment(sim, "event", date = truth$event_date, scope = truth$treated_areas)
out <- lamp_report(
  sim,
  list("Two-way fixed effects" = lamp_twfe(sim, "crime_total", tr)),
  file = tempfile(fileext = ".md"), quiet = TRUE
)
file.exists(out)
#> [1] TRUE
```

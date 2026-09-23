# The data.police.uk changelog as a table of refresh and gap notes

Fetches and parses the publisher's changelog, which records when a force
re-supplied months ("data refresh") or failed to supply a month ("not
provided").
[`lamp_coverage()`](https://blackthrive.github.io/streetlamp/reference/lamp_coverage.md)
and
[`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md)
use it to mark force-months as `refreshed` and to annotate gaps. The
page is fetched once and cached; pass `refresh = TRUE` to fetch it
again.

## Usage

``` r
lamp_changelog(refresh = FALSE, dir = lamp_cache_dir())
```

## Arguments

- refresh:

  Fetch the page again even if a cached copy exists.

- dir:

  Cache directory; see
  [`lamp_cache_dir()`](https://blackthrive.github.io/streetlamp/reference/lamp_cache_dir.md).

## Value

A tibble with columns `entry_month` (the changelog heading, a Date),
`force_name`, `force_id`, `file_type` (`street`, `outcomes`,
`stop-and-search`, a semicolon-separated combination, or `all`),
`action` (`refresh` or `not_provided`), `from`, `to` (Dates, `NA` when
the entry covers all months) and `text` (the entry as published).
Entries that do not follow the refresh or gap patterns are kept with
`action = NA`.

## See also

Other panel:
[`lamp_adjacency()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency.md),
[`lamp_adjacency_from_nb()`](https://blackthrive.github.io/streetlamp/reference/lamp_adjacency_from_nb.md),
[`lamp_boundaries()`](https://blackthrive.github.io/streetlamp/reference/lamp_boundaries.md),
[`lamp_coverage()`](https://blackthrive.github.io/streetlamp/reference/lamp_coverage.md),
[`lamp_panel()`](https://blackthrive.github.io/streetlamp/reference/lamp_panel.md),
[`lamp_population()`](https://blackthrive.github.io/streetlamp/reference/lamp_population.md),
[`lamp_revintage()`](https://blackthrive.github.io/streetlamp/reference/lamp_revintage.md)

## Examples

``` r
if (FALSE) {
# Requires network access
cl <- lamp_changelog()
cl[cl$force_id == "west-yorkshire", ]
}
```

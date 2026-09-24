# The colours streetlamp draws with

A named vector of the colours every
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) method in the
package uses, so that figures drawn outside the package can match them.
The series colours were chosen and checked as a set for separation under
the common forms of colour vision deficiency; the coverage statuses are
drawn from the same set so that a status never impersonates a series.

## Usage

``` r
lamp_colours()
```

## Value

A named character vector of hex colours. `series` is the main data
colour, `contrast` the second series where a plot has two, `accent` the
colour for the one mark the reader is meant to compare against (the
actual estimate in a placebo distribution), and `neutral` the fill for
marks that carry no identity. The `ink`, `secondary`, `muted`, `grid`,
`baseline`, `surface` and `shade` entries are the text and chrome
colours. The remaining entries are named for coverage statuses.

## See also

Other presentation:
[`lamp_table()`](https://blackthrive.github.io/streetlamp/reference/lamp_table.md),
[`lamp_theme()`](https://blackthrive.github.io/streetlamp/reference/lamp_theme.md)

## Examples

``` r
lamp_colours()[c("series", "contrast", "accent")]
#>    series  contrast    accent 
#> "#2a78d6" "#eb6834" "#d03b3b" 
```

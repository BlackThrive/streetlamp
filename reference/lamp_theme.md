# The ggplot2 theme streetlamp plots use

A quiet theme built on
[`ggplot2::theme_minimal()`](https://ggplot2.tidyverse.org/reference/ggtheme.html):
recessive hairline grid, no minor grid or tick marks, left-aligned
titles, muted axis text, and the legend above the plot. Every
[`plot()`](https://rdrr.io/r/graphics/plot.default.html) method in the
package applies it, and it can be added to any other ggplot.

## Usage

``` r
lamp_theme(base_size = 11)
```

## Arguments

- base_size:

  Base font size in points.

## Value

A ggplot2 theme object.

## See also

Other presentation:
[`lamp_colours()`](https://blackthrive.github.io/streetlamp/reference/lamp_colours.md),
[`lamp_table()`](https://blackthrive.github.io/streetlamp/reference/lamp_table.md)

## Examples

``` r
library(ggplot2)
ggplot(mtcars, aes(wt, mpg)) +
  geom_point(colour = lamp_colours()[["series"]]) +
  labs(title = "Weight and fuel economy") +
  lamp_theme()
```

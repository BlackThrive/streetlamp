# Precompute the vignettes.
#
# Vignettes are shipped already evaluated: each `*.Rmd.orig` is knitted to the
# `*.Rmd` that goes in the package, with results and figures embedded. This
# keeps R CMD check fast and guarantees that nothing in a vignette reaches the
# network at build time, as CRAN policy requires.
#
# Run from the package root after changing any .Rmd.orig:
#   Rscript vignettes/build.R

pkgload::load_all(".", quiet = TRUE)

old <- setwd("vignettes")
on.exit(setwd(old), add = TRUE)
dir.create("figures", showWarnings = FALSE)

for (f in list.files(".", pattern = "\\.Rmd\\.orig$")) {
  out <- sub("\\.orig$", "", f)
  message("knitting ", f)
  knitr::knit(f, out, quiet = TRUE)
}

message("done: ", paste(list.files(".", pattern = "\\.Rmd$"), collapse = ", "))

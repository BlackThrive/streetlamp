# Validation 2: placebo battery on the bundled sample panel
#
# Runs placebo outcomes, dates and areas on real data, where the answer should
# be nothing. A specification that produces effects here produces them
# everywhere, and nothing it says about a real intervention can be believed.
# Writes inst/validation/placebo-battery.csv.
#
#   Rscript inst/scripts/02-placebo-battery.R

suppressMessages(library(streetlamp))

out_dir <- file.path("inst", "validation")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

panel <- lamp_sample_panel()
months <- sort(unique(panel$month))
areas <- sort(unique(panel$area))
message(sprintf("Sample panel: %d areas, %d months", length(areas), length(months)))

# A placebo intervention: half the areas, from the middle of the period. There
# was no such operation, so every estimate below should be indistinguishable
# from zero.
set.seed(2026)
fake_treated <- sample(areas, floor(length(areas) / 2))
fake_date <- months[floor(length(months) / 2)]
tr <- lamp_treatment(panel, "event", date = fake_date, scope = fake_treated)

rows <- list()
record <- function(test, outcome, estimate, lo, hi, p) {
  tibble::tibble(
    test = test, outcome = outcome, estimate = estimate,
    conf_low = lo, conf_high = hi, p_value = p,
    excludes_zero = !is.na(lo) && !is.na(hi) && (lo > 0 || hi < 0)
  )
}

message("1. placebo outcomes: every crime type against a fake intervention")
types <- setdiff(lamp_crime_types()$key, "anti_social_behaviour")
for (ty in types) {
  fit <- try(lamp_twfe(panel, ty, tr), silent = TRUE)
  if (inherits(fit, "try-error")) next
  co <- fit$coefficients
  rows[[length(rows) + 1L]] <- record(
    "placebo outcome", ty, co$estimate[1], co$conf_low[1], co$conf_high[1], co$p_value[1]
  )
}

message("2. placebo dates: the fake intervention moved through the pre-period")
fit_total <- lamp_twfe(panel, "crime_total", tr)
pl_time <- lamp_placebo(fit_total, type = "time", n = 8)
for (i in seq_len(nrow(pl_time$distribution))) {
  rows[[length(rows) + 1L]] <- record(
    "placebo date", pl_time$distribution$label[i],
    pl_time$distribution$estimate[i], NA_real_, NA_real_, NA_real_
  )
}

message("3. placebo areas: the treatment reassigned at random 200 times")
pl_space <- lamp_placebo(fit_total, type = "space", n = 200, seed = 7)
for (i in seq_len(nrow(pl_space$distribution))) {
  rows[[length(rows) + 1L]] <- record(
    "placebo area", sprintf("draw %d", i),
    pl_space$distribution$estimate[i], NA_real_, NA_real_, NA_real_
  )
}

results <- dplyr::bind_rows(rows)
utils::write.csv(results, file.path(out_dir, "placebo-battery.csv"), row.names = FALSE)

by_test <- results |>
  dplyr::group_by(.data$test) |>
  dplyr::summarise(
    n = dplyr::n(),
    mean_estimate = mean(.data$estimate, na.rm = TRUE),
    median_estimate = stats::median(.data$estimate, na.rm = TRUE),
    share_excluding_zero = mean(.data$excludes_zero, na.rm = TRUE),
    .groups = "drop"
  )
print(as.data.frame(by_test), digits = 3)

# The distributions should be centred on zero, and at a 95 percent level
# roughly one in twenty outcome tests should exclude zero by chance.
outcome_rows <- results[results$test == "placebo outcome", ]
message(sprintf(
  "\nPlacebo outcomes: %d of %d exclude zero (expect about 1 in 20 by chance).",
  sum(outcome_rows$excludes_zero), nrow(outcome_rows)
))
message(sprintf(
  "Placebo areas: median %.4f, 5th to 95th percentile %.4f to %.4f.",
  stats::median(pl_space$distribution$estimate, na.rm = TRUE),
  stats::quantile(pl_space$distribution$estimate, 0.05, na.rm = TRUE),
  stats::quantile(pl_space$distribution$estimate, 0.95, na.rm = TRUE)
))
utils::write.csv(by_test, file.path(out_dir, "placebo-summary.csv"), row.names = FALSE)
message("written ", file.path(out_dir, "placebo-summary.csv"))

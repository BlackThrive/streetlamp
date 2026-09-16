# Build inst/extdata/bank_holidays.csv (England and Wales) from GOV.UK.
#
# Run manually with network access from the package root; never at build,
# check or test time. Verified 2026-09-16; see inst/NOTES/data_sources.md.
#
# Sources:
#   live      https://www.gov.uk/bank-holidays.json, division england-and-wales
#             (covered 2019-01-01 to 2028-12-26 at retrieval).
#   archived  Internet Archive captures of the same feed, used for 2012-2018
#             because the live feed drops past years. The "id_" flag returns
#             the original bytes without archive rewriting.
#   directgov Directgov "Bank holidays and British Summer Time", capture of
#             2011-01-06, for 2010 and 2011 (the feed starts at 2012).
#             Transcribed by hand from the England and Wales table.
#
# Apostrophes (U+2019 in the feed) are normalised to ASCII.

live_url <- "https://www.gov.uk/bank-holidays.json"
archived <- c(
  "2014-12-24" = "https://web.archive.org/web/20141224183209id_/https://www.gov.uk/bank-holidays.json",
  "2016-12-29" = "https://web.archive.org/web/20161229052951id_/https://www.gov.uk/bank-holidays.json",
  "2018-12-03" = "https://web.archive.org/web/20181203062756id_/https://www.gov.uk/bank-holidays.json"
)
directgov_url <- paste0(
  "https://web.archive.org/web/20110106104158/http://www.direct.gov.uk/",
  "en/Governmentcitizensandrights/LivingintheUK/DG_073741"
)

read_feed <- function(url, source, source_url = url) {
  txt <- httr2::request(url) |>
    httr2::req_user_agent("streetlamp data-raw") |>
    httr2::req_retry(max_tries = 3) |>
    httr2::req_perform() |>
    httr2::resp_body_string()
  js <- jsonlite::fromJSON(txt)
  ev <- js[["england-and-wales"]][["events"]]
  data.frame(
    date = as.Date(ev$date),
    title = gsub("’", "'", ev$title),
    notes = ifelse(is.na(ev$notes) | ev$notes == "", NA_character_, ev$notes),
    bunting = as.logical(ev$bunting),
    source = source,
    source_url = source_url,
    stringsAsFactors = FALSE
  )
}

live <- read_feed(live_url, "gov.uk bank-holidays.json")
arch <- lapply(names(archived), function(d) {
  read_feed(archived[[d]], sprintf("gov.uk bank-holidays.json (archived %s)", d))
})

# Prefer the live feed, then the most recent archive, for each date.
all_rows <- rbind(live, do.call(rbind, rev(arch)))
dup <- duplicated(all_rows$date)
conflicts <- all_rows[all_rows$date %in% all_rows$date[dup], ]
by_date <- split(conflicts$title, conflicts$date)
disagree <- names(by_date)[vapply(by_date, function(t) length(unique(t)) > 1L, logical(1))]
if (length(disagree) > 0L) {
  print(conflicts[conflicts$date %in% disagree, ])
  stop("Feeds disagree on the title for the dates above")
}
feed <- all_rows[!dup, ]

directgov <- data.frame(
  date = as.Date(c(
    "2010-01-01", "2010-04-02", "2010-04-05", "2010-05-03", "2010-05-31",
    "2010-08-30", "2010-12-27", "2010-12-28",
    "2011-01-03", "2011-04-22", "2011-04-25", "2011-04-29", "2011-05-02",
    "2011-05-30", "2011-08-29", "2011-12-26", "2011-12-27"
  )),
  title = c(
    "New Year's Day", "Good Friday", "Easter Monday", "Early May bank holiday",
    "Spring bank holiday", "Summer bank holiday", "Christmas Day", "Boxing Day",
    "New Year's Day", "Good Friday", "Easter Monday", "Royal wedding",
    "Early May bank holiday", "Spring bank holiday", "Summer bank holiday",
    "Christmas Day", "Boxing Day"
  ),
  notes = c(
    NA, NA, NA, NA, NA, NA, "Substitute day", "Substitute day",
    "Substitute day", NA, NA, "Extra bank holiday", NA, NA, NA,
    "Substitute day", "Substitute day"
  ),
  bunting = NA,
  source = "Directgov (archived 2011-01-06), transcribed",
  source_url = directgov_url,
  stringsAsFactors = FALSE
)
stopifnot(!any(directgov$date %in% feed$date))

bh <- rbind(directgov, feed)
bh <- bh[order(bh$date), ]
rownames(bh) <- NULL

stopifnot(
  !anyDuplicated(bh$date),
  min(bh$date) == as.Date("2010-01-01"),
  max(bh$date) >= as.Date("2026-12-28"),
  # every year from 2010 to 2026 has at least the eight standard holidays
  all(table(format(bh$date, "%Y"))[as.character(2010:2026)] >= 8L),
  as.Date("2011-04-29") %in% bh$date,
  as.Date("2022-09-19") %in% bh$date,
  as.Date("2023-05-08") %in% bh$date
)

dir.create(file.path("inst", "extdata"), showWarnings = FALSE, recursive = TRUE)
readr::write_csv(bh, file.path("inst", "extdata", "bank_holidays.csv"), na = "")
cat("written", nrow(bh), "rows,", min(bh$date), "to", max(bh$date), "\n")
print(table(format(bh$date, "%Y")))

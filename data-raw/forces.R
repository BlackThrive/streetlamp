# Build inst/extdata/forces.csv: police.uk force identifiers joined to ONS
# police force area codes.
#
# Run manually with network access from the package root; never at build,
# check or test time. Verified 2026-09-16; see inst/NOTES/data_sources.md.
#
# Sources:
#   police.uk API   https://data.police.uk/api/forces (44 forces: 43
#                   territorial forces plus the Police Service of Northern
#                   Ireland; British Transport Police is absent and is added
#                   by hand because its files are in the archive).
#   ONS             Police Force Areas (December 2025) Names and Codes in the
#                   UK, item ff7c3ac78cc647f6b103166a65e31c44, read from the
#                   FeatureServer PFA_DEC_2025_UK_NC (Hub CSV download 404s).

dl_dir <- file.path("data-raw", "downloads")
dir.create(dl_dir, showWarnings = FALSE, recursive = TRUE)

forces_path <- file.path(dl_dir, "police-uk-forces.json")
if (!file.exists(forces_path)) {
  httr2::request("https://data.police.uk/api/forces") |>
    httr2::req_user_agent("streetlamp data-raw") |>
    httr2::req_perform(path = forces_path)
}
pfa_path <- file.path(dl_dir, "pfa-dec-2025-names-codes.json")
if (!file.exists(pfa_path)) {
  httr2::request(paste0(
    "https://services1.arcgis.com/ESMARspQHYMw9BZ9/arcgis/rest/services/",
    "PFA_DEC_2025_UK_NC/FeatureServer/0/query"
  )) |>
    httr2::req_url_query(where = "1=1", outFields = "*", returnGeometry = "false", f = "json") |>
    httr2::req_user_agent("streetlamp data-raw") |>
    httr2::req_perform(path = pfa_path)
}

api <- jsonlite::fromJSON(forces_path)
pfa <- jsonlite::fromJSON(pfa_path)$features$attributes[, c("PFA25CD", "PFA25NM")]

# police.uk name -> ONS PFA name
pfa_name <- sub(" (Police Service|Constabulary|Police)$", "", api$name)
pfa_name[api$id == "city-of-london"] <- "London, City of"
pfa_name[api$id == "metropolitan"] <- "Metropolitan Police"
pfa_name[api$id == "northern-ireland"] <- "Police Service of Northern Ireland"

forces <- data.frame(
  force_id = api$id,
  name = api$name,
  pfa_name = pfa_name,
  stringsAsFactors = FALSE
)
forces$pfa_code <- pfa$PFA25CD[match(forces$pfa_name, pfa$PFA25NM)]
stopifnot(!anyNA(forces$pfa_code))
forces$country <- ifelse(
  startsWith(forces$pfa_code, "E"), "england",
  ifelse(startsWith(forces$pfa_code, "W"), "wales", "northern_ireland")
)
forces$notes <- NA_character_
forces$notes[forces$force_id == "greater-manchester"] <-
  "No data submitted since 2019; absent from recent archive snapshots."
forces$notes[forces$force_id == "northern-ireland"] <-
  "Street files from September 2011; no outcomes data."

btp <- data.frame(
  force_id = "btp", name = "British Transport Police", pfa_name = NA_character_,
  pfa_code = NA_character_, country = NA_character_,
  notes = paste(
    "No police force area. Records carry British Transport Police in both",
    "Reported by and Falls within; no outcomes data."
  ),
  stringsAsFactors = FALSE
)
forces <- rbind(forces, btp)
forces <- forces[order(forces$force_id), c("force_id", "name", "pfa_code", "pfa_name", "country", "notes")]
rownames(forces) <- NULL

stopifnot(
  nrow(forces) == 45L,
  !anyDuplicated(forces$force_id),
  all(grepl("^[a-z]+(-[a-z]+)*$", forces$force_id)),
  sum(forces$country == "england", na.rm = TRUE) == 39L,
  sum(forces$country == "wales", na.rm = TRUE) == 4L
)
readr::write_csv(forces, file.path("inst", "extdata", "forces.csv"), na = "")
cat("written", nrow(forces), "forces\n")

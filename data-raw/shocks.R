# Build inst/extdata/shocks.csv: dated national policy and environment shocks
# relevant to police stop and search and recorded crime in England and Wales.
#
# Every date below was verified against the source_url on the `verified` date
# by fetching the page and quoting the sentence that establishes it; the
# quotes are recorded in inst/NOTES/data_sources.md. Events whose dates could
# not be verified from a fetched primary source are deliberately excluded and
# listed there as candidates.
#
# Run manually from the package root (no network needed; the table is
# curated here). Never run at build, check or test time.

verified <- as.Date("2026-09-16")

shock <- function(name, label, kind, start, end = NA, scope = "national",
                  forces = NA, source_url, notes) {
  data.frame(
    name = name, label = label, kind = kind,
    start = as.Date(start), end = as.Date(end),
    scope = scope, forces = forces, source_url = source_url, notes = notes,
    verified = verified, stringsAsFactors = FALSE
  )
}

ifg_timeline <- paste0(
  "https://www.instituteforgovernment.org.uk/sites/default/files/2022-12/",
  "timeline-coronavirus-lockdown-december-2021.pdf"
)
ons_july_2015 <- paste0(
  "https://www.ons.gov.uk/peoplepopulationandcommunity/crimeandjustice/",
  "bulletins/crimeinenglandandwales/2015-07-16"
)

shocks <- rbind(
  shock(
    "riots_2011", "August 2011 riots", "disorder",
    "2011-08-06", "2011-08-09", "forces",
    "metropolitan;west-midlands;greater-manchester;merseyside;nottinghamshire",
    "https://www.gov.uk/government/statistics/statistical-bulletin-on-the-public-disorder-of-6th-9th-august-2011--2",
    paste(
      "Ministry of Justice bulletin: disorder began on 6 August 2011, mainly",
      "in London on 7 and 8 August and mainly outside London on 9 August.",
      "The Home Office recorded 5,175 crimes across 19 forces; only the five",
      "forces named in the court statistics are listed here."
    )
  ),
  shock(
    "uksa_recorded_crime_dedesignation",
    "UK Statistics Authority removes National Statistics status from police recorded crime",
    "recording_practice", "2014-01-15", NA, "national", NA,
    ons_july_2015,
    paste(
      "Followed by a national drive to improve compliance with the National",
      "Crime Recording Standard; later rises in recorded violence and sexual",
      "offences partly reflect recording. Day taken from the ACPO response",
      "dated 15 January 2014."
    )
  ),
  shock(
    "stop_search_reform_announcement",
    "Home Secretary announces stop and search reform package",
    "stop_search_policy", "2014-04-30", NA, "national", NA,
    "https://www.gov.uk/government/speeches/stop-and-search-comprehensive-package-of-reform-for-police-stop-and-search-powers",
    paste(
      "Oral statement by Theresa May: PACE Code A to be revised on reasonable",
      "grounds for suspicion, and the Best Use of Stop and Search Scheme to",
      "be launched that summer."
    )
  ),
  shock(
    "buss_launch", "Best Use of Stop and Search Scheme launched",
    "stop_search_policy", "2014-08-26", "2021-07-27", "national", NA,
    "https://www.gov.uk/government/publications/best-use-of-stop-and-search-scheme",
    paste(
      "Voluntary Home Office and College of Policing scheme. Its Section 60",
      "conditions were suspended by the 2019 pilots and, per the scheme page,",
      "no longer in place after the Beating Crime Plan of 27 July 2021, which",
      "is the end date used here; other elements (outcome recording, lay",
      "observation, complaint triggers) remain."
    )
  ),
  shock(
    "hmic_crime_data_integrity_report",
    "HMIC crime data integrity final report published",
    "recording_practice", "2014-11-18", NA, "national", NA,
    ons_july_2015,
    paste(
      "Crime-recording: making the victim count estimated that 19 percent of",
      "crimes that should have been recorded were not; subsequent rises in",
      "recorded crime reflect improved compliance."
    )
  ),
  shock(
    "pace_code_a_2015",
    "Revised PACE Code A (reasonable grounds for suspicion) in force",
    "stop_search_policy", "2015-03-19", "2023-01-16", "national", NA,
    "https://www.gov.uk/government/publications/pace-code-a-2015",
    "Superseded by PACE Code A 2023 on 17 January 2023."
  ),
  shock(
    "hocr_24_hour_recording",
    "Home Office Counting Rules require crimes to be recorded within 24 hours",
    "recording_practice", "2015-04-01", NA, "national", NA,
    "https://www.gov.uk/government/statistics/crime-outcomes-in-england-and-wales-2025-to-2026/crime-outcomes-in-england-and-wales-technical-annex",
    paste(
      "Previously 72 hours. The source states since April 2015; the day of",
      "the month is assumed to be the first."
    )
  ),
  shock(
    "serious_violence_strategy", "Serious Violence Strategy launched",
    "crime_policy", "2018-04-09", NA, "national", NA,
    "https://www.gov.uk/government/news/home-secretary-to-launch-serious-violence-strategy",
    paste(
      "GBP 40 million of Home Office funding; precedes the 2019 surge",
      "funding and Violence Reduction Units."
    )
  ),
  shock(
    "met_violent_crime_task_force",
    "Metropolitan Police Violent Crime Task Force created",
    "stop_search_policy", "2018-04-01", NA, "forces", "metropolitan",
    "https://www.london.gov.uk/who-we-are/what-london-assembly-does/questions-mayor/find-an-answer/violence-taskforce",
    paste(
      "Mayor's Question answer states the task force was created in April",
      "2018; the day of the month is assumed to be the first."
    )
  ),
  shock(
    "s60_pilot_seven_forces",
    "Section 60 authorisation conditions relaxed in seven pilot forces",
    "stop_search_policy", "2019-04-01", "2019-08-10", "forces",
    "metropolitan;west-midlands;greater-manchester;merseyside;south-yorkshire;west-yorkshire;south-wales",
    "https://www.gov.uk/government/publications/research-into-the-section-60-stop-and-search-pilot/the-section-60-stop-and-search-pilot-statistical-analysis-and-review-of-authorisations",
    paste(
      "Announced 31 March 2019; authorisation lowered from chief officer to",
      "inspector and the threshold from serious violence will occur to may",
      "occur. Superseded by the national extension on 11 August 2019."
    )
  ),
  shock(
    "serious_violence_fund_surge",
    "Serious Violence Fund surge funding allocated to 18 forces",
    "crime_policy", "2019-04-17", NA, "forces",
    paste(
      "metropolitan;west-midlands;greater-manchester;merseyside;west-yorkshire;",
      "south-yorkshire;northumbria;thames-valley;lancashire;essex;",
      "avon-and-somerset;kent;nottinghamshire;leicestershire;bedfordshire;",
      "sussex;hampshire;south-wales",
      sep = ""
    ),
    "https://www.gov.uk/government/news/police-granted-funding-boost-for-action-on-serious-violence",
    paste(
      "GBP 51 million announced on 17 April 2019 for increased enforcement",
      "including stop and search; force list and amounts published on 8 May",
      "2019. The end of the funding period is not stated."
    )
  ),
  shock(
    "s60_relaxation_all_forces",
    "Section 60 relaxation extended to all forces; BUSS Section 60 conditions lifted",
    "stop_search_policy", "2019-08-11", NA, "national", NA,
    "https://www.gov.uk/government/news/government-lifts-emergency-stop-and-search-restrictions",
    paste(
      "All 43 forces and British Transport Police: inspector authorisation,",
      "may rather than will threshold, initial period 15 to 24 hours,",
      "maximum extension 39 to 48 hours. Made permanent by the Beating Crime",
      "Plan of 27 July 2021 and restated on 16 May 2022."
    )
  ),
  shock(
    "covid_england_lockdown_1",
    "COVID-19 first national lockdown (stay at home), England",
    "covid", "2020-03-23", "2020-05-31", "england", NA,
    ifg_timeline,
    paste(
      "Announced 23 March 2020 and legally in force from 26 March.",
      "Leaving-home rules widened on 13 May; the stay-at-home requirement was",
      "replaced by an overnight-stay ban from 1 June 2020 (the end used",
      "here); shops reopened 15 June and hospitality 4 July 2020."
    )
  ),
  shock(
    "covid_england_lockdown_2",
    "COVID-19 second national lockdown, England",
    "covid", "2020-11-05", "2020-12-02", "england", NA,
    ifg_timeline,
    paste(
      "Preceded by the rule of six (14 September) and the three-tier system",
      "(14 October 2020); followed by a stricter tier system from 2 December."
    )
  ),
  shock(
    "covid_london_tier_4",
    "COVID-19 Tier 4 stay-at-home restrictions, London and the South East",
    "covid", "2020-12-20", "2021-01-05", "forces", "metropolitan;city-of-london",
    "https://www.gov.uk/government/speeches/prime-ministers-statement-on-coronavirus-covid-19-19-december-2020",
    paste(
      "Applied to tier-3 areas of London, the South East and the East of",
      "England from 20 December 2020 (the Institute for Government gives 21",
      "December); more areas added on 26 December. Only the London forces",
      "are listed because the source names regions, not forces. Merged into",
      "the third national lockdown on 6 January 2021."
    )
  ),
  shock(
    "covid_england_lockdown_3",
    "COVID-19 third national lockdown, England",
    "covid", "2021-01-06", "2021-03-28", "england", NA,
    ifg_timeline,
    paste(
      "Schools reopened 8 March; the stay-at-home order ended 29 March 2021",
      "(the end used here); step 2 on 12 April, step 3 on 17 May and step 4",
      "(most legal limits removed) on 19 July 2021."
    )
  ),
  shock(
    "covid_england_plan_b", "COVID-19 Plan B measures, England",
    "covid", "2021-12-10", "2022-01-26", "england", NA,
    "https://www.gov.uk/government/news/england-to-return-to-plan-a-following-the-success-of-the-booster-programme",
    paste(
      "Face coverings from 10 December and the NHS COVID Pass from 15",
      "December 2021; lifted from 27 January 2022. All remaining domestic",
      "legal restrictions ended on 24 February 2022."
    )
  ),
  shock(
    "covid_wales_lockdown_1", "COVID-19 first lockdown, Wales",
    "covid", "2020-03-23", "2020-05-31", "wales", NA,
    "https://www.gov.wales/stay-local-to-keep-wales-safe",
    paste(
      "UK-wide stay-at-home from 23 March 2020; replaced in Wales by a",
      "stay-local (five-mile) rule from 1 June 2020."
    )
  ),
  shock(
    "covid_wales_stay_local_2020", "COVID-19 stay-local rule, Wales",
    "covid", "2020-06-01", "2020-07-05", "wales", NA,
    "https://www.gov.wales/stay-local-to-be-lifted-in-wales",
    paste(
      "Non-essential retail reopened 22 June; stay-local lifted 6 July;",
      "outdoor hospitality from 13 July 2020."
    )
  ),
  shock(
    "covid_wales_firebreak", "COVID-19 firebreak lockdown, Wales",
    "covid", "2020-10-23", "2020-11-08", "wales", NA,
    "https://www.gov.wales/national-coronavirus-fire-break-to-be-introduced-in-wales-on-friday",
    paste(
      "From 6pm on Friday 23 October to Monday 9 November 2020, when new",
      "national measures replaced it."
    )
  ),
  shock(
    "covid_wales_alert_level_4", "COVID-19 alert level 4 (stay at home), Wales",
    "covid", "2020-12-20", "2021-03-12", "wales", NA,
    "https://www.gov.wales/written-statement-alert-level-four-restrictions",
    paste(
      "From midnight on 19 to 20 December 2020; stay-at-home replaced by",
      "stay-local on 13 March 2021 (the end used here) and lifted 27 March;",
      "alert level 3 from 3 May and alert level 0 from 7 August 2021."
    )
  ),
  shock(
    "covid_wales_alert_level_2_omicron", "COVID-19 alert level 2 (Omicron), Wales",
    "covid", "2021-12-26", "2022-01-27", "wales", NA,
    "https://www.gov.wales/strengthened-measures-to-keep-wales-safe-as-omicron-strikes",
    "From 6am on 26 December 2021; the move to alert level 0 completed on 28 January 2022."
  ),
  shock(
    "beating_crime_plan_s60_permanent",
    "Beating Crime Plan: Section 60 relaxation made permanent",
    "stop_search_policy", "2021-07-27", NA, "national", NA,
    "https://www.gov.uk/government/publications/beating-crime-plan",
    paste(
      "The BUSS page records that the voluntary Section 60 conditions are no",
      "longer in place following this announcement. A Home Secretary letter",
      "of 16 May 2022 also describes removing the 2014 restrictions;",
      "operational conditions had applied nationally since 11 August 2019."
    )
  ),
  shock(
    "home_secretary_s60_letter_2022",
    "Home Secretary letter removing 2014 Section 60 restrictions; PACE Code A consultation opens",
    "stop_search_policy", "2022-05-16", NA, "national", NA,
    "https://www.gov.uk/government/news/home-secretary-backs-police-to-increase-stop-and-search",
    paste(
      "Restates the permanent removal of the BUSS Section 60 conditions",
      "(see beating_crime_plan_s60_permanent); the Code A consultation ran",
      "from 16 May to 27 June 2022."
    )
  ),
  shock(
    "pcsc_act_royal_assent",
    "Police, Crime, Sentencing and Courts Act 2022 receives Royal Assent",
    "crime_policy", "2022-04-28", NA, "national", NA,
    "https://www.legislation.gov.uk/ukpga/2022/32/introduction",
    paste(
      "Creates Serious Violence Reduction Orders (sections 165 to 170,",
      "commenced for the pilot only) and the Serious Violence Duty."
    )
  ),
  shock(
    "pace_code_a_2023", "PACE Code A 2023 in force",
    "stop_search_policy", "2023-01-17", NA, "national", NA,
    "https://www.gov.uk/government/publications/pace-code-a-2015",
    "Adds the Serious Violence Reduction Order annex; supersedes Code A 2015."
  ),
  shock(
    "serious_violence_duty", "Serious Violence Duty commenced",
    "crime_policy", "2023-01-31", NA, "national", NA,
    "https://www.legislation.gov.uk/uksi/2022/1227/regulation/4/made",
    paste(
      "Sections 8 to 21 of the Police, Crime, Sentencing and Courts Act",
      "2022: duty on specified authorities to collaborate to prevent and",
      "reduce serious violence."
    )
  ),
  shock(
    "svro_pilot", "Serious Violence Reduction Orders pilot",
    "stop_search_policy", "2023-04-19", "2025-04-18", "forces",
    "merseyside;thames-valley;sussex;west-midlands",
    "https://www.legislation.gov.uk/uksi/2023/387/made",
    paste(
      "Court orders permitting suspicionless search of the subject, piloted",
      "for 24 months in four police areas; the search power is exercisable",
      "anywhere in England and Wales. Live orders were phased out to 17",
      "October 2025."
    )
  ),
  shock(
    "public_order_act_2023_protest_search",
    "Public Order Act 2023 protest-related stop and search powers in force",
    "stop_search_policy", "2023-12-20", NA, "national", NA,
    "https://www.legislation.gov.uk/uksi/2023/1418/regulation/2/made",
    paste(
      "Sections 10 (with suspicion) and 11 (without suspicion) commenced by",
      "SI 2023/1418; the earlier commencement on 2 July 2023 covered other",
      "sections only."
    )
  )
)

shocks <- shocks[order(shocks$start, shocks$name), ]
rownames(shocks) <- NULL

stopifnot(
  !anyDuplicated(shocks$name),
  all(grepl("^[a-z0-9_]+$", shocks$name)),
  !anyNA(shocks$start),
  all(is.na(shocks$end) | shocks$end >= shocks$start),
  all(shocks$kind %in% c(
    "stop_search_policy", "crime_policy", "covid", "recording_practice",
    "disorder"
  )),
  all(shocks$scope %in% c("national", "england", "wales", "forces")),
  all(!is.na(shocks$forces[shocks$scope == "forces"])),
  all(is.na(shocks$forces[shocks$scope != "forces"])),
  all(grepl("^https://", shocks$source_url)),
  all(grepl(
    "^[a-z]+(-[a-z]+)*(;[a-z]+(-[a-z]+)*)*$",
    shocks$forces[!is.na(shocks$forces)]
  ))
)

dir.create(file.path("inst", "extdata"), showWarnings = FALSE, recursive = TRUE)
readr::write_csv(shocks, file.path("inst", "extdata", "shocks.csv"), na = "")
cat("written", nrow(shocks), "shocks\n")
print(table(shocks$kind))

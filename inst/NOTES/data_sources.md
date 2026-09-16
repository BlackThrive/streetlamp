# Data sources: verification record

Every external source streetlamp relies on, what was checked, how, and when.
Update this file whenever a source is re-verified or a discrepancy with the
specification is found (specification section 12.2). Items marked
`TODO(source)` are still to be verified at the milestone named.

## 1. data.police.uk (Open Government Licence v3.0)

### 1.1 About page, <https://data.police.uk/about/> (verified 2026-09-16)

Fetched the raw HTML and read the relevant sections.

- Crime and ASB records are "Assigned into one of 14 categories. A complete
  mapping between Home Office Offence Codes and Categories can be downloaded
  here", linking to
  <https://data.police.uk/static/files/police-uk-category-mappings.csv>
  (1,486 rows plus header at retrieval; columns Home Office Code, Sub Class,
  Offence, Police.uk Category; category labels there are in Title Case, the
  street CSV files use sentence case).
- LSOA field: "References to the Lower Layer Super Output Area that the
  anonymised point falls into, according to the LSOA boundaries provided by
  the Office for National Statistics." No vintage is stated on the page; the
  changelog (section 1.4) records the switch from 2011 to 2021 LSOAs in June
  2023.
- Location anonymisation: coordinates are snapped to a master list of points,
  each with a catchment of at least eight postal addresses or none. "The snap
  points list was created in 2012 and based on Ordnance Survey population and
  housing developments relevant to that year. The snap points list was
  refreshed in 2022 using more recent data from the same sources."
  Consequence for the package: point locations, and therefore LSOA
  assignment at the margin, are not comparable across the July 2022 refresh.
- "Falls within: At present, also the force that provided the data about the
  crime. This is currently being looked into and is likely to change in the
  near future."
- Time period covered on the live site at retrieval: crime and outcomes
  "August 2023 to July 2026"; stop and search "December 2014 to July 2026".
  Earlier months come only from the archive (section 1.5).
- Outcomes: "Neither the British Transport Police nor the Police Service of
  Northern Ireland provide outcome data." Court outcomes are matched by the
  Ministry of Justice.
- Data refreshes: forces occasionally re-supply whole months ("This is fairly
  rare"); the changelog lists them by force and month.
- Licence statement on the page: "Open Government Licence v3.0".

### 1.2 Crime categories, <https://data.police.uk/api/crime-categories?date=YYYY-MM> (verified 2026-09-16)

Queried for 2010-12, 2011-06, 2012-06, 2013-05, 2013-06, 2014-01, 2019-01,
2023-06 and 2026-07. Every query returned the same fifteen entries: `all-crime`
plus the fourteen categories bundled in `lamp_crime_types()`, with
`violent-crime` named "Violence and sexual offences". The API therefore does
not expose the pre-June-2013 category set, which the changelog describes:

> June 2013: New crime category 'bicycle theft' introduced (previously included
> in 'other theft'). New crime category 'theft from the person' introduced
> (previously included in 'other theft'). New crime categories 'possession of
> weapons' and 'public order' introduced (previously amalgamated together in
> 'public disorder and weapons'). Renamed crime category from 'violent crime'
> to 'violent crime and sexual offences', for clarity. Introduction of CSV
> bulk-download functionality.

Verified against Dyfed-Powys street files in the 2017-04 and 2013-12
archives (2026-09-16): three category sets in the archive.

| Data months | Categories | Labels |
|---|---|---|
| 2010-12 to 2011-08 | six | Anti-social behaviour, Burglary, Other crime, Robbery, Vehicle crime, Violent crime |
| 2011-09 to 2013-04 | eleven | the six plus Criminal damage and arson, Drugs, Other theft, Public disorder and weapons, Shoplifting |
| 2013-05 onwards | fourteen | the current set |

The June 2013 changelog entry therefore applies from the May 2013 data month.
`lamp_read_crime()` renames "Violent crime" to "Violence and sexual offences",
keeps "Public disorder and weapons" as its own level, and records each file's
category set in the contract. The switch months were checked for one force
only; other forces are assumed to have changed at the same time because the
categories are assigned centrally from Home Office offence codes.

### 1.3 Outcome categories, <https://data.police.uk/docs/method/outcomes-for-crime/> (verified 2026-09-16)

Fetched the raw HTML. The documented code and name pairs (28) are those in
`lamp_outcome_types()`, with one discrepancy found in the archive files
(West Yorkshire and Dyfed-Powys outcomes, May to July 2026, 76,000 rows): the
CSV writes `Offender given penalty notice` where the documentation says
`Offender given a penalty notice`. The table uses the CSV string and keeps
the API name as `api_name`. Ten of the 28 categories were seen in those
files; the court-outcome categories were absent, consistent with the
changelog note that court outcomes are unavailable from June 2019. Every
`Last outcome category` string in the street files matched the table. The
grouping into six classes is the package's own and is documented in that help
page. The note "Outcomes are not available for the Police Service of Northern
Ireland" appears on the page.

### 1.4 Changelog, <https://data.police.uk/changelog/> (verified 2026-09-16)

Entries run from January 2013 to July 2026. Verbatim entries used:

- July 2022: "Snap point data refreshed for July 2022."
- June 2023: "The LSOA data has been updated from the 2011 data to the 2021
  data."
- Known issues (undated, current): "Court outcomes from June 2019 onwards are
  currently unavailable. We are working with the MoJ to provide this data over
  the coming months."
- Known issues (undated, current): "Greater Manchester Police: Currently no
  crime, outcome or stop and search data is available. The force is
  progressing towards a new IT system and data processes which will support
  provision of data to police.uk in the future." Monthly entries "Greater
  Manchester Police: Crime data not provided for <month>" run from at least
  March 2025 to July 2026.
- Stop and search and crime data refreshes by force are listed monthly, for
  example "British Transport Police: Crime data refresh from December 2021 to
  October 2023."

Verified 2026-09-16 by matching codes in Dyfed-Powys street files against the
bundled code lists: archives keep each month at the vintage it was first
published with. In the 2023-12 archive, the 2021-01 file uses 2011 codes
(11 codes found only in the 2011 list, none only in 2021) and the 2023-06 file
uses 2021 codes; in the 2026-07 archive every month (2023-08 onwards) uses
2021 codes. One archive can therefore mix vintages, and `lamp_lsoa_vintage()`
runs per file. Very small files can lack any vintage-specific code (City of
London, July 2026: 26 distinct codes, none decisive); the reader then falls
back to the data month, with 2023-06 as the first 2021-vintage month, and
records `vintage_basis = "month"`.

### 1.5 Archive index, <https://data.police.uk/data/archive/> (verified 2026-09-16)

- "These archives were not being generated before December 2013." Links exist
  for `2013-12.zip` through `2026-07.zip` plus `latest.zip` (154 zip links
  including `neighbourhood.zip`); MD5 sums are provided.
- Each zip is described with its data range. Archives up to spring 2017 hold
  the full history (for example "Contains data from Dec 2010 to Apr 2017");
  later archives hold a rolling 36 months (`2026-07.zip`: "Contains data from
  Aug 2023 to Jul 2026"; `2018-03.zip`: "Apr 2015 to Mar 2018").
- "With the exception of the latest month's archive, the data on this page is
  out of date and should not be used." streetlamp uses older archives
  deliberately, to obtain months outside the rolling window and to record
  version differences; the panel contract records which archive supplied
  each force-month.

Verified 2026-09-16 by reading the zip central directories over HTTP byte
ranges (the zips redirect to `https://policeuk-data.s3.amazonaws.com/archive/`,
which honours `Range` requests with 206 responses):

- Layout: every member is `YYYY-MM/YYYY-MM-<force>-<type>.csv` with type
  `street`, `outcomes` or `stop-and-search`; no other members. All members are
  DEFLATE-compressed; no ZIP64 structures (the largest zip, 2017-04, is
  2.56 GB).
- Window: `2017-04.zip` holds 77 months (2010-12 to 2017-04); `2017-05.zip`
  holds 36 months (2014-06 to 2017-05). The rolling 36-month window therefore
  begins with the May 2017 snapshot. `2013-12.zip` holds 37 months.
- File types by month: street files from 2010-12; outcomes files from 2012-01;
  stop-and-search files from 2014-04 (Hampshire first, then others). The
  2013-12 archive has no stop-and-search files at all.
- Forces: 45 identifiers in older archives (43 territorial forces, `btp`,
  `northern-ireland`); 44 in the 2026-07 archive because `greater-manchester`
  is absent. Northern Ireland street files begin in 2011-09 (44 street files
  per month before, 45 after).
- Street columns: Crime ID, Month, Reported by, Falls within, Longitude,
  Latitude, Location, LSOA code, LSOA name, Crime type, Last outcome category,
  Context (as the specification expected). Outcomes columns: Crime ID, Month,
  Reported by, Falls within, Longitude, Latitude, Location, LSOA code, LSOA
  name, Outcome type.
- Sizes: the 2026-07 archive is 1.73 GB with 4,485 members; a West Yorkshire
  street file is about 6 MB uncompressed (26,000 rows), Dyfed-Powys about
  1 MB (4,400 rows).

### 1.6 Stop-and-search files (verified 2026-09-16)

Columns: Type, Date, Part of a policing operation, Policing operation,
Latitude, Longitude, Gender, Age range, Self-defined ethnicity,
Officer-defined ethnicity, Legislation, Object of search, Outcome, Outcome
linked to object of search, Removal of more than just outer clothing.
streetlamp reads only Date, Latitude, Longitude and Legislation.

- `Date` is ISO 8601 with offset, for example `2026-07-01T00:40:00+00:00`.
  The offset is always `+00:00`, including in summer, yet a few rows in each
  summer-month file are dated between 23:00 and 23:59 on the last day of the
  previous month (West Yorkshire May 2026: 6 of 1,659; June 2026: 5 of
  1,466; July 2026: none), which is what local British Summer Time stored as
  UTC looks like at the month boundary. `lamp_read_stop_counts()` therefore
  dates every stop by its file's month and reports the count of such rows.
- Legislation values seen: `Police and Criminal Evidence Act 1984 (section
  1)`, `Misuse of Drugs Act 1971 (section 23)`, `Firearms Act 1968 (section
  47)`, `Psychoactive Substances Act 2016 (s36(2))`, `Criminal Justice and
  Public Order Act 1994 (section 60)` (Metropolitan Police, July 2026: 17
  rows), and empty. The Section 60 string is bundled as
  `lamp_s60_legislation()`. Dyfed-Powys November 2025 had Legislation empty
  on every row.
- About 4 to 5 percent of searches have no coordinates (West Yorkshire July
  2026: 58 of 1,532) and cannot be assigned to an area; they are counted as
  `stops_no_location`.
- Dyfed-Powys submitted no stop-and-search file for December 2025 to July
  2026 although its street and outcomes files are present; this is the
  mismatched-file-type case the coverage audit must flag.

### 1.7 Force attribution: British Transport Police (discrepancy)

The specification says BTP records fall within territorial force areas. In
the archive (BTP street file for January 2025, 3,304 rows) every row has
`British Transport Police` in both `Reported by` and `Falls within`, so
counting by `Falls within` attributes BTP records to BTP, not to territorial
forces. Location-based assignment (LSOA code) is the way to place them
geographically. BTP street files also stop at January 2025 in the 2026-07
archive (18 months present of 36), and 103 of 3,304 rows have no LSOA.
Records can also sit outside the submitting force's area: Dyfed-Powys July
2026 includes crimes located in Barnet and Birmingham LSOAs.

### 1.8 Version differences between archive snapshots (verified 2026-09-16)

The same force-month file differs between consecutive snapshots:

| File | 2026-06 snapshot | 2026-07 snapshot | Difference |
|---|---|---|---|
| Dyfed-Powys 2026-05 street | 4,053 rows | 4,053 rows | 459 rows changed Last outcome category |
| West Yorkshire 2026-05 street | 26,103 rows | 26,103 rows | 2,275 outcome changes |
| West Yorkshire 2026-05 outcomes | 20,811 rows | 20,801 rows | 10 crime ids only in the older snapshot |
| West Yorkshire 2026-06 outcomes | 21,955 rows | 21,945 rows | 10 crime ids only in the older snapshot |
| West Yorkshire 2026-05 stop-and-search | identical | identical | same CRC |

Street files therefore differ almost always (outcome updates), so checksums
alone do not indicate a re-supplied month; `lamp_version_diff()` compares
row counts and crime-id sets. Outcomes files can lose rows in later
snapshots.

### 1.9 Other field facts (Dyfed-Powys July 2026 street and outcomes files)

- Every anti-social behaviour row (609) has an empty Crime ID and empty Last
  outcome category; no non-ASB row lacks an id; no duplicated ids in a street
  file.
- Rows without coordinates (166) are exactly the rows without an LSOA code.
- `Context` was empty on every row.
- An outcomes file lists outcomes recorded in that month: only 1,591 of 3,688
  crime ids also appear in the same month's street file, and a crime id can
  repeat (several outcomes).
- `Month` equals the folder month in every file read.

## 2. GOV.UK bank holidays (Crown copyright, Open Government Licence v3.0)

Bundled as `inst/extdata/bank_holidays.csv` (England and Wales only) by
`data-raw/bank_holidays.R`. Verified 2026-09-16.

- Live feed <https://www.gov.uk/bank-holidays.json>: divisions
  `england-and-wales`, `scotland`, `northern-ireland`; event fields `title`,
  `date`, `notes`, `bunting`. England and Wales covered 2019-01-01 to
  2028-12-26 (83 events) at retrieval. Past years drop out of the feed.
- UK Government Web Archive copies of the feed return an HTML shell, so
  Internet Archive captures were used for 2012 to 2018 (the `id_` flag returns
  the original bytes):
  `https://web.archive.org/web/20141224183209id_/https://www.gov.uk/bank-holidays.json`
  (2012 to 2016),
  `https://web.archive.org/web/20161229052951id_/https://www.gov.uk/bank-holidays.json`
  (2012 to 2018),
  `https://web.archive.org/web/20181203062756id_/https://www.gov.uk/bank-holidays.json`
  (2012 to 2019). The builder stops if captures disagree on a date's title;
  they did not.
- 2010 and 2011 (the feed starts in 2012): transcribed from the England and
  Wales table on the archived Directgov page "Bank holidays and British Summer
  Time", capture of 2011-01-06,
  `https://web.archive.org/web/20110106104158/http://www.direct.gov.uk/en/Governmentcitizensandrights/LivingintheUK/DG_073741`.
  2010: 1 January, 2 April, 5 April, 3 May, 31 May, 30 August, 27 and 28
  December (substitute days). 2011: 3 January (substitute), 22 April, 25
  April, 29 April (royal wedding), 2 May, 30 May, 29 August, 26 and 27
  December (substitute days). `bunting` is not published there and is `NA`.
- Apostrophes (U+2019 in the feed) are normalised to ASCII.

## 3. ONS Open Geography Portal (Open Government Licence v3.0)

Bundled as `inst/extdata/lsoa_lookup.rds` by `data-raw/lsoa_lookup.R`.
Verified 2026-09-16 via the ArcGIS Online search API for the ONS Geography
organisation (org id `ESMARspQHYMw9BZ9`), the Hub download API and the
FeatureServer query endpoint. Item records give `licenseInfo` linking to
<https://www.ons.gov.uk/methodology/geography/licences>, which supplies the
statement "Source: Office for National Statistics licensed under the Open
Government Licence v.3.0".

| Product | Item id | Rows | Notes |
|---|---|---|---|
| LSOA (2011) to LSOA (2021) to Local Authority District (2022) Exact Fit Lookup for EW (V3) | `cbfe64cc03d74af982c1afec639bafd1` | 35,796 | Columns LSOA11CD, LSOA11NM, LSOA21CD, LSOA21NM, CHGIND, LAD22CD, LAD22NM, LAD22NMW. CHGIND: U 33,647; S 1,900; M 239; X 10. Distinct LSOA11CD 34,753; distinct LSOA21CD 35,672; 331 LADs. V3 corrected the change indicator for fewer than ten LSOAs and four Shepway names. |
| LSOA (2011) to LSOA (2021) to Local Authority District (2022) Best Fit Lookup for EW (V2) | `b684a0dbf786473f9563ec0616da2f8b` | 34,753 | One row per 2011 LSOA, no change indicator; 1,039 2021 LSOAs are never a best-fit target. Hub CSV download returned 404 twice, so the table was paged from the FeatureServer (`LSOA11_LSOA21_LAD22_EW_LU_v2`, 1,000 rows per page). Every best-fit pair is also an exact-fit pair. |
| Lower layer Super Output Areas (December 2021) Names and Codes in EW (V3) | `0f80c523f3cd4d0fab5111572f84a2fb` | 35,672 | E01 33,755; W01 1,917. Equal to the exact-fit LSOA21CD set. |
| Lower layer Super Output Areas (December 2011) Names and Codes in EW | `a5b7042782fe4ee99b8477ddf7bfe585` | 34,753 | E01 32,844; W01 1,909. Equal to the exact-fit LSOA11CD set. |

Discrepancy with the specification: the specification calls the required
table the "best-fit lookup" and expects a change indicator. The ONS product
literally named "Best Fit" has no indicator; the "Exact Fit" product has it.
The package bundles the exact-fit table with a `best_fit` flag marking the
best-fit choice, which serves both purposes (decision 3 in `decisions.md`).

`TODO(source)` (M2): LSOA 2011 and 2021 boundary products (generalised,
BGC or BSC), the LSOA to MSOA to LAD to PFA lookups, and their item ids.

## 3a. Police forces (bundled as `inst/extdata/forces.csv`)

Built by `data-raw/forces.R` on 2026-09-16 from
<https://data.police.uk/api/forces> (44 forces; British Transport Police is
absent from the API but present in the archive and added by hand) joined to
the ONS Police Force Areas (December 2025) Names and Codes in the UK (item
`ff7c3ac78cc647f6b103166a65e31c44`, FeatureServer `PFA_DEC_2025_UK_NC`; the
Hub CSV download returned 404). Name matching: strip " Police",
" Constabulary" or " Police Service"; City of London maps to "London, City
of", the Metropolitan Police Service to "Metropolitan Police".

## 4. Policy shocks (bundled as `inst/extdata/shocks.csv`)

Dates were verified on 2026-09-16 by fetching each `source_url` and quoting
the sentence that establishes the date. Key quotes, by row name:

- `riots_2011`: Ministry of Justice, "The public disorder began on 6th August
  2011. On 7th and 8th August 2011 there were further outbreaks of disorder
  mainly in London. On 9th August the incidents were mainly outside of
  London." Home Office overview (24 October 2011): "5,175 recorded crimes and
  4,105 arrests across 19 police forces". Court hearings by area name London,
  West Midlands, Greater Manchester, Merseyside and Nottingham; the full list
  of 19 forces is only in a PDF that could not be read, so only those five
  forces are listed.
- `uksa_recorded_crime_dedesignation`: ACPO release of 15 January 2014, "We
  are very disappointed in the move made today by the UK Statistics Authority
  to remove the National Statistics designation on statistics arising out of
  recorded crime data." ONS bulletin of 16 July 2015 confirms "published in
  January 2014".
- `stop_search_reform_announcement`: "Delivered on: 30 April 2014"; "This
  summer, the Home Office and the College of Policing will launch a new 'Best
  Use of Stop and Search' scheme."
- `buss_launch`: "Published: 26 August 2014"; "Following the announcement in
  the Beating Crime Plan on 27 July 2021, the voluntary conditions relating to
  section 60 (pages 2 and 6) within this scheme are no longer in place."
  Re-checked directly on 2026-09-16.
- `hmic_crime_data_integrity_report`: ONS, "The final report Crime-recording:
  making the victim count, was published on 18 November 2014."; "an estimated
  1 in 5 offences (19%) that should have been recorded as crimes were not."
- `pace_code_a_2015` and `pace_code_a_2023`: "This revised PACE Code A has
  effect from 19 March 2015"; "It was superseded by PACE Code A 2023 on 17
  January 2023."
- `hocr_24_hour_recording`: "Since April 2015, the Home Office Counting Rules
  have required the police to record a crime at the earliest opportunity, and
  at most within 24 hours ... (previously this was within 72 hours)." Day of
  month not stated; the first is assumed.
- `serious_violence_strategy`: "Published: 9 April 2018"; "The Home Secretary
  will launch the Serious Violence Strategy at an event in London today".
- `met_violent_crime_task_force`: Mayor's Question answer of 10 June 2019,
  "The Violent Crime Task Force (VCTF) has made 1,069 arrests since its
  creation in April 2018." Day of month not stated; the first is assumed.
- `s60_pilot_seven_forces`: Home Office research page, "On 31 March 2019 the
  Home Secretary announced that 2 relaxations to the Best Use of Stop and
  Search Scheme (BUSSS) would be piloted" in "Greater Manchester Police (GMP),
  Merseyside, Metropolitan Police Service (MPS), South Wales, South Yorkshire,
  West Midlands, and West Yorkshire". Home Office statistical bulletin (year
  ending March 2022): "7 forces joining the pilot from 1st April 2019 whilst
  the remaining 37 forces joined from August 2019."
- `serious_violence_fund_surge`: "Published: 17 April 2019"; "allocating an
  immediate £51 million for police forces"; "Funding is being allocated to 18
  forces in England and Wales". Force list and amounts from the 8 May 2019
  release "Police granted funding boost for action on serious violence".
- `s60_relaxation_all_forces`: "Published: 11 August 2019"; "A stop and search
  pilot has today been rolled out to all 43 forces in England and Wales";
  "extending the initial period a Section 60 can be in force from 15 hours to
  24, and extending the overall period an extension can be in place from 39 to
  48 hours"; "lift all conditions in the voluntary Best Use of Stop and Search
  Scheme over the use of Section 60". Re-checked directly on 2026-09-16.
- COVID-19 England rows: Institute for Government timeline (December 2021
  edition): "23 March PM announces the first lockdown in the UK, ordering
  people to 'stay at home'"; "26 March Lockdown measures legally come into
  force"; "4 July ... reopening of pubs, restaurants, hairdressers"; "5
  November Second national lockdown comes into force in England"; "2 December
  Second lockdown ends"; "6 January England enters third national lockdown";
  "29 March: Step 1 ... 'Stay at home' order ends"; "19 July: Step 4 Most
  legal limits on social contact removed". SI 2020/558 "come into force on
  1st June 2020" replacing the leaving-home restriction with an
  overnight-stay ban. Tier 4: Prime Minister's statement of 19 December 2020,
  "These measures will take effect from tomorrow morning"; the Institute for
  Government gives 21 December. Plan B: "From Thursday 27 January: venues and
  events will no longer be required by law to use the NHS COVID Pass"; all
  domestic legal restrictions "will end on 24 February" 2022.
- COVID-19 Wales rows: GOV.WALES, "'Local' means not generally travelling
  more than 5 miles from home" (from Monday 1 June 2020); "The requirement to
  stay local will be lifted from 6 July"; "The fire-break will start at 6pm on
  Friday 23 October and end on Monday 9 November"; alert level 4 "These new
  restrictions will come into effect from midnight tonight" (19 December
  2020); "stay-at-home restrictions will be replaced by a new interim stay
  local rule in Wales from tomorrow (Saturday 13 March)" 2021; Omicron "New
  measures will be introduced from 6am on Boxing Day"; "On Friday 28 January,
  Wales will complete the move to alert level 0."
- `beating_crime_plan_s60_permanent`: Beating Crime Plan "Published: 27 July
  2021" and the BUSS page quote above.
- `home_secretary_s60_letter_2022`: "Published: 16 May 2022"; "In a letter
  sent to police forces today (Monday 16 May), the Home Secretary will remove
  restrictions on section 60 that have been in place since 2014." Conflict
  with the 2021 row noted in both rows' notes: operational conditions had
  applied nationally since 11 August 2019.
- `pcsc_act_royal_assent`: legislation.gov.uk "[28th April 2022]".
- `serious_violence_duty`: SI 2022/1227 regulation 4, provisions coming into
  force "31st January 2023" including sections 8 and 9.
- `svro_pilot`: SI 2023/387, "'the specified period' means the period of 24
  months beginning with 19th April 2023"; pilot areas "Merseyside, Thames
  Valley, Sussex and West Midlands". Crown Prosecution Service (17 April
  2025): "live orders will be phased out over 6 months, ending on Friday 17
  October 2025".
- `public_order_act_2023_protest_search`: SI 2023/1418 regulation 2, "The
  following provisions of the Public Order Act 2023 come into force on 20th
  December 2023" including sections 10 and 11; SI 2023/733 commenced sections
  3 to 6 and 17 on 2 July 2023.

Reviewed and excluded (date not verifiable from a fetched primary source, or
context only): HMIC interim report "Crime recording: A matter of fact" (May
2014); BUSS "all 43 forces signed up" claim; the Metropolitan Police Stop and
Search Charter (February 2025, day unverified); Crime and Policing Act 2026
(Royal Assent 29 April 2026; no change to territorial-force stop and search
powers identified). Candidates for later verification are listed in the
research record kept with the M0 session.

## 5. Not yet verified (later milestones)

- `TODO(source)` (M2): NOMIS API for Census 2021 usual resident population by
  LSOA and MSOA (<https://www.nomisweb.co.uk/api/v01/>): dataset id, geography
  type codes, rate limits.
- `TODO(source)` (M2): English Indices of Deprivation 2025 file layout and the
  Welsh Index of Multiple Deprivation 2019 layout.
- `TODO(source)` (M2): whether the `Falls within` and `Reported by` strings of
  every force equal the police.uk API names in `lamp_forces()` (verified for
  Dyfed-Powys, West Yorkshire and British Transport Police only).
- `TODO(source)` (M3): UK daylight saving transition dates (statutory rule:
  last Sunday in March and October, 1am GMT; confirmed on the archived
  Directgov page for 2010 and 2011).

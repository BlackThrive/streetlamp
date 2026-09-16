# Bundled data

Small reference tables shipped with streetlamp. Each is built by the script of
the same name in `data-raw/` and verified as recorded in
`inst/NOTES/data_sources.md`.

| File | Content | Source and licence |
|---|---|---|
| `shocks.csv` | Dated national policy and environment shocks (stop and search policy, crime policy, COVID-19 restrictions, recording practice, disorder) with the source that establishes each date | Curated from GOV.UK, GOV.WALES, legislation.gov.uk, ONS and the Institute for Government; see `source_url` per row. Crown copyright material is reused under the Open Government Licence v3.0. |
| `bank_holidays.csv` | Bank and public holidays in England and Wales, 2010 to 2028 | GOV.UK bank holidays feed (live and Internet Archive captures) and the archived Directgov page, Crown copyright, Open Government Licence v3.0 |
| `lsoa_lookup.rds` | LSOA 2011 to LSOA 2021 exact-fit lookup for England and Wales with ONS change indicator, 2022 local authority district and best-fit flag; the source of both LSOA code lists | Source: Office for National Statistics licensed under the Open Government Licence v3.0 |

Contains public sector information licensed under the Open Government Licence
v3.0: <https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/>.

Recorded crime, outcomes and stop and search data are not bundled as records.
The sample panel and raw force-month fixtures added at later milestones derive
from data.police.uk, also published under the Open Government Licence v3.0.

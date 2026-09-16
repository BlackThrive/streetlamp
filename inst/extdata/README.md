# Bundled data

Small reference tables shipped with streetlamp. Each is built by the script of
the same name in `data-raw/` and verified as recorded in
`inst/NOTES/data_sources.md`.

| File | Content | Source and licence |
|---|---|---|
| `shocks.csv` | Dated national policy and environment shocks (stop and search policy, crime policy, COVID-19 restrictions, recording practice, disorder) with the source that establishes each date | Curated from GOV.UK, GOV.WALES, legislation.gov.uk, ONS and the Institute for Government; see `source_url` per row. Crown copyright material is reused under the Open Government Licence v3.0. |
| `bank_holidays.csv` | Bank and public holidays in England and Wales, 2010 to 2028 | GOV.UK bank holidays feed (live and Internet Archive captures) and the archived Directgov page, Crown copyright, Open Government Licence v3.0 |
| `lsoa_lookup.rds` | LSOA 2011 to LSOA 2021 exact-fit lookup for England and Wales with ONS change indicator, 2022 local authority district and best-fit flag; the source of both LSOA code lists | Source: Office for National Statistics licensed under the Open Government Licence v3.0 |
| `forces.csv` | The 45 forces in the archive with police.uk identifiers, names and ONS police force area codes | police.uk API and ONS Police Force Areas (December 2025) Names and Codes, Open Government Licence v3.0 |
| `archive/2026-06.zip`, `archive/2026-07.zip` | Miniature copies of two data.police.uk archive snapshots with the real layout (`YYYY-MM/YYYY-MM-<force>-<type>.csv`) and real records for a subset of neighbourhoods (Leeds 100 to 112 and Kirklees 042 in West Yorkshire; Carmarthenshire 001 to 012 and Pembrokeshire 001 to 006 in Dyfed-Powys), May to July 2026, plus a few rows without a location; built by `data-raw/sample.R` | data.police.uk, Open Government Licence v3.0 |

Contains public sector information licensed under the Open Government Licence
v3.0: <https://www.nationalarchives.gov.uk/doc/open-government-licence/version/3/>.

The miniature archives are the only records bundled; they exist so that the
examples and tests run offline and are not a sample for analysis. The
aggregated sample panel and boundaries added at milestone M2 also derive from
data.police.uk and the Office for National Statistics under the Open
Government Licence v3.0.

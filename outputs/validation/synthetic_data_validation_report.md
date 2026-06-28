# Synthetic Data Validation Report

- Generated: `2026-06-22T08:28:51Z`
- Overall status: **PASS**
- Checks: 54
- Errors: 0
- Warnings: 0
- Expected test exceptions: 6

## Executive Statistics

- Encounters: `6,345`
- Resource rows: `6,850`
- GL transactions: `257`
- Total signed GL: `$82,837,467.56`
- Direct costs: `$1,649,736.61`
- Funded encounters: `6,344`
- Unfunded review encounters: `1`
- Total synthetic NWAU: `7475.508562`
- Total synthetic funding: `$80,361,719.43`
- Funding-to-GL ratio: `97.0%`

## Encounter Distribution

### By service line

| Service line | Encounters | Share |
|---|---:|---:|
| Emergency | 1,024 | 16.1% |
| Medical | 2,189 | 34.5% |
| Mental Health | 449 | 7.1% |
| Outpatients | 310 | 4.9% |
| Surgical | 1,356 | 21.4% |
| Women's and Children's | 1,017 | 16.0% |

### By care type

| Care type | Encounters | Share |
|---|---:|---:|
| Emergency | 1,024 | 16.1% |
| Inpatient | 4,264 | 67.2% |
| Outpatient | 310 | 4.9% |
| Same-day | 747 | 11.8% |

## Statistical Summaries

| Measure | Count | Min | Mean | Median | P95 | Max |
|---|---:|---:|---:|---:|---:|---:|
| Age (years) | 6,345 | 0.0 | 49.527 | 48.0 | 88.0 | 92.0 |
| Inpatient LOS (days) | 4,264 | 1.0 | 3.511 | 3.0 | 9.0 | 27.0 |
| Synthetic NWAU | 6,344 | 0.18 | 1.178 | 0.9 | 3.2 | 3.528 |
| Bed Days | 6,850 | 0.0 | 2.207 | 2.0 | 7.0 | 22.0 |
| Theatre Minutes | 6,850 | 0.0 | 28.712 | 0.0 | 175.55 | 413.0 |
| Imaging Weighted Units | 6,850 | 0.0 | 1.137 | 1.0 | 3.0 | 5.0 |
| Pathology Weighted Units | 6,849 | 0.0 | 4.41 | 4.0 | 9.0 | 18.0 |
| Pharmacy Units | 6,850 | 0.0 | 7.737 | 6.0 | 18.0 | 37.0 |
| Medical Service Units | 6,850 | 1.0 | 7.64 | 6.0 | 19.0 | 44.0 |
| Allied Health Units | 6,850 | 0.0 | 4.02 | 3.0 | 11.0 | 24.0 |

## Validation Checks

| Status | Area | Check | Result |
|---|---|---|---|
| EXPECTED | ABF | `ABF-UNFUNDED` | One unclassified encounter is held for funding review Observed: `ENC0006345`. |
| EXPECTED | Encounters | `ENC-UNCLASSIFIED` | One deliberate unclassified encounter is present Observed: `ENC0006345`. |
| EXPECTED | Financial | `DIR-FAILED` | One deliberate failed direct assignment is present Observed: `900.00`. |
| EXPECTED | Financial | `GL-UNKNOWN-CC` | One deliberate unmapped cost centre is present Observed: `25000.00`. |
| EXPECTED | Financial | `GL-ZERO-DRIVER` | Deliberate zero-driver cost pool is present Observed: `45000.00`. |
| EXPECTED | Resources | `RES-NEG-PATH` | One deliberate negative pathology driver is present Observed: `1`. |
| PASS | ABF | `ABF-CALC` | Encounter funding calculations are arithmetically consistent |
| PASS | ABF | `ABF-GROUPS` | All calculated funding rows have group references |
| PASS | ABF | `ABF-MONTH-CONTROL` | Monthly ABF controls agree Observed: `12`. |
| PASS | ABF | `ABF-POPULATION` | ABF population exactly matches the encounter population Observed: `6345`. |
| PASS | ABF | `ABF-PRICE` | One synthetic base price is applied consistently Observed: `10750.00`. |
| PASS | Control files | `CON-FILE-control_gl_cost_centre.csv` | File and required columns are present Observed: `194`. |
| PASS | Control files | `CON-FILE-control_gl_monthly.csv` | File and required columns are present Observed: `12`. |
| PASS | Control files | `CON-FILE-control_row_count.csv` | File and required columns are present Observed: `15`. |
| PASS | Control files | `CON-FILE-expected_data_quality_issue.csv` | File and required columns are present Observed: `5`. |
| PASS | Encounters | `ENC-AGE` | Encounter ages are within 0-110 |
| PASS | Encounters | `ENC-CARE` | All expected care types are represented |
| PASS | Encounters | `ENC-CARE-LOS` | Care type and LOS are consistent |
| PASS | Encounters | `ENC-DATES` | Encounter dates and LOS are internally valid |
| PASS | Encounters | `ENC-MONTHS` | All 12 reporting months are represented |
| PASS | Encounters | `ENC-MULTI-MONTH` | Multi-month encounter resource records are present Observed: `505`. |
| PASS | Encounters | `ENC-SERVICES` | All expected service lines are represented |
| PASS | Encounters | `ENC-UNIQUE` | Encounter IDs are unique Observed: `6345`. |
| PASS | Expected outputs | `EXP-FILE-abf_encounter_funding.csv` | File and required columns are present Observed: `6345`. |
| PASS | Expected outputs | `EXP-FILE-abf_monthly_control_total.csv` | File and required columns are present Observed: `12`. |
| PASS | Financial | `GL-CC-CONTROL` | Cost-centre GL totals match controls Observed: `194`. |
| PASS | Financial | `GL-DIRECT-CONTROL` | Direct-cost detail agrees with GL controls |
| PASS | Financial | `GL-MONTH-CONTROL` | Monthly GL totals match controls Observed: `12`. |
| PASS | Financial | `GL-NEGATIVE` | Negative GL amounts are classified as credits or reversals Observed: `2`. |
| PASS | Financial | `GL-UNIQUE` | GL transaction IDs are unique Observed: `257`. |
| PASS | Financial | `GL-UNKNOWN-ACCOUNT` | All GL natural accounts are mapped |
| PASS | Plausibility | `PLAUS-COST-FUNDING` | Portfolio-wide synthetic funding is reasonably calibrated to the GL cost base Observed: `97.0%`. |
| PASS | Plausibility | `PLAUS-MONTH-VOLUME` | Monthly encounter volumes vary without implausible discontinuity Observed: `460-610`. |
| PASS | Plausibility | `PLAUS-SERVICE-MIX` | All service lines have usable analytical populations |
| PASS | Plausibility | `PLAUS-VOLUME` | Annual encounter volume is suitable for the portfolio scale Observed: `6345`. |
| PASS | Raw files | `RAW-FILE-direct_cost_detail.csv` | File and required columns are present Observed: `841`. |
| PASS | Raw files | `RAW-FILE-general_ledger_transaction.csv` | File and required columns are present Observed: `257`. |
| PASS | Raw files | `RAW-FILE-patient_encounter.csv` | File and required columns are present Observed: `6345`. |
| PASS | Raw files | `RAW-FILE-resource_usage.csv` | File and required columns are present Observed: `6850`. |
| PASS | Reference files | `REF-FILE-abf_activity_group.csv` | File and required columns are present Observed: `9`. |
| PASS | Reference files | `REF-FILE-abf_adjustment_rule.csv` | File and required columns are present Observed: `5`. |
| PASS | Reference files | `REF-FILE-account_mapping.csv` | File and required columns are present Observed: `14`. |
| PASS | Reference files | `REF-FILE-activity_group.csv` | File and required columns are present Observed: `10`. |
| PASS | Reference files | `REF-FILE-allocation_rule.csv` | File and required columns are present Observed: `12`. |
| PASS | Reference files | `REF-FILE-care_type.csv` | File and required columns are present Observed: `4`. |
| PASS | Reference files | `REF-FILE-cost_centre.csv` | File and required columns are present Observed: `17`. |
| PASS | Reference files | `REF-FILE-reporting_period.csv` | File and required columns are present Observed: `12`. |
| PASS | Reference files | `REF-FILE-service_line.csv` | File and required columns are present Observed: `6`. |
| PASS | Resources | `RES-BED-DAY` | Bed days are confined to admitted activity Observed: `15117`. |
| PASS | Resources | `RES-FK` | All resource rows reference valid encounters |
| PASS | Resources | `RES-NEG-OTHER` | No unexpected negative resource measures |
| PASS | Resources | `RES-THEATRE` | Theatre minutes are concentrated in procedural services Observed: `100.0%`. |
| PASS | Resources | `RES-UNIQUE` | Resource usage IDs are unique Observed: `6850`. |
| PASS | Source controls | `SRC-ROW-CONTROL` | All controlled source row counts agree Observed: `15`. |

## Interpretation

- `PASS` means the generated data met the check.
- `EXPECTED` identifies a deliberate exception included to test later SQL controls.
- `WARNING` identifies a plausible but reviewable distribution or calibration issue.
- `ERROR` indicates an unexpected inconsistency and causes the script to exit non-zero.
- Statistical plausibility does not make the synthetic data clinically authoritative.

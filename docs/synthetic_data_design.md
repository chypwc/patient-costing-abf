# Synthetic Data Design

## 1. Purpose

Two reproducible generators create the connected data for this project:

1. `scripts/generate_patient_costing_data.py` creates raw clinical and financial extracts, reference data and independent controls.
2. `scripts/generate_abf_funding_data.py` reads the raw encounter file, adds ABF reference rules and creates expected funding outputs for the same encounters.

The ABF generator must be run after the patient-costing generator. It does not create a second patient population.

All data is synthetic. The activity groups, weights, adjustments and prices are educational portfolio assumptions rather than official IHACPA classifications or funding calculations.

## 2. Reproducibility

The patient-costing generator uses fixed random seed `20250622`. Re-running it produces the same business records and financial values. Generation timestamps in manifest files will change.

Both scripts use only the Python standard library.

```powershell
python scripts/generate_patient_costing_data.py
python scripts/generate_abf_funding_data.py
python scripts/validate_synthetic_data.py
```

The validation command returns exit code `0` when no unexpected errors are
found and exit code `1` when a consistency failure is detected.

## 3. Data Folder Responsibilities

| Folder | Purpose | SQL treatment |
|---|---|---|
| `data/raw/` | Source-like clinical, resource, direct-cost and GL extracts | Load into `landing`, validate, then promote to `stg` |
| `data/reference/` | Controlled mappings, classifications and costing or ABF rules | Load into `landing`, validate, then promote to `ref` |
| `data/controls/` | Row-count controls, financial controls, expected exceptions and generation manifests | Use for load and test validation |
| `data/expected_outputs/` | Independently generated ABF results used to test SQL calculations | Do not use as production source input |

Only `raw/` and `reference/` are normal batch-load inputs. They first enter
nullable-text landing tables. SQL validates and promotes accepted rows into
typed `stg` and `ref` tables, calculates patient costs and ABF results, then
compares them with `expected_outputs/` during testing.

## 4. Shared Population

The generated population covers synthetic financial year 2024–25:

- 1 July 2024 to 30 June 2025;
- one synthetic tertiary facility, `Central Hospital`;
- 6,345 encounters;
- six service lines;
- four care types;
- nine synthetic activity groups;
- one deliberate unclassified encounter.

Monthly volume increases gradually and contains a deliberate March activity increase. This allows later monthly cost, activity and unit-cost variance analysis.

## 5. Data-Type and Format Conventions

- identifiers and classification codes are text;
- dates and reporting months use ISO `YYYY-MM-DD`;
- counts, minutes, units, age and length of stay are integers;
- financial amounts use signed decimal values with two displayed decimal places;
- percentage or weight calculations retain at least six decimal places;
- flags use `Y` and `N`;
- permitted service lines, care types, activity groups, cost centres and accounts are supplied in reference files.

## 6. Raw Source Contracts

### `patient_encounter.csv`

**Grain:** one row per encounter.  
**Business key:** `encounter_id`.

| Column | Meaning |
|---|---|
| `encounter_id` | Synthetic encounter identifier |
| `patient_id` | Synthetic patient identifier; a patient may have multiple encounters |
| `facility` | Synthetic hospital |
| `service_line` | Clinical service responsible for the encounter |
| `care_type` | Inpatient, Same-day, Emergency or Outpatient |
| `admission_date` | Encounter start date |
| `discharge_date` | Encounter end date |
| `episode_month` | Primary monthly reporting period |
| `activity_group_code` | Synthetic activity classification used by costing and ABF |
| `length_of_stay` | Calendar length of stay; zero is valid for non-overnight care |
| `separation_status` | Encounter completion status |
| `age_years` | Synthetic age used for clinical mix and funding demonstration |
| `indigenous_status` | Synthetic demographic flag |
| `remoteness_area` | Synthetic remoteness classification |
| `high_complexity_flag` | Scenario flag that increases expected resource use |
| `hospital_acquired_complication_flag` | Synthetic quality-context flag; not used to judge care |

### `resource_usage.csv`

**Grain:** one row per encounter and service month.  
**Business key:** `resource_usage_id`; alternate key `encounter_id + service_month`.

The file contains:

- bed days;
- theatre minutes;
- imaging weighted units;
- pathology weighted units;
- pharmacy units;
- medical service units;
- allied health units.

Encounter count is not stored in this file. SQL derives it from
`patient_encounter.csv` at the nominated `episode_month`, so a multi-month
encounter is counted once while its resource use may span multiple months.

Multi-month admitted encounters have one resource row for each month. One deliberate negative pathology value tests validation logic.

### `direct_cost_detail.csv`

**Grain:** one patient-identifiable direct-cost item.  
**Business key:** `direct_cost_id`.

The file contains:

- prostheses and implants;
- patient-specific medicines;
- patient-specific imaging;
- one deliberate direct-cost record with an invalid encounter identifier.

The corresponding direct-cost amounts are included in the GL control records so the direct-assignment layer can reconcile.

### `general_ledger_transaction.csv`

**Grain:** one synthetic GL transaction or monthly control transaction.  
**Business key:** `gl_transaction_id`.

Amounts use the signed convention:

- positive values increase expense;
- negative values are credits or reversals.

The data includes:

- recurring monthly expenditure;
- a March theatre and agency-nursing increase;
- a legitimate supplier credit;
- a legitimate accrual reversal;
- a journal adjustment;
- a `$45,000` zero-driver allied-health test pool;
- a `$25,000` unmapped cost-centre test;
- direct-cost control amounts.

## 7. Reference Files

| File | Grain and purpose |
|---|---|
| `cost_centre.csv` | One cost centre with service and cost-pool mapping |
| `account_mapping.csv` | One natural account with category, treatment and default driver |
| `service_line.csv` | One approved service line |
| `care_type.csv` | One approved care type |
| `activity_group.csv` | One synthetic activity group |
| `allocation_rule.csv` | One effective-dated cost-pool allocation rule |
| `reporting_period.csv` | One monthly reporting period |
| `abf_activity_group.csv` | One synthetic funding activity group and weight |
| `abf_adjustment_rule.csv` | One synthetic funding adjustment rule |

## 8. Synthetic Activity Groups

| Code | Group | Main service stream |
|---|---|---|
| `AG01` | Complex Medical | Admitted acute |
| `AG02` | General Medical | Admitted acute |
| `AG03` | Major Surgical | Admitted acute |
| `AG04` | Minor Surgical or Same-day | Admitted acute |
| `AG05` | Maternity | Admitted acute |
| `AG06` | Paediatric | Admitted acute |
| `AG07` | Mental Health | Mental health |
| `AG08` | Emergency | Emergency |
| `AG09` | Outpatient | Non-admitted |

These codes are not official AR-DRGs.

## 9. Deliberate Test Scenarios

| Scenario | Expected treatment |
|---|---|
| One unclassified activity group | Costing may proceed with a warning; ABF remains `UNFUNDED_REVIEW` |
| One negative pathology driver | Block the affected driver record |
| Unknown cost centre `CC_UNKNOWN` | Retain the GL amount as unallocated |
| `ALLIED_SPECIAL` expenditure with no eligible population | Retain the full pool as unallocated |
| Direct cost for `ENC_NOT_FOUND` | Fail direct assignment and retain the amount as unallocated |
| Same-day zero-length encounters | Treat as valid |
| Multi-month admitted encounter | Use separate encounter-month resource records |
| Credits, reversals and journal adjustments | Preserve signed values and classify rather than reject automatically |

## 10. Control Outputs

The patient-costing generator creates:

- `control_row_count.csv`;
- `control_gl_monthly.csv`;
- `control_gl_cost_centre.csv`;
- `patient_costing_generation_manifest.json`;
- `expected_data_quality_issue.csv`.

These files are written to `data/controls/`. Generation manifests are also
stored there.

These controls will be loaded or independently checked during SQL ingestion.

The independent validator `scripts/validate_synthetic_data.py` reads both data
layers without modifying them. It checks contracts, keys, relationships,
distributions, financial controls, deliberate exceptions and ABF arithmetic,
then writes:

- `outputs/validation/synthetic_data_validation_report.md`;
- `outputs/validation/synthetic_data_validation_report.json`.

An unexpected validation error causes a non-zero process exit code.

## 11. Synthetic ABF Layer

The ABF generator reads `data/raw/patient_encounter.csv` and produces:

- ABF reference files in `data/reference/`;
- `abf_encounter_funding.csv` in `data/expected_outputs/`;
- `abf_monthly_control_total.csv` in `data/expected_outputs/`;
- `abf_generation_manifest.json` in `data/controls/`.

The simplified calculation is:

```text
Adjusted weighted activity
=
Synthetic base weight
× demographic adjustment factors
+ synthetic long-stay outlier units
```

```text
Estimated synthetic funding
=
Adjusted weighted activity
× synthetic base price
```

The synthetic base price is `$10,750`. It is calibrated only to keep portfolio-wide funding reasonably close to the generated cost base. Demonstration adjustments include Indigenous status, remote residence, paediatric admitted activity, same-day activity and long-stay outliers.

These values illustrate the logic of classification, weighted activity and pricing. They are not official NWAU values, price weights, adjustments or funding entitlements.

## 12. Connection Between the Two Layers

```text
patient_encounter.csv
       |                         |
       v                         v
Patient-costing SQL         Synthetic ABF script
       |                         |
       v                         v
Patient-level cost          Estimated funding
       |                         |
       +-----------+-------------+
                   v
          Cost-to-funding analysis
```

The eventual comparison joins on `encounter_id`. Patient-level cost remains a SQL output; the generator does not pre-calculate it.

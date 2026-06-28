# SQL Data Workflow and Schema Responsibilities

## Approved Workflow

```text
CSV files
    |
    v
landing  Exact source values as nullable text
    |
    v
dq       Format, completeness, relationship and control checks
    |
    +---------- valid rows ----------+
    |                                |
    v                                v
stg typed transactions          ref typed mappings and rules
    |                                |
    +---------------+----------------+
                    v
costing  Cost pools, drivers, allocations and patient-level cost
                    |
                    v
recon    GL control totals and GL-to-costing reconciliation
                    |
                    v
reporting  Excel-ready views
```

## Schema Responsibilities

| Schema | Responsibility | Example objects |
|---|---|---|
| `landing` | Preserve exact CSV values before conversion | `landing.patient_encounter`, `landing.general_ledger_transaction` |
| `stg` | Validated, typed transactional data | `stg.patient_encounter`, `stg.resource_usage` |
| `ref` | Validated, typed mappings and business rules | `ref.cost_centre`, `ref.allocation_rule` |
| `dq` | Load audit, source controls, validation outcomes and issue management | `dq.load_run`, `dq.source_file_control`, `dq.validation_result`, `dq.issue_register` |
| `costing` | Costing calculations and patient-level results only | `costing.cost_pool`, `costing.encounter_driver`, `costing.patient_level_cost` |
| `recon` | Financial control totals and GL-to-costing reconciliation | `recon.gl_control_total`, `recon.costing_reconciliation` |
| `reporting` | Curated views for Excel and management reporting | `reporting.vw_executive_costing_summary` |

## Why Validation Is Not in `costing`

Data validation occurs before data is accepted for costing. Placing validation
under `costing` would mix source assurance with business calculations and make
ownership unclear.

The `dq` schema can record:

- whether a file loaded;
- whether a value can be converted to its target type;
- duplicate and missing-key findings;
- invalid dates and resource values;
- missing mappings;
- whether a row is eligible for promotion to `stg` or `ref`.

## Why Reconciliation Is Separate

Reconciliation is an assurance process that compares:

- source control totals with loaded GL totals; and
- GL costs with direct, allocated, unallocated and excluded costing outcomes.

It tests the costing model but is not itself an allocation calculation.
Separating it under `recon` makes financial control evidence easier to review.

## Landing and Typed Layers

Landing columns are nullable text so malformed source values can still be
loaded and reported:

```text
landing.patient_encounter.admission_date = 'not-a-date'
```

Validation can then use:

```sql
TRY_CONVERT(date, admission_date)
```

Only rows meeting the required promotion rules enter typed `stg` or `ref`
tables. Typed tables remain the trusted inputs to costing.


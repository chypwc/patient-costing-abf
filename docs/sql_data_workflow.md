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
recon    GL-to-costing reconciliation at TOTAL and COST_POOL levels
                    |
                    v
reporting  Excel-ready fact and dimension views
```

## Schema Responsibilities

| Schema | Responsibility | Example objects |
|---|---|---|
| `landing` | Preserve exact CSV values before conversion | `landing.patient_encounter`, `landing.general_ledger_transaction` |
| `stg` | Validated, typed transactional data | `stg.patient_encounter`, `stg.resource_usage` |
| `ref` | Validated, typed mappings and business rules | `ref.cost_centre`, `ref.allocation_rule` |
| `dq` | Load audit, source controls, validation outcomes and issue management | `dq.load_run`, `dq.source_file_control`, `dq.validation_result`, `dq.issue_register` |
| `costing` | Costing calculations and patient-level results only | `costing.cost_pool`, `costing.encounter_driver`, `costing.patient_level_cost` |
| `recon` | GL-to-costing reconciliation evidence | `recon.costing_reconciliation` |
| `reporting` | Excel-ready fact and dimension views | `reporting.vw_fact_patient_cost`, `reporting.vw_dim_service_line` |

## Final Reporting Model

The project does not build separate physical star-schema tables in SQL Server.
Instead, SQL Server publishes Excel-ready views from the `reporting` schema.
Excel loads those views into the Power Query / Power Pivot Data Model and uses
relationships, slicers, PivotTables and PivotCharts for presentation.

The final reporting views are:

| View type | Views |
|---|---|
| Fact views | `reporting.vw_fact_patient_cost`, `reporting.vw_fact_abf_comparison`, `reporting.vw_fact_reconciliation`, `reporting.vw_fact_data_quality_issue` |
| Dimension views | `reporting.vw_dim_month`, `reporting.vw_dim_facility`, `reporting.vw_dim_service_line`, `reporting.vw_dim_care_type`, `reporting.vw_dim_activity_group`, `reporting.vw_dim_cost_category` |

Excel should consume these views only. It should not recreate patient-cost
allocation, data-quality validation, ABF comparison or reconciliation logic.

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

- loaded GL transactions with direct, allocated, unallocated and excluded costing outcomes.

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

## Reconciliation Grain

`recon.costing_reconciliation` contains two reconciliation levels:

| Level | Purpose | Excel use |
|---|---|---|
| `TOTAL` | Whole-run GL control proof | Headline reconciliation table only |
| `COST_POOL` | Detailed reconciliation by reporting month, facility, cost centre, cost pool and cost category | Cost-category / cost-pool analysis and slicers |

Do not sum `TOTAL` and `COST_POOL` rows together in the same PivotTable. That
will double-count the reconciliation amounts.

# Runbook

## Purpose

This runbook describes how to refresh the synthetic patient-level costing workflow and Excel reporting workbook.

It is written for a portfolio demonstration environment using SQL Server, local CSV files and Microsoft Excel.

## Prerequisites

- SQL Server is running.
- Database target is `CostAnalysisABF`.
- Synthetic CSV files are available under:
  - `C:\SQLData\cost_analysis_abf\raw`
  - `C:\SQLData\cost_analysis_abf\reference`
- Excel workbook is available at:
  - `excel/Patient_Level_Costing_Analysis.xlsx`

## SQL Refresh Sequence

Run the SQL scripts in order:

1. `sql/00_create_database.sql`
2. `sql/01_create_schemas.sql`
3. `sql/02_create_tables.sql`
4. `sql/03_load_landing_from_csv.sql`
5. `sql/04_seed_reference_data.sql`
6. `sql/05_promote_landing_to_staging.sql`
7. `sql/06_validate_staging_data.sql`
8. `sql/07_build_costing_outputs.sql`
9. `sql/09_create_reporting_views.sql`

Reconciliation is built inside `sql/07_build_costing_outputs.sql`. There is no
separate `08_reconcile_costing.sql` script in the final numbered workflow.

If tables already exist, confirm whether the script is intended to be rerun safely. For a clean rebuild, drop only the project tables that are in scope and then rerun the scripts from table creation onward.

## Reference Data Approach

For this portfolio project, reference data is loaded from controlled reference CSV files into temporary tables and merged into `ref` tables.

In a production setting, these reference tables would normally be governed master/reference data or derived and validated from source-system facts, not blindly loaded from monthly CSV files.

## Validation Checks

After staging promotion and validation, confirm:

| Check | Expected result |
|---|---:|
| Patient encounters promoted | 6,345 |
| Resource usage rows promoted | 6,849 |
| Direct cost rows promoted | 840 |
| GL transaction rows promoted | 257 |
| Open DQ issues | 4 |
| DQ financial impact | $70,900 |

Blocking DQ issues prevent affected rows from entering typed staging. Non-blocking issues remain visible for review and are retained in unallocated cost where applicable.

## Costing Checks

After costing outputs are built, confirm:

| Measure | Expected value |
|---|---:|
| Patient-level cost rows | 6,345 |
| Direct assigned cost | $1,648,836.61 |
| Indirect allocated cost | $71,988,922.78 |
| Overhead allocated cost | $5,180,282.29 |
| Total patient-level cost | $78,818,041.68 |
| Unallocated cost | $70,900.00 |

## Reconciliation Checks

Confirm that reconciliation status is `PASS` and that the total reconciliation difference is immaterial rounding only.

The reconciliation output has two levels:

- `TOTAL` for the whole-run control proof.
- `COST_POOL` for cost-category and cost-pool review in Excel.

Do not add `TOTAL` and `COST_POOL` rows together in Excel.

| Measure | Expected value |
|---|---:|
| GL amount | $82,837,467.56 |
| Direct assigned amount | $1,648,836.61 |
| Indirect allocated amount | $75,937,448.66 |
| Overhead allocated amount | $5,180,282.29 |
| Unallocated amount | $70,900.00 |
| Reconciliation difference | approximately $0.00 |

Expected row shape:

| Reconciliation level | Expected row count |
|---|---:|
| `TOTAL` | 1 |
| `COST_POOL` | many detail rows |

## Excel Refresh

1. Open `excel/Patient_Level_Costing_Analysis.xlsx`.
2. Go to **Data**.
3. Select **Refresh All**.
4. Confirm Power Query connections refresh successfully.
5. Confirm PivotTables and PivotCharts update.
6. Check workbook totals against the SQL control totals.

Excel should consume the `reporting.vw_fact_*` and `reporting.vw_dim_*` views
only. It should not recreate allocation, validation or reconciliation logic.

## Known Review Items

- One failed resource-usage row with invalid driver value.
- One failed direct cost row linked to an unknown encounter.
- One GL transaction with unknown cost centre.
- One zero-driver cost pool retained as unallocated.
- One unclassified activity group retained as `UNFUNDED_REVIEW` in ABF comparison.

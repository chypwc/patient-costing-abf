# Patient-Level Costing Analysis and ABF Decision Support

This portfolio project demonstrates a synthetic hospital patient-level costing workflow that converts general-ledger expenditure, clinical activity and resource-use data into reconciled patient-level costs and Excel-based decision-support reporting.

The project is tailored to a Costing Analyst role in a hospital Decision Support / Costing and Performance environment. It focuses on SQL Server costing logic, data-quality controls, general-ledger reconciliation, Activity Based Funding-style comparison and management-ready Excel reporting.

## Project Story

A hospital finance team needs a controlled monthly process to understand the cost and value of clinical services. Source extracts arrive separately from clinical encounters, resource usage, direct cost detail and general-ledger transactions. The workflow validates those inputs, maps expenditure to cost pools, assigns or allocates cost to patient encounters, reconciles the result to the general ledger and publishes Excel-ready reporting views for analysis.

All data is synthetic and generated for portfolio demonstration. It does not represent Canberra Health Services, ACT Government, patient information, financial records or official ABF prices.

## What This Project Shows

- SQL Server workflow for landing, staging, validation, costing, reconciliation and reporting.
- Patient-level cost model using direct assignment, indirect allocation and overhead allocation.
- Data-quality issue register with blocking and non-blocking validation outcomes.
- Reconciliation from general ledger expenditure to direct, allocated, overhead and unallocated cost.
- Excel-ready `vw_fact_*` and `vw_dim_*` reporting views for the workbook Data Model.
- Synthetic ABF-style cost-versus-funding comparison.
- Excel workbook with Power Query, Data Model relationships, PivotTables, PivotCharts and slicers.

## Key Outputs

| Output | Description |
|---|---|
| [`excel/Patient_Level_Costing_Analysis.xlsx`](excel/Patient_Level_Costing_Analysis.xlsx) | Management workbook for service-line cost, activity group analysis, high-cost encounters, ABF comparison, reconciliation and data quality. |
| [`sql/`](sql/) | SQL Server scripts for schema creation, CSV loading, reference seeding, staging promotion, validation, costing outputs and reporting views. |
| [`docs/management_briefing.md`](docs/management_briefing.md) | Concise management summary of findings, risks and recommended actions. |
| [`docs/runbook.md`](docs/runbook.md) | Practical runbook for refreshing the synthetic costing workflow. |
| [`docs/data_dictionary.md`](docs/data_dictionary.md) | Business-oriented dictionary for source, staging, costing, reconciliation and reporting objects. |
| [`docs/costing_methodology.md`](docs/costing_methodology.md) | Detailed costing method, cost pools and allocation drivers. |
| [`docs/data_quality_and_reconciliation.md`](docs/data_quality_and_reconciliation.md) | Data-quality and reconciliation design. |

## Final Reporting Model

SQL Server publishes Excel-ready fact and dimension views in the `reporting`
schema. These are views, not separate physical star-schema tables. Excel loads
them into the Data Model for relationships, slicers, PivotTables and charts.

Fact views:

- `reporting.vw_fact_patient_cost`
- `reporting.vw_fact_abf_comparison`
- `reporting.vw_fact_reconciliation`
- `reporting.vw_fact_data_quality_issue`

Dimension views:

- `reporting.vw_dim_month`
- `reporting.vw_dim_facility`
- `reporting.vw_dim_service_line`
- `reporting.vw_dim_care_type`
- `reporting.vw_dim_activity_group`
- `reporting.vw_dim_cost_category`

## Workbook Structure

The Excel workbook contains six sheets:

1. **Executive Summary** — patient cost by service line with cost composition.
2. **Service and Activity Costing** — total, volume and average cost by activity group.
3. **Cost Drivers and High-Cost Encounters** — high-cost flag summary and drill-down slicers.
4. **ABF Cost vs Funding** — patient cost compared with synthetic ABF-style funding.
5. **Reconciliation and Data Quality** — GL reconciliation and open DQ issues.
6. **Methodology and Controls** — disclaimers, costing method and control notes.

## Costing and Reconciliation Workflow

1. **Prepare and validate source data**
   - Load general-ledger, encounter, direct-cost and resource-use data.
   - Validate required fields, mappings, dates, duplicates and allocation drivers.
   - Record unresolved issues without silently removing affected costs.

2. **Calculate patient-level costs**
   - Assign encounter-identifiable costs directly.
   - Allocate shared clinical costs using documented activity drivers.
   - Allocate approved overhead using the pre-overhead patient-care cost base.
   - Retain failed assignments and zero-driver amounts as unallocated costs.

3. **Reconcile costing results**
   - Reconcile general-ledger expenditure to direct, indirect, overhead, unallocated and excluded amounts.
   - Validate whole-of-run totals and detailed cost-pool results.
   - Preserve reconciliation exceptions for review and management reporting.

4. **Compare cost with ABF-style funding**
   - Apply a clearly labelled simulated funding rate to each eligible encounter.
   - Compare patient-level cost with estimated funding.
   - Aggregate the comparison by service line, activity group and reporting period.

5. **Analyse cost and funding variance**
   - Identify cost-versus-funding differences, monthly movements and high-cost encounters.
   - Examine activity volume, unit cost, resource drivers and data-quality impacts.
   - Present findings with clinical complexity, quality and service context, rather than interpreting cost in isolation.

## Technology Used

- SQL Server / SQL Server Management Studio
- T-SQL
- Microsoft Excel
- Power Query
- Power Pivot / Data Model
- PivotTables, PivotCharts and slicers
- Python synthetic data generation scripts

## Important Caveats

This is a portfolio-scale simulation, not a production costing system, National Hospital Cost Data Collection submission, official IHACPA model or jurisdictional ABF funding model. Cost should be interpreted alongside clinical context, safety, quality, patient complexity and service obligations.

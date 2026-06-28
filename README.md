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

## Workbook Structure

The Excel workbook contains six sheets:

1. **Executive Summary** — patient cost by service line with cost composition.
2. **Service and Activity Costing** — total, volume and average cost by activity group.
3. **Cost Drivers and High-Cost Encounters** — high-cost flag summary and drill-down slicers.
4. **ABF Cost vs Funding** — patient cost compared with synthetic ABF-style funding.
5. **Reconciliation and Data Quality** — GL reconciliation and open DQ issues.
6. **Methodology and Controls** — disclaimers, costing method and control notes.

## Validated Control Totals

| Measure | Value |
|---|---:|
| Patient-level cost | $78,818,041.68 |
| Direct cost | $1,648,836.61 |
| Indirect allocated cost | $71,988,922.78 |
| Overhead allocated cost | $5,180,282.29 |
| General-ledger amount | $82,837,467.56 |
| Unallocated cost | $70,900.00 |
| Reconciliation difference | approximately $0.00 |
| Encounters | 6,345 |
| High-cost encounters | 321 |
| Open data-quality issues | 4 |
| Data-quality financial impact | $70,900.00 |
| Synthetic ABF funding | $80,361,717.04 |
| Cost less synthetic funding | ($1,549,090.27) |

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


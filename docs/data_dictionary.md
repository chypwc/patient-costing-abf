# Data Dictionary

## Purpose

This dictionary explains the main business objects used in the synthetic patient-level costing and ABF decision-support project.

It is written for a costing analyst or finance stakeholder, not as a full physical database specification.

## Main Schemas

| Schema | Purpose |
|---|---|
| `landing` | Raw CSV-shaped tables loaded as text with load metadata. |
| `stg` | Typed staging tables after validation and reference checks. |
| `ref` | Governed reference/configuration tables for costing and reporting. |
| `dq` | Data-quality rules, validation results and issue register. |
| `costing` | Cost pools, drivers, assignments, allocations, patient-level costs and ABF comparison. |
| `recon` | Financial reconciliation outputs. |
| `reporting` | Excel-ready reporting views. |

## Source and Staging Objects

| Object | Description | Key fields |
|---|---|---|
| `patient_encounter` | Synthetic clinical encounter record. One row represents an encounter episode/month used for costing. | `encounter_id`, `patient_id`, `facility`, `service_line`, `care_type`, `admission_date`, `discharge_date`, `episode_month`, `activity_group_code` |
| `resource_usage` | Encounter-month resource measures used as allocation drivers. | `resource_usage_id`, `encounter_id`, `service_month`, `bed_days`, `theatre_minutes`, `imaging_weighted_units`, `pathology_weighted_units`, `pharmacy_units`, `medical_service_units`, `allied_health_units` |
| `direct_cost_detail` | Patient-specific cost records that can be directly assigned when a valid encounter exists. | `direct_cost_id`, `encounter_id`, `service_month`, `cost_centre_id`, `natural_account`, `direct_cost_type`, `quantity`, `amount` |
| `general_ledger_transaction` | Synthetic GL transactions forming the financial control total. | `gl_transaction_id`, `reporting_month`, `facility`, `cost_centre_id`, `natural_account`, `signed_amount`, `adjustment_type` |

Landing versions store values as text and preserve source-row metadata. Staging versions store typed values suitable for costing.

## Reference Objects

| Object | Description |
|---|---|
| `ref.service_line` | Service-line labels used for reporting and slicers. |
| `ref.care_type` | Valid care types such as inpatient, same-day, emergency and outpatient. |
| `ref.activity_group` | Synthetic activity group classification for clinical costing and ABF comparison. |
| `ref.cost_centre` | Governed cost-centre mapping to service line and cost pool. |
| `ref.account_mapping` | Natural account mapping to cost category, costing treatment and default driver. |
| `ref.allocation_rule` | Cost-pool allocation driver, eligible scope and rationale. |
| `ref.reporting_period` | Reporting month, period number and financial year. |
| `ref.abf_activity_group` | Synthetic ABF-style activity group weights and outlier parameters. |
| `ref.abf_adjustment_rule` | Synthetic ABF-style adjustment factors. |

## Data Quality Objects

| Object | Description |
|---|---|
| `dq.load_run` | One record per load/refresh run. |
| `dq.source_file_control` | Expected and actual row counts by source file. |
| `dq.validation_rule` | Governed list of validation rules and severity. |
| `dq.validation_result` | Summary result of each validation rule for a load run. |
| `dq.issue_register` | Row-level or business-key-level issues requiring review or resolution. |

### Blocking Flag

`blocking_flag = Y` means the affected row cannot safely flow into costing. `blocking_flag = N` means the process can continue, but the issue must remain visible for review.

## Costing Objects

| Object | Description |
|---|---|
| `costing.cost_pool` | Monthly GL cost grouped by cost pool, cost category and allocation driver. |
| `costing.encounter_driver` | Encounter-level driver units used to allocate shared cost pools. |
| `costing.direct_cost_assignment` | Direct costs successfully assigned to valid encounters. |
| `costing.indirect_cost_allocation` | Indirect and overhead costs allocated from cost pools to encounters. |
| `costing.patient_level_cost` | Final patient-level cost by encounter/month with direct, indirect, overhead and total cost. |
| `costing.unallocated_cost` | Costs retained for review because they could not be safely assigned or allocated. |
| `costing.abf_comparison` | Patient-level cost compared with synthetic ABF-style funding estimate. |

## Reconciliation Object

| Object | Description |
|---|---|
| `recon.costing_reconciliation` | Reconciles GL cost to direct assigned, indirect allocated, overhead allocated, unallocated and excluded amounts at `TOTAL` and `COST_POOL` levels. |

`TOTAL` rows prove the whole-run control total. `COST_POOL` rows support Excel
slicing by reporting month, facility, cost centre, cost pool and cost category.
Do not aggregate both levels together in the same PivotTable.

## Reporting Views

| View | Purpose |
|---|---|
| `reporting.vw_fact_patient_cost` | Main Excel fact view for patient-level cost analysis. |
| `reporting.vw_fact_abf_comparison` | Excel fact view for patient cost versus synthetic ABF funding. |
| `reporting.vw_fact_reconciliation` | Excel fact view for reconciliation and financial control reporting. Includes both `TOTAL` and `COST_POOL` levels. |
| `reporting.vw_fact_data_quality_issue` | Excel fact view for data-quality issue reporting. |
| `reporting.vw_dim_month` | Month/period dimension for slicers and relationships. |
| `reporting.vw_dim_facility` | Facility dimension. |
| `reporting.vw_dim_service_line` | Service-line dimension. |
| `reporting.vw_dim_care_type` | Care-type dimension. |
| `reporting.vw_dim_activity_group` | Activity-group dimension. |
| `reporting.vw_dim_cost_category` | Cost-category dimension for reconciliation reporting. |

These are views shaped for Excel's Data Model. They are not separate physical
fact and dimension tables in SQL Server.

## Key Measures

| Measure | Meaning |
|---|---|
| `direct_cost_amount` | Patient-specific cost directly linked to an encounter. |
| `indirect_cost_amount` | Shared patient-care cost allocated using resource drivers. |
| `overhead_cost_amount` | Support/overhead cost allocated after direct and indirect costing. |
| `total_patient_cost` | Direct plus indirect plus overhead patient-level cost. |
| `synthetic_nwau` | Synthetic National Weighted Activity Unit-style measure. |
| `synthetic_funding_amount` | Synthetic funding estimate using generated weights and base price. |
| `cost_funding_variance` | Patient cost minus synthetic funding. Positive values indicate cost above synthetic funding. |
| `unallocated_amount` | Cost retained for review rather than allocated without a valid rule or driver. |
| `reconciliation_difference` | Difference between GL control total and explained costing disposition. |

# 3-Day Closeout Checklist — Patient-Level Costing and ABF Decision Support

This is the compact execution tracker for closing the Costing Analyst portfolio project in three days.

The project should demonstrate the job-relevant story:

> A production-like SQL Server and Excel workflow that transforms clinical activity and general ledger data into reconciled patient-level costs, ABF decision-support metrics and management-ready service costing insights.

## Working Rules

- [x] Keep the project focused on clinical costing, financial reconciliation, data quality and management advice.
- [x] Use only synthetic data.
- [x] Use SQL Server for official costing, reconciliation, validation, statistics, flags and variance measures.
- [x] Use Excel for Power Query, Data Model relationships, slicers, PivotTables, charts, commentary and presentation.
- [x] Do not build a separate physical star-schema warehouse in SQL Server.
- [x] Publish Excel-ready fact and dimension views from the `reporting` schema.
- [x] Do not recreate allocation, reconciliation, validation or official variance logic in Excel.
- [x] Keep DHR, Health Information, NSQHS and CHS references as contextual awareness only; do not claim live CHS implementation.

---

# Current Progress Snapshot

## Completed or Mostly Completed

- [x] Project plan created and tailored to the Costing Analyst role.
- [x] Job description saved as `job_description_costing_analyst.md`.
- [x] Core business definitions documented.
- [x] Costing methodology documented in `docs/costing_methodology.md`.
- [x] Data-quality and reconciliation design documented in `docs/data_quality_and_reconciliation.md`.
- [x] Synthetic data design documented in `docs/synthetic_data_design.md`.
- [x] SQL workflow documented in `docs/sql_data_workflow.md`.
- [x] SQL environment documented in `docs/sql_environment.md`.
- [x] Synthetic patient-costing data script created.
- [x] Synthetic ABF funding data script created.
- [x] Synthetic data validation script created.
- [x] Raw CSV files generated in `data/raw/`.
- [x] Reference fixture CSV files generated in `data/reference/`.
- [x] Control files generated in `data/controls/`.
- [x] Expected ABF output files generated in `data/expected_outputs/`.
- [x] Synthetic validation reports generated in `outputs/validation/`.
- [x] SQL database creation script created: `sql/00_create_database.sql`.
- [x] SQL schema creation script created: `sql/01_create_schemas.sql`.
- [x] SQL table creation script started: `sql/02_create_tables.sql`.
- [x] Schemas confirmed in SQL Server: `landing`, `stg`, `ref`, `dq`, `costing`, `recon`, `reporting`.
- [x] Landing table designs created for the four operational source files.
- [x] Typed staging table designs created for the four operational source files.
- [x] Governed reference table designs created.
- [x] DQ control table designs created.
- [x] Reconciliation table designs created.
- [x] `costing.cost_pool` table design reviewed in SQL Server.

## Still Needed

- [ ] Finish the remaining costing tables and costing SQL scripts.
- [ ] Load CSVs into SQL Server.
- [ ] Promote landing rows into typed staging tables.
- [ ] Seed governed reference tables.
- [ ] Run practical DQ checks.
- [ ] Calculate cost pools, allocations, patient-level cost and unallocated costs.
- [ ] Calculate ABF cost-versus-funding comparison.
- [ ] Reconcile SQL outputs to GL control totals.
- [x] Create Excel-ready reporting views.
- [ ] Build the Excel workbook.
- [ ] Write concise README, management briefing and application wording.

---

# Day 1 — Finish Source Loading, Reference Data and Validation

Goal: SQL Server has loaded, typed and validated source data.

## 1.1 Finalise SQL Table Foundation

- [x] Confirm `sql/00_create_database.sql` exists.
- [x] Confirm `sql/01_create_schemas.sql` exists.
- [x] Confirm `sql/02_create_tables.sql` contains landing tables.
- [x] Confirm `sql/02_create_tables.sql` contains typed staging tables.
- [x] Confirm `sql/02_create_tables.sql` contains governed reference tables.
- [x] Confirm `sql/02_create_tables.sql` contains DQ and reconciliation control tables.
- [x] Add or confirm the remaining costing tables in SQL:
  - [x] `costing.cost_pool`
  - [x] `costing.encounter_driver`
  - [x] `costing.direct_cost_assignment`
  - [x] `costing.indirect_cost_allocation`
  - [x] `costing.patient_level_cost`
  - [x] `costing.unallocated_cost`
  - [x] `costing.abf_comparison`
- [x] Keep table definitions simple enough to complete in three days.

## 1.2 Load Source CSVs

- [x] Create `sql/03_load_landing_from_csv.sql`.
- [x] Load `data/raw/patient_encounter.csv` into `landing.patient_encounter`.
- [x] Load `data/raw/resource_usage.csv` into `landing.resource_usage`.
- [x] Load `data/raw/direct_cost_detail.csv` into `landing.direct_cost_detail`.
- [x] Load `data/raw/general_ledger_transaction.csv` into `landing.general_ledger_transaction`.
- [x] Record row counts in `dq.source_file_control`.
- [x] Compare SQL row counts to `data/controls/control_row_count.csv`.

## 1.3 Seed Governed Reference Data

- [x] Create `sql/04_seed_reference_data.sql`.
- [x] Seed `ref.service_line`.
- [x] Seed `ref.care_type`.
- [x] Seed `ref.activity_group`.
- [x] Seed `ref.cost_centre`.
- [x] Seed `ref.account_mapping`.
- [x] Seed `ref.allocation_rule`.
- [x] Seed `ref.reporting_period`.
- [x] Seed `ref.abf_activity_group`.
- [x] Seed `ref.abf_adjustment_rule`.
- [x] Confirm reference rows are governed fixtures, not automatically approved from raw distinct values.

## 1.4 Promote Landing to Typed Staging

- [x] Create `sql/05_promote_landing_to_staging.sql`.
- [x] Convert patient encounter dates and numeric fields with `TRY_CONVERT`.
- [x] Convert resource usage driver fields with `TRY_CONVERT`.
- [x] Convert direct cost quantities and amounts with `TRY_CONVERT`.
- [x] Convert GL reporting month and signed amount with `TRY_CONVERT`.
- [x] Keep failed rows visible as DQ issues.
- [x] Confirm promoted staging row counts reconcile to landing row counts.

## 1.5 Run Practical Data-Quality Checks

- [x] Create `sql/06_validate_staging_data.sql`.
- [x] Check missing mandatory encounter fields.
- [x] Check invalid admission/discharge date relationships.
- [x] Check resource usage points to a valid encounter.
- [x] Check direct cost points to a valid encounter.
- [x] Check GL cost centres exist in `ref.cost_centre`.
- [x] Check GL natural accounts exist in `ref.account_mapping`.
- [x] Check negative or invalid driver quantities.
- [x] Check zero-driver cost pools.
- [x] Store issues in `dq.issue_register`.
- [x] Confirm blocking issues are visible before costing proceeds.

## Day 1 Exit Criteria

- [x] Four raw CSV files are loaded into landing tables.
- [x] Valid rows are promoted to typed staging tables.
- [x] Reference tables are seeded.
- [x] DQ issues are recorded and explainable.
- [x] Source row counts and GL control totals are visible.

---

# Day 2 — Build Costing, ABF Comparison and Reconciliation

Goal: SQL Server produces official patient-level costs and reconciled management totals.

## 2.1 Build Cost Pools

- [x] Create `sql/07_build_costing_outputs.sql`.
- [x] Group GL transactions by reporting month, facility, cost centre, natural account, cost pool and cost category.
- [x] Apply account mapping and cost-centre mapping.
- [x] Store grouped GL amounts in `costing.cost_pool`.
- [x] Mark unmapped cost-centre or account amounts as unallocated/review.
- [x] Confirm cost-pool totals reconcile to staged GL totals.

## 2.2 Build Encounter Drivers

- [x] Derive encounter-count driver in SQL from `stg.patient_encounter`.
- [x] Derive bed-day driver from `stg.resource_usage`.
- [x] Derive theatre-minute driver from `stg.resource_usage`.
- [x] Derive imaging driver from `stg.resource_usage`.
- [x] Derive pathology driver from `stg.resource_usage`.
- [x] Derive pharmacy and allied-health drivers from `stg.resource_usage`.
- [x] Store driver rows in `costing.encounter_driver`.
- [x] Keep zero-driver pools unallocated instead of forcing allocation.

## 2.3 Assign Direct Costs

- [x] Assign valid direct cost records to encounters.
- [x] Store direct costs in `costing.direct_cost_assignment`.
- [x] Reject direct costs for unknown encounters.
- [x] Retain failed direct assignments as unallocated/review.
- [x] Confirm direct cost totals reconcile to source direct cost records.

## 2.4 Allocate Indirect Costs

- [x] Allocate ward/nursing cost by bed days.
- [x] Allocate theatre cost by theatre minutes.
- [x] Allocate imaging cost by imaging weighted units.
- [x] Allocate pathology cost by pathology weighted units.
- [x] Allocate pharmacy/allied-health cost by approved units where relevant.
- [x] Allocate patient administration by encounter count.
- [x] Store allocations in `costing.indirect_cost_allocation`.
- [x] Confirm allocation totals equal allocatable pool amounts.

## 2.5 Create Patient-Level Cost

- [x] Create encounter-level cost output in `costing.patient_level_cost`.
- [x] Separate direct, indirect, overhead if used, and total cost.
- [x] Include service line, care type, activity group and reporting month.
- [x] Include high-cost flag using a simple documented threshold.
- [x] Confirm patient-level totals aggregate back to costing pools.

## 2.6 Record Unallocated Costs

- [x] Create `costing.unallocated_cost`.
- [x] Record unmapped GL costs.
- [x] Record zero-driver pool amounts.
- [x] Record failed direct assignments.
- [x] Record excluded or review-only amounts.
- [x] Confirm unallocated costs remain visible in reconciliation.

## 2.7 Build ABF Decision-Support Comparison

- [x] Create `costing.abf_comparison`.
- [x] Import or stage expected ABF encounter funding from `data/expected_outputs/abf_encounter_funding.csv`, or calculate equivalent SQL output.
- [x] Compare patient-level cost to synthetic ABF funding by encounter.
- [x] Calculate cost-versus-funding variance.
- [x] Flag unfunded/review activity groups.
- [x] Keep wording clear: this is synthetic ABF decision support, not a production ABF payment model.

## 2.8 Reconcile Costing Outputs

- [x] Create `sql/08_reconcile_costing.sql`.
- [x] Reconcile GL total.
- [x] Reconcile direct assigned amount.
- [x] Reconcile indirect allocated amount.
- [x] Reconcile unallocated amount.
- [x] Calculate reconciliation difference.
- [x] Store results in `recon.costing_reconciliation`.
- [x] Confirm differences are zero or explained.

## Day 2 Exit Criteria

- [x] Every material GL amount is allocated, unallocated/review, or excluded with a reason.
- [x] Patient-level cost exists.
- [x] ABF cost-versus-funding comparison exists.
- [x] Reconciliation agrees with GL controls or differences are explained.
- [x] SQL outputs are ready for Excel reporting views.

---

# Day 3 — Build Excel Reporting and Portfolio Evidence

Goal: the project is understandable, job-relevant and ready to show.

## 3.1 Create Excel-Ready Reporting Views

- [x] Create `sql/09_create_reporting_views.sql`.
- [x] Create `reporting.vw_fact_patient_cost`.
- [x] Create `reporting.vw_fact_abf_comparison`.
- [x] Create `reporting.vw_fact_reconciliation`.
- [x] Create `reporting.vw_fact_data_quality_issue`.
- [x] Create `reporting.vw_dim_month`.
- [x] Create `reporting.vw_dim_facility`.
- [x] Create `reporting.vw_dim_service_line`.
- [x] Create `reporting.vw_dim_care_type`.
- [x] Create `reporting.vw_dim_activity_group`.
- [x] Create `reporting.vw_dim_cost_category`.
- [x] Confirm views include stable relationship keys and readable labels.
- [x] Confirm views do not duplicate patient-level costs.

## 3.2 Build Excel Workbook

- [x] Create `excel/Patient_Level_Costing_Analysis.xlsx`.
- [x] Connect to SQL reporting views with Power Query.
- [x] Load fact and dimension views into the Excel Data Model.
- [x] Create relationships between dimensions and facts.
- [x] Add practical slicers for period, service line, care type, activity group, funding status and issue status.
- [x] Build PivotTables and PivotCharts from the Data Model.
- [ ] Confirm workbook totals match SQL.
- [ ] Avoid formulas that recreate SQL allocation or reconciliation logic.

## 3.3 Workbook Sheets

- [x] Sheet 1: Executive Summary.
- [x] Sheet 2: Service and Activity Costing.
- [x] Sheet 3: Cost Drivers and High-Cost Encounters.
- [x] Sheet 4: ABF Cost vs Funding.
- [x] Sheet 5: Reconciliation and Data Quality.
- [x] Sheet 6: Methodology and Controls.
- [x] Add synthetic-data disclaimer.
- [x] Add safety, quality and clinical-context caveats.
- [ ] Add concise management findings and recommended actions.

## 3.4 Validate Workbook Against SQL

- [ ] Compare workbook GL total to SQL.
- [ ] Compare workbook allocated total to SQL.
- [ ] Compare workbook unallocated total to SQL.
- [ ] Compare workbook reconciliation difference to SQL.
- [ ] Compare workbook encounter counts to SQL.
- [ ] Compare workbook ABF variance totals to SQL.
- [ ] Test slicers and refresh.
- [ ] Record validation evidence.

## 3.5 Package Portfolio Evidence

- [x] Update `README.md`.
- [x] Create or finalise `docs/management_briefing.md`.
- [x] Create or finalise `docs/runbook.md`.
- [x] Create or finalise `docs/data_dictionary.md`.
- [x] Capture representative Excel screenshots if useful. Screenshots for workbook pages 1 to 5 are saved in `excel/`.
- [x] Export small representative samples from SQL if useful. Reporting views and workbook retained as primary evidence; separate samples not required for this closeout.
- [x] Confirm no real patient or CHS data exists.
- [x] Confirm no credentials or connection secrets are committed.

## 3.6 Prepare Application Wording

- [x] Draft one concise project summary.
- [x] Draft 3 to 5 CV bullets.
- [x] Map SQL Server and Excel evidence to Key Selection Criterion 1.
- [x] Map reconciliation, GL mappings and accounting controls to Key Selection Criterion 2.
- [x] Map variance analysis, DQ issues and recommendations to Key Selection Criterion 3.
- [x] Map simulated stakeholder and management communication artefacts to Key Selection Criterion 4.
- [x] Map safety, quality and patient-experience caveats to Key Selection Criterion 5.
- [x] Avoid claiming full ABF implementation or formal national costing compliance.

## Day 3 Exit Criteria

- [ ] Excel workbook refreshes successfully.
- [ ] Workbook totals agree with SQL.
- [ ] README and core docs explain the workflow.
- [ ] The project clearly demonstrates SQL Server, Excel, costing analysis, reconciliation and management advice.
- [ ] Application wording is truthful and role-aligned.

---

# Final Definition of Done

- [ ] Source data is synthetic and reproducible.
- [ ] SQL Server workflow is runnable in numbered scripts.
- [ ] Patient-level costs reconcile to GL controls.
- [ ] Unallocated and data-quality issues are visible.
- [ ] ABF comparison is clearly labelled as synthetic decision support.
- [ ] Excel workbook uses Power Query, Data Model relationships, slicers and PivotTables.
- [ ] Workbook does not duplicate SQL costing logic.
- [ ] Documentation is concise and consistent with the implemented state.
- [ ] Project evidence maps cleanly to the Costing Analyst job description.

# Patient-Level Costing Analysis and ABF Decision Support

## 1. Project Objective

Build a production-like clinical costing analysis workflow using synthetic hospital data, SQL Server Management Studio and Microsoft Excel.

The project will demonstrate how a Costing Analyst can:

- combine clinical activity, resource utilisation and general ledger data;
- validate the completeness and reliability of source data;
- assign and allocate hospital costs to patient encounters;
- reconcile patient-level costs to the general ledger;
- analyse cost, activity and resource-use patterns;
- compare patient-level cost with a clearly labelled synthetic ABF funding estimate;
- identify material variances, outliers and data-quality issues;
- communicate findings and practical advice to clinical, operational and financial stakeholders.

The principal business deliverable will be an Excel costing analysis workbook. SQL Server will contain the controlled data model, allocation logic, validation checks and reporting views that supply the workbook.

This is a portfolio-scale simulation of a hospital costing workflow. It will not be represented as a full Canberra Health Services costing system, a National Hospital Cost Data Collection submission or a complete Activity Based Funding model.

---

## 2. Alignment with the Costing Analyst Position

| Position requirement | Project evidence |
|---|---|
| Extract, validate and analyse large datasets using SQL Server Management Studio | Staging tables, transformation queries, validation procedures, allocation model and reporting views |
| Advanced Microsoft Excel skills | Power Query connections, structured tables, PivotTables, PivotCharts, formulas, slicers and reconciliation controls |
| Build a reliable and timely clinical costing allocation model | Repeatable cost-pool, direct-assignment and proportional-allocation workflow |
| Validate clinical and financial data | Data-quality rules, exception reports, control totals and general-ledger reconciliation |
| Analyse key issues, trends, inconsistencies and implications | Service-line, cost-category, monthly variance, cost-driver and high-cost episode analysis |
| Formulate sound advice | Management commentary and recommended actions included in the final workbook |
| Understand accounting and financial reporting practices | Chart of accounts, cost centres, cost pools, direct and indirect costs, adjustments and reconciliation |
| Understand Digital Health Record data | Synthetic encounter, care-type, service, theatre and diagnostic activity extracts with documented source lineage |
| Collaborate with diverse stakeholders | Simulated stakeholder requirements, costing-rule review and management briefing artefacts |
| Apply safety, quality and patient-centred thinking | Quality interpretation guardrails, privacy controls and explicit warnings against treating lower cost as automatically better care |

---

## 3. Intended Users

The outputs will be designed for:

- the Director, Costing and Performance;
- finance and costing staff;
- clinical service managers;
- operational managers;
- health information and data-quality staff.

Each audience needs a different level of detail. The Excel workbook will therefore provide an executive summary, analytical drill-downs and supporting reconciliation evidence.

---

## 4. Business Scenario

A hospital requires a monthly view of the cost and value of delivering services. Clinical activity and resource-use information is held separately from financial records. Management needs a controlled process that:

1. receives monthly clinical, activity and general-ledger extracts;
2. checks whether the data is complete and suitable for costing;
3. groups expenditure into valid cost pools;
4. directly assigns identifiable costs where possible;
5. allocates remaining costs using documented resource drivers;
6. reconciles the resulting patient-level costs to financial control totals;
7. presents cost and activity results with clear caveats and recommended actions.

The project will simulate this monthly costing cycle over a twelve-month reporting period.

---

## 5. Core Business Questions

The analysis will answer:

1. Do patient-level allocated costs reconcile to the general ledger?
2. What is the total and average cost by month, service line, care type and cost category?
3. Which services have material changes in cost, activity or unit cost?
4. Which cost categories and resource drivers explain those changes?
5. Which encounters are high-cost relative to clinically comparable encounters?
6. Are high-cost encounters explained by length of stay, theatre time, diagnostics, pharmacy or other resource use?
7. Which missing, invalid or inconsistent records reduce confidence in the costing results?
8. Which costs remain unallocated, and why?
9. How do average costs vary by activity group or synthetic DRG?
10. How does patient-level cost compare with synthetic weighted-activity funding?
11. What should management investigate or validate before relying on the results?

---

## 6. End-to-End Workflow

```text
Synthetic source extracts
        |
        v
SQL Server landing tables
        |
        v
Data-quality validation and source controls
        |
        v
Validated typed staging and reference tables
        |
        v
Reference mapping and cost-pool preparation
        |
        v
Direct cost assignment and indirect cost allocation
        |
        v
Patient-level costing and reconciliation
        |
        v
Controlled SQL reporting views
        |
        v
Excel Power Query refresh
        |
        v
Management costing workbook and advice
```

SQL Server will perform the costing calculations. Excel will consume curated reporting views rather than reproduce allocation logic in workbook formulas.

---

## 7. Data Scope

### 7.1 Clinical and Activity Data

The synthetic Digital Health Record-style extract will include:

- encounter and patient identifiers;
- facility and clinical service;
- admission and discharge dates;
- care type;
- episode month;
- synthetic diagnosis-related group;
- length of stay and bed days;
- discharge status;
- theatre minutes;
- imaging activity;
- pathology activity;
- pharmacy usage;
- allied health or other service units.

Encounter count will be derived in SQL from the encounter table at
`episode_month`; it will not be stored as a resource-usage source field.

All identifiers will be synthetic. No real patient information will be used.

### 7.2 Financial Data

The synthetic finance extract will include:

- accounting period;
- entity and facility;
- cost centre;
- natural account;
- account description;
- cost category;
- debit or credit amount;
- adjustment indicator;
- direct, indirect or overhead classification;
- financial control total.

Valid credits, reversals and adjustments will be retained and classified rather than automatically rejected as errors.

### 7.3 Reference and Costing Data

Reference data will include:

- cost-centre hierarchy;
- chart-of-accounts mapping;
- service-line mapping;
- care-type reference;
- activity-group or synthetic DRG reference;
- cost-pool definitions;
- allocation rules;
- allocation-driver priority;
- effective dates;
- data-quality thresholds;
- reconciliation tolerances.

### 7.4 Synthetic ABF Data

The same encounter population will support a separate synthetic ABF layer containing:

- synthetic activity-group weights;
- a synthetic base price;
- transparent demonstration adjustments;
- weighted activity by encounter;
- estimated synthetic funding;
- funding calculation status and control totals.

This layer demonstrates how patient-level cost can be compared with activity-based funding. It is not an official NWAU calculation, IHACPA price-weight table or real funding entitlement.

---

## 8. SQL Server Data Model

### 8.1 Schemas

| Schema | Purpose |
|---|---|
| `landing` | Exact CSV values loaded as nullable text before validation |
| `stg` | Validated and typed transactional data |
| `ref` | Validated and typed mappings and business rules |
| `dq` | Load audit, source controls, validation outcomes and issue management |
| `costing` | Cost pools, driver calculations, allocations and patient-level results |
| `recon` | Source financial controls and GL-to-costing reconciliation |
| `reporting` | Curated views consumed by Excel |

This separation keeps source assurance, costing calculations and financial reconciliation independently reviewable.

### 8.2 Principal Tables

#### Landing

- `landing.patient_encounter`
- `landing.resource_usage`
- `landing.direct_cost_detail`
- `landing.general_ledger_transaction`
- corresponding landing tables for every reference CSV

#### Staging

- `stg.patient_encounter`
- `stg.resource_usage`
- `stg.direct_cost_detail`
- `stg.general_ledger_transaction`

#### Reference

- `ref.cost_centre`
- `ref.account_mapping`
- `ref.service_line`
- `ref.care_type`
- `ref.activity_group`
- `ref.abf_activity_group`
- `ref.abf_adjustment_rule`
- `ref.allocation_rule`
- `ref.reporting_period`

#### Costing

- `costing.cost_pool`
- `costing.encounter_driver`
- `costing.direct_cost_assignment`
- `costing.indirect_cost_allocation`
- `costing.patient_level_cost`
- `costing.unallocated_cost`

#### Control and Quality

- `dq.load_run`
- `dq.source_file_control`
- `dq.validation_result`
- `dq.issue_register`

#### Reconciliation

- `recon.gl_control_total`
- `recon.costing_reconciliation`

### 8.3 Required Technical Controls

The database design will include:

- primary and foreign keys;
- uniqueness constraints;
- valid-date checks;
- accepted-value checks;
- decimal financial data types;
- load and reporting-period identifiers;
- effective dates on mappings and allocation rules;
- indexes on encounter, period, cost-centre and activity-group keys;
- repeatable scripts that can rebuild the portfolio database;
- stored procedures or controlled scripts for each monthly costing run;
- an audit record showing whether each processing stage passed or failed.

---

## 9. Costing Methodology

### 9.1 Costing Hierarchy

Costs will be processed in the following order:

1. validate financial and clinical inputs;
2. map general-ledger transactions to cost centres, accounts and cost categories;
3. form monthly cost pools;
4. assign patient-identifiable costs directly;
5. allocate remaining patient-care costs using resource drivers;
6. allocate approved overhead pools using documented secondary drivers;
7. retain costs that cannot be allocated in an exception table;
8. aggregate results to encounter, service-line and activity-group levels;
9. reconcile all allocated and unallocated amounts to the general ledger.

### 9.2 Direct Cost Assignment

Where a cost can be linked to an encounter, it will be assigned directly. Examples may include:

- encounter-specific pharmacy use;
- prostheses or high-cost consumables;
- patient-specific imaging or pathology activity.

Direct assignment will be preferred over proportional allocation when reliable encounter-level information exists.

### 9.3 Indirect Cost Allocation

The basic allocation formula will be:

```text
Encounter allocated cost
=
Monthly cost-pool amount
×
Encounter driver units
÷
Total eligible driver units for the same pool and period
```

Proposed drivers:

| Cost pool | Primary driver |
|---|---|
| Ward and nursing | Bed days |
| Theatre | Theatre minutes |
| Imaging | Imaging examinations or weighted units |
| Pathology | Pathology tests or weighted units |
| Pharmacy | Pharmacy units |
| Allied health | Service units |
| Patient administration | Encounter count |
| Approved overhead | Weighted service units or allocated patient-care cost |

Every rule will contain a business rationale, effective period and exception treatment.

### 9.4 Zero-Driver and Unallocated Costs

If a cost pool has expenditure but no valid driver units:

- the cost will not be silently spread across unrelated encounters;
- the full amount will be written to `costing.unallocated_cost`;
- the issue will appear in the data-quality register;
- the reconciliation will still account for the amount;
- management will receive a recommended follow-up action.

### 9.5 Reconciliation Equation

```text
General ledger total
=
Directly assigned cost
+ Indirectly allocated cost
+ Unallocated cost
+ Approved exclusions or adjustments
+ Reconciliation difference
```

Reconciliation will be assessed at:

- reporting-period level;
- facility level;
- cost-centre level;
- cost-pool and cost-category level.

The final tolerance will be documented before implementation. The workbook will display both the dollar difference and percentage difference.

---

## 10. Validation and Data-Quality Framework

### 10.1 Clinical Data Checks

- duplicate encounter identifiers;
- missing or invalid service lines;
- invalid care types;
- discharge before admission;
- invalid episode-month assignment;
- negative length of stay or bed days;
- missing activity-group classification;
- activity recorded outside the encounter period;
- implausible resource-use values.

Same-day episodes and valid zero-day cases will be distinguished from genuine errors.

### 10.2 Financial Data Checks

- duplicate transactions;
- unmapped accounts or cost centres;
- inactive mappings with current financial activity;
- missing cost-pool classification;
- unexplained credit or adjustment entries;
- source totals that do not agree with supplied control totals;
- financial activity outside the reporting period.

### 10.3 Allocation Checks

- missing or overlapping allocation rules;
- expired rules;
- invalid allocation drivers;
- expenditure with zero eligible driver units;
- encounters receiving costs from ineligible services or periods;
- material unallocated balances;
- reconciliation outside tolerance.

### 10.4 Issue Register

Each issue will record:

- issue category;
- affected period and source;
- severity;
- affected row count;
- estimated financial impact;
- owner or stakeholder group;
- recommended action;
- resolution status;
- effect on interpretation.

---

## 11. Reporting Views

Excel will connect to the following controlled SQL views:

| View | Purpose |
|---|---|
| `reporting.vw_executive_costing_summary` | Headline cost, activity, unit-cost and reconciliation measures |
| `reporting.vw_service_line_costing` | Cost and activity comparison by service line and care type |
| `reporting.vw_activity_group_costing` | Encounter and average cost analysis by synthetic DRG or activity group |
| `reporting.vw_cost_category_analysis` | Composition and movement of major cost categories |
| `reporting.vw_monthly_cost_variance` | Month-on-month cost, activity and unit-cost variance |
| `reporting.vw_cost_driver_analysis` | Relationship between resource use and allocated cost |
| `reporting.vw_high_cost_encounter_review` | High-cost cases within comparable activity groups |
| `reporting.vw_reconciliation_summary` | GL, allocated, unallocated and variance totals |
| `reporting.vw_data_quality_issues` | Material data and costing exceptions |
| `reporting.vw_cost_to_funding_variance` | Patient-level cost compared with synthetic ABF funding |

High-cost encounters will be identified within comparable groups, such as care type and activity group, rather than against one hospital-wide average.

---

## 12. Final Excel Costing Analysis Workbook

The main business-facing deliverable will be:

```text
Patient_Level_Costing_Analysis.xlsx
```

### Sheet 1 — Executive Summary

For senior management:

- total GL cost;
- allocated and unallocated cost;
- reconciliation status;
- encounters and activity volume;
- average cost per encounter;
- major cost categories;
- material monthly variances;
- high-priority data-quality issues;
- concise findings and recommended actions.

### Sheet 2 — Service and Activity Costing

For costing, finance and operational review:

- cost by service line, care type and activity group;
- encounter count and relevant activity denominator;
- average cost per encounter;
- cost per bed day for appropriate admitted activity only;
- cost-category mix;
- comparison with prior periods;
- filters for month, facility, service and care type.

### Sheet 3 — Cost Drivers and High-Cost Encounters

- bed days, theatre minutes, diagnostics and other resource drivers;
- cost-driver contribution;
- high-cost encounters within comparable groups;
- major cost category for each flagged encounter;
- possible analytical explanation;
- indicator that clinical validation is required before drawing conclusions.

### Sheet 4 — Monthly Variance Analysis

- total cost variance;
- activity-volume variance;
- unit-cost variance;
- service-line contribution to change;
- materiality flags;
- commentary on key movements and implications.

### Sheet 5 — Reconciliation and Data Quality

- GL-to-costing reconciliation;
- allocated, unallocated and excluded costs;
- variance by period, cost centre and cost pool;
- unresolved data-quality issues;
- estimated financial impact;
- recommended owners and follow-up actions.

### Sheet 6 — Methodology and Controls

- source and refresh information;
- costing rules and drivers;
- reconciliation tolerance;
- definitions;
- assumptions and exclusions;
- privacy and safety considerations;
- interpretation caveats.

### Excel Features

The workbook will demonstrate:

- Power Query connections to SQL reporting views;
- refreshable queries;
- structured tables;
- PivotTables and PivotCharts;
- slicers and filters;
- XLOOKUP where an auditable workbook lookup is appropriate;
- SUMIFS and controlled reconciliation formulas;
- conditional formatting for material exceptions;
- protected formula areas;
- visible refresh date and reporting period;
- clear separation between data, calculations and presentation.

The workbook will not contain a second, competing version of the SQL allocation model.

---

## 13. Management Analysis and Advice

The project will not stop at producing charts. It will include a short management briefing that answers:

- What changed?
- Why did it change?
- How material is the change?
- How reliable is the underlying information?
- What are the operational or financial implications?
- What should management validate or do next?

Advice will distinguish between:

- a confirmed analytical finding;
- a plausible explanation requiring clinical validation;
- a data-quality limitation;
- an issue requiring finance, health information or operational follow-up.

---

## 14. Stakeholder and Clinical Validation Simulation

To demonstrate the collaborative nature of the role, the project will include:

- a stakeholder map;
- a costing requirements and decisions log;
- questions for clinical managers about care pathways and resource use;
- questions for finance about account mappings and adjustments;
- questions for health information staff about activity classification and data quality;
- a costing-rule validation record;
- a one-page management briefing written for a non-technical audience.

These artefacts will be clearly labelled as a simulated portfolio exercise, not real CHS consultation.

---

## 15. Safety, Quality and Patient Experience

The project will apply the following interpretation principles:

- lower cost does not automatically represent better performance;
- high-cost care is not automatically inefficient or inappropriate;
- costing results must be considered with clinical complexity, quality, outcomes and patient experience;
- data-quality failures can lead to misleading resource-allocation decisions;
- patient-level data must be de-identified and access-controlled;
- operational recommendations must not compromise safe or appropriate care.

The management workbook will contain an explicit caveat requiring clinical context before action is taken on high-cost encounters or apparent service variation.

---

## 16. Production-Like Operating Controls

The project will simulate a controlled monthly process:

1. create a new load-run record;
2. load source extracts into staging;
3. compare source row counts and control totals;
4. run blocking and non-blocking data-quality checks;
5. apply effective-dated mappings;
6. build cost pools;
7. run direct assignment and indirect allocation;
8. capture unallocated costs;
9. reconcile to the general ledger;
10. publish reporting views only when critical controls pass;
11. refresh the Excel workbook;
12. record sign-off, caveats and unresolved issues.

The repository will contain a runbook explaining how to execute, review and troubleshoot this process.

---

## 17. Repository Structure

```text
cost_analysis_abf/
|
|-- README.md
|-- PROJECT_PLAN.md
|-- job_description_costing_analyst.md
|
|-- docs/
|   |-- costing_methodology.md
|   |-- synthetic_data_design.md
|   |-- data_dictionary.md
|   |-- data_quality_and_reconciliation.md
|   |-- stakeholder_validation.md
|   |-- management_briefing.md
|   `-- runbook.md
|
|-- data/
|   |-- raw/
|   |-- reference/          # design fixtures, not production batch inputs
|   |-- controls/
|   |-- expected_outputs/
|   `-- sample_exports/
|
|-- scripts/
|   |-- generate_patient_costing_data.py
|   |-- generate_abf_funding_data.py
|   `-- validate_synthetic_data.py
|
|-- sql/
|   |-- 00_create_database.sql
|   |-- 01_create_schemas.sql
|   |-- 02_create_tables.sql
|   |-- 03_seed_reference_data.sql
|   |-- 04_load_raw_data.sql
|   |-- 05_validate_and_promote.sql
|   |-- 06_prepare_cost_pools.sql
|   |-- 07_allocate_patient_costs.sql
|   |-- 08_reconcile_costing.sql
|   `-- 09_create_reporting_views.sql
|
|-- excel/
|   `-- Patient_Level_Costing_Analysis.xlsx
|
`-- outputs/
    |-- patient_level_cost_sample.csv
    |-- reconciliation_sample.csv
    |-- data_quality_issue_sample.csv
    `-- validation/
        |-- synthetic_data_validation_report.md
        `-- synthetic_data_validation_report.json
```

---

## 18. Delivery Phases

### Phase 1 — Confirm the Costing Design

- agree on scope, business questions and reporting period;
- define accounting, activity and resource-use concepts;
- define cost pools and allocation drivers;
- define reconciliation and data-quality rules;
- confirm workbook users and decisions supported.

**Exit criterion:** the costing methodology is reviewable before SQL implementation begins.

### Phase 2 — Build the Source and Reference Model

- define the synthetic source contracts and expected test scenarios;
- generate and validate the four operational source extracts;
- calculate source row counts and financial control totals;
- load source extracts into nullable-text landing tables;
- validate and promote accepted rows into typed staging tables;
- create and seed governed reference mappings and rules through reviewed SQL;
- compare raw classifications with approved reference values;
- implement keys, constraints and audit fields;
- prepare the data dictionary.

**Exit criterion:** landing totals agree with source controls, validation outcomes
account for every source row, accepted rows are promoted to typed staging, and
governed reference data is reproducible from SQL.

### Phase 3 — Build Validation and Costing Logic

- implement source validation;
- form monthly cost pools;
- assign direct costs;
- allocate indirect and overhead costs;
- capture zero-driver and unallocated costs;
- build patient-level costing output.

**Exit criterion:** all cost movements are traceable from the GL to the patient-level result or an explicit exception.

### Phase 4 — Reconcile and Analyse

- reconcile by month, facility, cost centre and cost pool;
- build service-line, activity-group and cost-category analysis;
- identify material trends and comparable high-cost encounters;
- record data limitations and analytical implications.

**Exit criterion:** reconciliation is within the agreed tolerance or all residual differences are documented.

### Phase 5 — Build and Validate the Excel Workbook

- connect Power Query to reporting views;
- build analytical tables, pivots, charts and filters;
- add management commentary and recommendations;
- test refresh behaviour and workbook controls;
- check figures against SQL outputs.

**Exit criterion:** the workbook refreshes successfully and key totals agree with SQL and the GL controls.

### Phase 6 — Package the Portfolio Evidence

- complete the README and methodology;
- complete the runbook and data dictionary;
- add stakeholder-validation and management-briefing artefacts;
- capture representative screenshots;
- prepare truthful CV and selection-criteria wording.

**Exit criterion:** another analyst can understand the workflow, reproduce the result and explain its limitations.

---

## 19. Definition of Done

The project is complete when:

- SQL Server contains a repeatable, auditable costing workflow;
- source, mapping and allocation exceptions are visible;
- direct, allocated and unallocated costs are separately identifiable;
- patient-level costs reconcile to the general ledger within tolerance;
- results can be traced from a management total to the underlying cost pool and driver;
- the Excel workbook refreshes from controlled reporting views;
- the workbook explains cost, activity, variance and data reliability;
- management findings include implications and recommended actions;
- clinical and safety caveats are visible;
- documentation enables another analyst to rerun the process;
- all portfolio claims accurately describe synthetic and simulated work.

---

## 20. Out of Scope

The first version will not include:

- real patient or CHS data;
- a live Digital Health Record connection;
- a full enterprise clinical costing platform;
- a formal National Hospital Cost Data Collection submission;
- a complete Independent Health and Aged Care Pricing Authority compliance assessment;
- a production ABF payment calculation;
- machine learning;
- cloud infrastructure;
- Power BI;
- automated deployment orchestration.

These exclusions keep the project centred on the position's main requirements: SQL, Excel, clinical costing analysis, financial reconciliation, data quality and management advice.

---

## 21. Project Positioning

The project should be described as:

> A production-like SQL Server and Excel clinical costing workflow that validates clinical and financial data, assigns and allocates general-ledger expenditure to patient encounters, reconciles results to financial control totals, and provides management analysis of cost, activity, resource utilisation, variance and data quality.

It should not be described as:

> A complete hospital costing system, a real CHS implementation, or a full ABF pricing and funding solution.

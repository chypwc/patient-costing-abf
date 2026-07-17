# Phase 1 Design and Business Definitions

## 1. Purpose

This document records the approved design assumptions for the patient-level costing portfolio project before SQL implementation begins.

The project story is:

> A production-like SQL Server and Excel workflow that transforms clinical activity and general ledger data into reconciled patient-level costs and management-ready service costing insights.

The final business-facing deliverable will be `Patient_Level_Costing_Analysis.xlsx`. SQL Server will own the data model, validation, costing calculations, reconciliation and reporting views. Excel will provide analysis, presentation, commentary and recommended actions.

The project is a synthetic portfolio simulation. It is not a real Canberra Health Services implementation, a formal national costing submission or a complete ABF payment model.

## 2. Users and Decisions

| User | Information required | Decisions supported |
|---|---|---|
| Director, Costing and Performance | Executive cost, activity, reconciliation, major variance and data-quality summary | Prioritise investigation, request validation and direct follow-up |
| Finance and costing staff | GL mappings, cost pools, allocation methods, unallocated costs and reconciliation detail | Review costing completeness, accounting treatment and allocation rules |
| Clinical service managers | Service cost, activity, resource drivers and comparable high-cost encounters | Validate whether results reflect care pathways and service delivery |
| Operational managers | Monthly activity, total cost, unit cost and service contribution to change | Identify services requiring operational review |
| Health information and data-quality staff | Missing classifications, invalid dates, unmatched activity and issue impact | Correct source-data and classification problems |

The workbook may support investigation, validation and planning discussions. It must not, without additional clinical and organisational evidence:

- conclude that a high-cost encounter was inefficient;
- recommend reducing a clinical resource solely because its allocated cost is high;
- assess quality of care or individual performance;
- make a real funding, pricing or budget decision;
- represent synthetic DRG analysis as an official ABF calculation.

## 3. Reporting Scope

| Design element | Decision |
|---|---|
| Reporting period | Synthetic financial year 1 July 2024 to 30 June 2025 |
| Period grain | Twelve calendar months |
| Facility | One synthetic tertiary facility: `Central Hospital` |
| Service lines | Medical, Surgical, Women's and Children's, Mental Health, Emergency, Outpatients |
| Care types | Inpatient, Same-day, Emergency, Outpatient |
| Activity groups | Nine synthetic activity groups plus an `Unclassified` exception group |
| Financial grain | One GL transaction by accounting period, facility, cost centre and natural account |
| Patient-cost grain | One encounter, period, cost pool and cost category |

The nine synthetic activity groups will represent common, understandable resource profiles:

1. complex medical;
2. general medical;
3. major surgical;
4. minor surgical or same-day;
5. maternity;
6. paediatric;
7. mental health;
8. emergency activity;
9. outpatient activity.

These are portfolio classifications, not official AR-DRGs.

Required cost categories are:

- nursing;
- medical;
- theatre;
- imaging;
- pathology;
- pharmacy;
- allied health;
- patient administration;
- prostheses;
- overhead.

Costs must reconcile by reporting period, facility, cost centre, cost pool and cost category. Prior-month comparisons are required for monthly cost, activity and unit-cost analysis. High-cost comparisons must use care type and activity group rather than a hospital-wide average.

## 4. Core Business Definitions

| Term | Definition |
|---|---|
| Encounter | A synthetic episode of hospital service with one encounter identifier and defined start and end dates. |
| Episode month | The reporting month to which an encounter or encounter-level resource record is assigned under the documented monthly attribution rule. |
| Patient-level cost | The sum of direct and allocated costs assigned to an encounter for a reporting period. |
| Cost centre | An organisational unit used to record and manage expenditure in the general ledger. |
| Natural account | The chart-of-accounts code that identifies the economic nature of a transaction, such as salaries, supplies or contracted services. |
| Cost category | A reporting classification that groups related costs, such as nursing, theatre or pharmacy. |
| Cost pool | A monthly grouping of GL expenditure with a common service purpose and costing treatment. |
| Direct cost | A cost that can be reliably linked to a specific encounter using an encounter identifier and valid source record. |
| Indirect patient-care cost | A patient-care cost that cannot be linked directly and is allocated using a documented resource driver. |
| Overhead cost | A supporting or corporate cost allocated after patient-care costs using an approved secondary driver. |
| Allocation driver | A measurable unit used to distribute a cost pool across eligible encounters. |
| Unallocated cost | A valid cost that cannot be assigned because a required mapping, eligible encounter or driver is unavailable. |
| Approved exclusion or adjustment | A documented GL amount kept outside patient costing or separately adjusted under an approved rule while remaining visible in reconciliation. |
| Reconciliation difference | GL cost less direct cost, indirect cost, overhead cost, unallocated cost and approved exclusions or adjustments. |
| Material variance | A monthly movement that exceeds both the approved dollar and percentage analysis thresholds. |
| High-cost encounter | An encounter whose total cost exceeds the agreed percentile within the same care type and activity group. |

For this portfolio:

- a material monthly variance is an absolute change of at least `$100,000` and at least `10%`;
- a high-cost encounter is above the `95th percentile` within its comparable care-type and activity-group cohort;
- cohorts with fewer than 20 encounters will be reported as insufficient for a stable high-cost comparison.

## 5. SQL Architecture

The database name will be:

```text
CostAnalysisABF
```

The approved SQL design uses seven schemas:

| Schema | Responsibility |
|---|---|
| `landing` | Exact CSV values stored as nullable text before validation |
| `stg` | Validated and typed transactional data |
| `ref` | Validated and typed mappings, classifications, periods and rules |
| `dq` | Load audit, controls, validation outcomes and issue management |
| `costing` | Cost pools, drivers, allocations and patient-level results |
| `recon` | GL-to-costing reconciliation evidence |
| `reporting` | Curated views consumed by Excel |

The design deliberately separates data quality and reconciliation from costing calculations.

## 6. Design Boundaries

- Source records first land as text in `landing`.
- Valid transactional rows are promoted to typed `stg` tables.
- Effective-dated business rules and mappings reside in `ref`.
- Validation and load controls reside in `dq`.
- Costing transformations reside in `costing`.
- Financial reconciliation resides in `recon`.
- Excel receives data only from `reporting` views.
- Excel may calculate presentation checks but will not reproduce cost allocation.
- Every result must retain reporting-period and load-run traceability.
- No real patient data, credentials or CHS operational information will be used.

## 7. Assumptions and Limitations

- The synthetic DHR-style data is simplified and does not reproduce a real DHR data model.
- The synthetic activity groups illustrate costing comparisons but are not official national classifications.
- Monthly encounter attribution is simplified for a portfolio model; multi-month stays will use monthly resource records rather than assigning all activity to discharge month.
- Allocation drivers are selected for transparency and educational value.
- Clinical appropriateness, outcomes and patient experience are not measured by cost alone.
- The workbook supports management review, not automated operational decisions.

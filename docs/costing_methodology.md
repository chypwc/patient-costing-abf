# Costing Methodology

## 1. Objective

The costing model converts synthetic general-ledger expenditure, clinical encounters and resource-use records into traceable patient-level costs. It prioritises direct assignment, uses documented drivers for shared costs, preserves unresolved amounts and reconciles all financial values to source control totals.

## 2. Source-to-Reporting Workflow

```text
Synthetic clinical, resource and GL extracts
        |
        v
landing text tables
        |
        v
dq validation and source controls
        |
        v
typed stg transactions and ref rules
        |
        v
costing monthly cost pools and encounter drivers
        |
        v
Direct assignment, indirect allocation and overhead allocation
        |
        v
Patient-level costs and unallocated costs
        |
        v
recon financial reconciliation
        |
        v
reporting views
        |
        v
Excel management workbook
```

## 3. Costing Hierarchy

Each monthly costing run will:

1. create a load-run record;
2. load and validate clinical, resource and financial inputs;
3. compare row counts and financial totals with source controls;
4. map GL transactions to cost centres, cost categories and cost pools;
5. assign encounter-identifiable costs directly;
6. calculate encounter driver units for shared cost pools;
7. allocate indirect patient-care costs;
8. allocate approved overhead costs;
9. retain failed or zero-driver amounts as unallocated costs;
10. aggregate patient-level results;
11. reconcile the costing disposition to the GL;
12. publish reporting views only when blocking controls pass.

## 4. Cost Pools and Allocation Drivers

| Cost pool | Costing treatment | Primary driver | Eligible population | Rationale |
|---|---|---|---|---|
| Ward and nursing | Indirect allocation | Bed days | Inpatient and same-day encounters with valid bed-day records | Nursing and ward resource consumption generally increases with time receiving admitted care |
| Emergency nursing | Indirect allocation | Encounter count | Emergency encounters | Encounter volume provides a transparent first-version emergency driver |
| Outpatient nursing | Indirect allocation | Encounter count | Outpatient encounters | Encounter volume provides a transparent first-version clinic driver |
| Medical | Indirect allocation | Medical service units | Encounters with valid weighted medical activity | Weighted service units approximate medical effort across care types |
| Theatre | Indirect allocation | Theatre minutes | Surgical encounters with valid theatre activity | Theatre time represents use of staff, room and equipment capacity |
| Imaging | Direct where linked; otherwise indirect | Imaging weighted units | Encounters with valid imaging activity | Exam volume and complexity approximate imaging resource use |
| Pathology | Direct where linked; otherwise indirect | Pathology weighted units | Encounters with valid pathology activity | Test volume and complexity approximate pathology resource use |
| Pharmacy | Direct where linked; otherwise indirect | Pharmacy units | Encounters with valid pharmacy use | Patient-specific use is preferred; units provide a fallback for shared pharmacy cost |
| Allied health | Indirect allocation | Service units | Encounters receiving allied health activity | Service contacts or weighted units approximate professional effort |
| Patient administration | Indirect allocation | Encounter count | Valid encounters in the relevant service and period | Administrative effort is approximated by processed encounter volume |
| Overhead | Secondary allocation | Pre-overhead patient-care cost | Encounters with assigned patient-care cost | Allocates approved support cost in proportion to the cost base supported |

Allocation rules may change over time. Each rule must contain:

- a unique rule identifier;
- cost pool and cost category;
- allocation method and driver;
- eligible service or care-type scope;
- business rationale;
- effective-from date;
- effective-to date;
- active status.

Rules must not overlap for the same cost pool, scope and reporting date.

`Encounter count` is derived in SQL from `patient_encounter.csv`; it is not a
source field in `resource_usage.csv`. Each encounter contributes one unit in
its nominated `episode_month`. Additional resource months for a multi-month
stay do not create additional encounter-count units.

## 5. Direct Cost Assignment

Direct assignment takes precedence when a reliable encounter link exists.

Included direct-cost examples are:

- encounter-specific pharmacy issues;
- prostheses and high-cost consumables recorded against an encounter;
- encounter-specific imaging or pathology charges where a cost value is supplied.

A valid direct assignment requires:

- a valid encounter identifier;
- a reporting period consistent with the encounter or monthly resource record;
- a mapped cost centre, account, cost category and cost pool;
- a non-null signed amount;
- one unambiguous source record;
- no prior assignment of the same source cost.

Failed direct assignments are written to `costing.unallocated_cost` with the failure reason and linked issue-register record. They are not moved automatically into a proportional cost pool.

## 6. Indirect Cost Allocation

For each cost pool and month:

```text
Encounter allocation share
=
Encounter eligible driver units
/
Total eligible driver units
```

```text
Encounter allocated cost
=
Allocatable cost-pool amount
×
Encounter allocation share
```

Calculations will retain at least six decimal places during processing. Currency presentation will be rounded to two decimal places only in reporting outputs.

Missing driver values are treated as follows:

- a missing value for an otherwise eligible encounter is a data-quality issue;
- a missing value is not silently converted to a positive driver;
- where business meaning supports it, a genuine absence of activity may be represented as zero;
- only positive valid units contribute to a proportional allocation denominator.

## 7. Zero-Driver and Unallocated Costs

A cost remains unallocated when:

- the cost centre or account is unmapped;
- no effective allocation rule exists;
- the cost pool has no eligible encounters;
- total valid driver units equal zero;
- a direct assignment cannot be matched reliably;
- a blocking data-quality failure prevents safe allocation.

The full amount is recorded with:

- load run and reporting period;
- source transaction or cost-pool identifier;
- facility, cost centre and cost category;
- unallocated reason;
- signed financial amount;
- severity and recommended owner;
- resolution status.

Unallocated cost remains part of financial reconciliation and is visible to management.

## 8. Overhead Allocation

Only overhead pools explicitly approved in the reference rules are allocated.

The first version uses pre-overhead patient-care cost as the secondary driver:

```text
Encounter overhead share
=
Encounter pre-overhead patient-care cost
/
Total pre-overhead patient-care cost
```

This method is transparent and prevents circular allocation. Encounters with no valid patient-care cost do not receive overhead. An overhead pool with no valid denominator remains unallocated.

## 9. Financial Treatment

GL amounts use a signed convention:

- debits that increase expense are positive;
- credits and reversals that reduce expense are negative.

Credits are not errors merely because they are negative. Transactions carry an adjustment type such as:

- standard expense;
- credit;
- reversal;
- journal adjustment.

Included entries are operating expenses mapped to approved patient-care or overhead pools for the reporting period. The following may be approved exclusions:

- capital expenditure;
- financing items;
- depreciation if excluded from the simplified model;
- non-patient activity outside the project scope;
- clearly identified prior-period adjustments not attributed to the reporting year.

Every exclusion must retain its original amount and an exclusion reason.

Financial values will use `DECIMAL(19,6)` during loading, allocation and reconciliation. Reporting views may present currency to two decimal places. Reconciliation uses unrounded processing values.

## 10. Reconciliation

The control equation is:

```text
GL cost
=
Directly assigned cost
+ Indirectly allocated cost
+ Allocated overhead
+ Unallocated cost
+ Approved exclusions or adjustments
+ Reconciliation difference
```

Reconciliation is stored at two levels:

| Level | Meaning |
|---|---|
| `TOTAL` | Whole-run reconciliation from GL amount to direct assigned, indirect allocated, overhead, unallocated, excluded and reconciliation difference. |
| `COST_POOL` | Detailed reconciliation by reporting month, facility, cost centre, cost pool and cost category. |

Excel uses the `TOTAL` level for the headline control table and the `COST_POOL`
level for slicers and cost-category review. The two levels must not be summed
together.

The status rules are:

| Status | Rule |
|---|---|
| Pass | Absolute difference is at most `$1.00` |
| Review | The row is retained for review, usually because a detailed cost-pool row has an unresolved mapping, allocation or unallocated-cost treatment |

Approved exclusions, adjustments and unallocated costs do not disappear from reconciliation; they are separate, visible components of the equation.

## 11. Interpretation

- Lower cost does not automatically indicate better performance.
- High cost does not automatically indicate inefficiency.
- Cost variation must be considered with activity mix, clinical complexity, safety, quality and patient experience.
- High-cost encounter explanations are analytical hypotheses until clinically validated.
- Synthetic findings must not be presented as real CHS results.

# Data Quality and Reconciliation Design

Data-quality objects reside in `dq`. Financial control and reconciliation
objects reside in `recon`. Costing tables contain only costing calculations and
results.

## 1. Control Approach

Data-quality rules are classified as blocking or non-blocking.

- A **blocking** failure means the costing run or affected cost pool cannot be published safely.
- A **non-blocking** warning allows processing to continue, but the issue and its effect on interpretation must be visible.

## 2. Severity Levels

| Severity | Meaning |
|---|---|
| Critical | Financial completeness or allocation integrity is compromised; publication is blocked |
| High | A material cost or population is affected and requires resolution or explicit approval |
| Medium | Results remain usable with a documented limitation |
| Low | Minor anomaly with negligible effect on totals or interpretation |

## 3. Duplicate Rules

- Encounter identifiers must be unique in the encounter source.
- GL transaction identifiers must be unique within a source system and load run.
- Resource records must be unique at their declared source grain.
- Exact duplicate source records are blocking when they affect financial totals or allocation units.
- Potential business duplicates are warnings until reviewed.

## 4. Mandatory Clinical Fields

The following are mandatory for a costable encounter:

- encounter identifier;
- synthetic patient identifier;
- facility;
- service line;
- care type;
- encounter start date;
- encounter end date where applicable;
- episode month;
- activity group or an explicit `Unclassified` value.

Valid care types are:

- `Inpatient`;
- `Same-day`;
- `Emergency`;
- `Outpatient`.

## 5. Date and Episode Rules

- Encounter end date must not precede start date.
- Episode month must fall within the reporting year.
- Resource activity month must overlap the encounter service period or an approved related period.
- Same-day encounters may have zero calendar-day length of stay.
- A zero-day same-day encounter is valid when start and end dates match and care type is `Same-day`.
- Negative length of stay or negative bed days are invalid.
- Multi-month admitted encounters may contribute monthly resource records to more than one episode month.

## 6. Resource-Use Rules

Initial portfolio plausibility ranges are:

| Measure | Valid range per encounter-month | Treatment outside range |
|---|---:|---|
| Bed days | 0 to 31 | High warning; negative value is blocking |
| Theatre minutes | 0 to 1,440 | High warning; negative value is blocking |
| Imaging weighted units | 0 to 100 | Medium warning; negative value is blocking |
| Pathology weighted units | 0 to 500 | Medium warning; negative value is blocking |
| Pharmacy units | 0 to 10,000 | Medium warning; negative value is blocking unless documented reversal logic applies |
| Allied health service units | 0 to 200 | Medium warning; negative value is blocking |

These thresholds identify records for review; they are not clinical limits.

## 7. Mandatory Financial Mappings

Every included GL transaction requires:

- reporting period;
- facility;
- cost centre;
- natural account;
- signed amount;
- active cost-centre mapping;
- active account-to-category mapping;
- cost-pool classification;
- direct, indirect, overhead or exclusion treatment.

Missing mappings are blocking for the affected amount. The amount is retained as unallocated until resolved.

## 8. Allocation-Rule Validity

An allocation rule is valid when:

- the reporting date falls between its effective dates;
- the cost pool and driver are recognised;
- the eligible population is defined;
- the business rationale is present;
- no overlapping rule exists for the same scope;
- the rule is active.

A missing, invalid or overlapping rule blocks allocation of the affected pool.

## 9. Unallocated-Cost Materiality

Unallocated cost is always reported.

| Status | Threshold |
|---|---|
| Low | Less than `$1,000` and less than `0.01%` of monthly GL cost |
| Medium | At least `$1,000` or at least `0.01%` |
| High | At least `$10,000` or at least `0.10%` |
| Critical | At least `$100,000` or at least `1.00%`, or any unexplained amount preventing financial completeness |

The higher severity produced by the dollar or percentage test applies.

## 10. Issue Register

Each issue will contain:

- issue identifier;
- load-run identifier;
- rule identifier;
- issue category;
- source table or costing stage;
- reporting period;
- facility;
- cost centre or cost pool where relevant;
- severity;
- blocking flag;
- affected record count;
- signed financial impact;
- issue description;
- recommended owner;
- recommended action;
- status;
- resolution note;
- effect on interpretation;
- created and resolved timestamps.

## 11. Reporting Readiness Gates

The reporting views can be created as database objects at any time, but a run
should only be used for workbook reporting when:

- source row counts have been checked and loaded GL transactions are available;
- blocking promotion failures are reviewed;
- material mapping issues are visible in the DQ issue register or unallocated-cost table;
- zero-driver pools are retained as unallocated rather than spread without a driver;
- reconciliation differences are immaterial or explained;
- the load run is complete.

Non-blocking warnings may proceed when they are recorded and visible in the workbook.

## 12. Reconciliation Evidence

For every costing run, the project stores:

- source row counts;
- loaded GL totals;
- mapped and unmapped GL amounts;
- direct-cost totals;
- indirect-allocation totals;
- overhead totals;
- unallocated totals;
- approved exclusions and adjustments;
- reconciliation difference and percentage;
- status at each required reconciliation level.

`recon.costing_reconciliation` stores:

| Level | Purpose |
|---|---|
| `TOTAL` | Whole-run GL control proof. |
| `COST_POOL` | Detailed reconciliation by month, facility, cost centre, cost pool and cost category. |

The Excel workbook must agree with the SQL reconciliation result and must not
sum `TOTAL` and `COST_POOL` rows together.

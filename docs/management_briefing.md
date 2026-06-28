# Management Briefing

## Purpose

This briefing summarises the synthetic patient-level costing and ABF decision-support workflow developed for the Costing Analyst portfolio project.

The project demonstrates how hospital finance, costing and decision-support teams can combine clinical activity, resource-use and general-ledger data to produce reconciled patient-level costs and management-ready analysis.

## Headline Findings

- The costing model produced patient-level costs for **6,345 encounters**.
- Total patient-level cost was **$78.82m**.
- The model reconciled to the general ledger with an immaterial rounding difference.
- **$70.9k** remained visible as unallocated cost because it could not be safely assigned or allocated.
- **321 encounters** were flagged as high cost using a cohort-based 95th percentile method.
- Synthetic ABF-style funding was **$80.36m**, compared with patient-level cost of **$78.81m** for funded encounters.
- One encounter remained **UNFUNDED_REVIEW** due to unclassified activity.

## Cost Profile

| Measure | Amount |
|---|---:|
| Direct assigned cost | $1.65m |
| Indirect allocated cost | $71.99m |
| Overhead allocated cost | $5.18m |
| Total patient-level cost | $78.82m |
| Unallocated cost | $0.07m |
| General-ledger control total | $82.84m |

Most patient-level cost is allocated through indirect cost pools, which is realistic for a first-pass hospital costing model where many shared clinical and support costs are not directly linked to a single encounter.

## Data Quality and Control Issues

| Issue | Treatment | Financial impact |
|---|---|---:|
| Resource usage row failed staging promotion | Blocking issue; affected row excluded from typed staging | $0 |
| Direct cost row failed staging promotion | Blocking issue; direct cost not assigned to patient | $900 |
| Unknown cost centre in GL | Non-blocking review; retained as unallocated | $25,000 |
| Zero-driver cost pool | Non-blocking review; retained as unallocated | $45,000 |

The key control principle is that unresolved amounts are not hidden or spread across patients without a defensible driver. They remain visible for finance and costing review.

## ABF Decision-Support Interpretation

The ABF comparison is synthetic and should not be interpreted as an official funding result. It is useful as a decision-support view because it compares patient-level cost against activity group weights, adjustment factors and a synthetic price.

The output can help managers identify activity groups where cost appears materially above or below the synthetic funding estimate, then investigate whether the difference is explained by patient complexity, service model, length of stay, resource intensity, data quality or costing-rule design.

## Recommended Actions

1. Review the unknown cost centre and update governed cost-centre mapping if appropriate.
2. Investigate the zero-driver allied health cost pool and confirm whether an eligible activity population exists.
3. Correct or approve the failed direct cost assignment for the unknown encounter.
4. Review the high-cost encounter cohort with clinical and operational context before drawing efficiency conclusions.
5. Treat the ABF comparison as a triage tool, not as an official funding or performance judgement.

## Caveat

All figures are synthetic. This project demonstrates the analyst workflow, controls and communication style, not real hospital cost or funding performance.


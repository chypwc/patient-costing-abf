#!/usr/bin/env python3
"""Generate reproducible synthetic source data for patient-level costing.

This script creates source-like CSV files only. It does not perform the final
patient-level allocation, which remains the responsibility of SQL Server.
"""

from __future__ import annotations

import argparse
import csv
import json
import random
from collections import defaultdict
from datetime import UTC, date, datetime, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path


SEED = 20250622
FY_START = date(2024, 7, 1)
FY_END = date(2025, 6, 30)
FACILITY = "Central Hospital"

MONTH_VOLUMES = [460, 475, 490, 505, 520, 535, 550, 545, 610, 570, 555, 530]

ACTIVITY_PROFILES = {
    "AG01": {
        "name": "Complex Medical",
        "service_line": "Medical",
        "care_type": "Inpatient",
        "weight": 14,
        "los": (6, 4, 30),
    },
    "AG02": {
        "name": "General Medical",
        "service_line": "Medical",
        "care_type": "Inpatient",
        "weight": 20,
        "los": (3, 1, 15),
    },
    "AG03": {
        "name": "Major Surgical",
        "service_line": "Surgical",
        "care_type": "Inpatient",
        "weight": 10,
        "los": (7, 3, 30),
    },
    "AG04": {
        "name": "Minor Surgical or Same-day",
        "service_line": "Surgical",
        "care_type": "Same-day",
        "weight": 12,
        "los": (0, 0, 0),
    },
    "AG05": {
        "name": "Maternity",
        "service_line": "Women's and Children's",
        "care_type": "Inpatient",
        "weight": 8,
        "los": (3, 1, 8),
    },
    "AG06": {
        "name": "Paediatric",
        "service_line": "Women's and Children's",
        "care_type": "Inpatient",
        "weight": 8,
        "los": (2, 1, 12),
    },
    "AG07": {
        "name": "Mental Health",
        "service_line": "Mental Health",
        "care_type": "Inpatient",
        "weight": 7,
        "los": (10, 2, 35),
    },
    "AG08": {
        "name": "Emergency or Non-admitted",
        "service_line": "Emergency",
        "care_type": "Emergency",
        "weight": 16,
        "los": (0, 0, 0),
    },
    "AG09": {
        "name": "Outpatient",
        "service_line": "Outpatients",
        "care_type": "Outpatient",
        "weight": 5,
        "los": (0, 0, 0),
    },
}

SERVICE_LINES = [
    ("Medical", "Admitted medical services"),
    ("Surgical", "Admitted and same-day surgical services"),
    ("Women's and Children's", "Maternity and paediatric services"),
    ("Mental Health", "Admitted mental health services"),
    ("Emergency", "Emergency care"),
    ("Outpatients", "Non-admitted outpatient care"),
]

CARE_TYPES = [
    ("Inpatient", "Formal admitted care with one or more overnight stays"),
    ("Same-day", "Formal admitted care with admission and discharge on the same day"),
    ("Emergency", "Emergency department care"),
    ("Outpatient", "Non-admitted scheduled care"),
]

COST_CENTRES = [
    ("CC_MED_WARD", "Medical Ward", "Medical", "WARD_NURSING", "Y"),
    ("CC_SURG_WARD", "Surgical Ward", "Surgical", "WARD_NURSING", "Y"),
    ("CC_WCH_WARD", "Women's and Children's Ward", "Women's and Children's", "WARD_NURSING", "Y"),
    ("CC_MH_WARD", "Mental Health Ward", "Mental Health", "WARD_NURSING", "Y"),
    ("CC_EMERGENCY", "Emergency Department", "Emergency", "EMERGENCY_CARE", "Y"),
    ("CC_OUTPATIENT", "Outpatient Clinics", "Outpatients", "OUTPATIENT_CARE", "Y"),
    ("CC_MEDICAL", "Medical Workforce", "All", "MEDICAL", "Y"),
    ("CC_THEATRE", "Operating Theatre", "Surgical", "THEATRE", "Y"),
    ("CC_IMAGING", "Medical Imaging", "All", "IMAGING", "Y"),
    ("CC_PATHOLOGY", "Pathology Laboratory", "All", "PATHOLOGY", "Y"),
    ("CC_PHARMACY", "Pharmacy", "All", "PHARMACY", "Y"),
    ("CC_ALLIED", "Allied Health", "All", "ALLIED_HEALTH", "Y"),
    ("CC_ALLIED_UNUSED", "Special Rehabilitation Unit", "Specialist Rehabilitation", "ALLIED_SPECIAL", "Y"),
    ("CC_ADMIN", "Patient Administration", "All", "PATIENT_ADMIN", "Y"),
    ("CC_ICT", "ICT Services", "All", "OVERHEAD", "Y"),
    ("CC_FACILITIES", "Facilities Management", "All", "OVERHEAD", "Y"),
    ("CC_ORTHO", "Orthopaedic Surgery", "Surgical", "PROSTHESIS_DIRECT", "Y"),
]

ACCOUNT_ROWS = [
    ("500100", "Nursing salaries", "Nursing", "Indirect", "bed_days"),
    ("500110", "Agency nursing expense", "Nursing", "Indirect", "bed_days"),
    ("500200", "Medical salaries", "Medical", "Indirect", "medical_service_units"),
    ("510100", "Theatre supplies and staffing", "Theatre", "Indirect", "theatre_minutes"),
    ("510200", "Imaging services", "Imaging", "Indirect", "imaging_weighted_units"),
    ("510300", "Pathology services", "Pathology", "Indirect", "pathology_weighted_units"),
    ("510400", "Pharmaceuticals", "Pharmacy", "Indirect", "pharmacy_units"),
    ("510500", "Allied health services", "Allied Health", "Indirect", "allied_health_units"),
    ("520100", "Patient administration", "Patient Administration", "Indirect", "encounter_count"),
    ("530100", "ICT services", "Overhead", "Overhead", "pre_overhead_cost"),
    ("530200", "Facilities management", "Overhead", "Overhead", "pre_overhead_cost"),
    ("540100", "Prostheses and implants", "Prosthesis", "Direct", "direct_assignment"),
    ("540200", "Patient-specific pharmaceuticals", "Pharmacy", "Direct", "direct_assignment"),
    ("540300", "Patient-specific imaging", "Imaging", "Direct", "direct_assignment"),
]

POOL_RULES = [
    ("RULE_WARD", "WARD_NURSING", "Nursing", "bed_days", "Inpatient|Same-day", "Ward nursing use follows admitted bed days"),
    ("RULE_EMERGENCY", "EMERGENCY_CARE", "Nursing", "encounter_count", "Emergency", "Emergency nursing follows emergency encounters"),
    ("RULE_OUTPATIENT", "OUTPATIENT_CARE", "Nursing", "encounter_count", "Outpatient", "Clinic nursing follows outpatient encounters"),
    ("RULE_MEDICAL", "MEDICAL", "Medical", "medical_service_units", "All", "Medical effort follows weighted medical service units"),
    ("RULE_THEATRE", "THEATRE", "Theatre", "theatre_minutes", "Surgical", "Theatre resource use follows procedure duration"),
    ("RULE_IMAGING", "IMAGING", "Imaging", "imaging_weighted_units", "All", "Imaging use follows weighted examinations"),
    ("RULE_PATHOLOGY", "PATHOLOGY", "Pathology", "pathology_weighted_units", "All", "Pathology use follows weighted tests"),
    ("RULE_PHARMACY", "PHARMACY", "Pharmacy", "pharmacy_units", "All", "Shared pharmacy cost follows dispensed units"),
    ("RULE_ALLIED", "ALLIED_HEALTH", "Allied Health", "allied_health_units", "All", "Allied health use follows service units"),
    ("RULE_ALLIED_SPECIAL", "ALLIED_SPECIAL", "Allied Health", "allied_health_units", "Specialist Rehabilitation", "Deliberate zero-driver test pool"),
    ("RULE_ADMIN", "PATIENT_ADMIN", "Patient Administration", "encounter_count", "All", "Administration follows encounter volume"),
    ("RULE_OVERHEAD", "OVERHEAD", "Overhead", "pre_overhead_cost", "All", "Overhead follows pre-overhead patient-care cost"),
]


def month_start(offset: int) -> date:
    year = FY_START.year + (FY_START.month - 1 + offset) // 12
    month = (FY_START.month - 1 + offset) % 12 + 1
    return date(year, month, 1)


def next_month(value: date) -> date:
    return date(value.year + (value.month == 12), 1 if value.month == 12 else value.month + 1, 1)


def month_end(value: date) -> date:
    return next_month(value) - timedelta(days=1)


def money(value: float | Decimal) -> str:
    return str(Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))


def weighted_choice(rng: random.Random, items: list[str], weights: list[int]) -> str:
    return rng.choices(items, weights=weights, k=1)[0]


def clamp_int(value: float, minimum: int, maximum: int) -> int:
    return max(minimum, min(maximum, int(round(value))))


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def generate_encounters(rng: random.Random) -> list[dict]:
    codes = list(ACTIVITY_PROFILES)
    weights = [ACTIVITY_PROFILES[code]["weight"] for code in codes]
    rows: list[dict] = []
    encounter_number = 1

    for month_index, volume in enumerate(MONTH_VOLUMES):
        start = month_start(month_index)
        end = month_end(start)
        for _ in range(volume):
            code = weighted_choice(rng, codes, weights)
            profile = ACTIVITY_PROFILES[code]
            admission = start + timedelta(days=rng.randint(0, (end - start).days))
            care_type = profile["care_type"]
            service_line = profile["service_line"]

            if care_type in {"Same-day", "Emergency", "Outpatient"}:
                length_of_stay = 0
            else:
                mean, minimum, maximum = profile["los"]
                length_of_stay = clamp_int(rng.lognormvariate(max(0.1, mean / 5), 0.45), minimum, maximum)

            discharge = min(admission + timedelta(days=length_of_stay), FY_END + timedelta(days=20))
            age = (
                rng.randint(0, 16)
                if code == "AG06"
                else rng.randint(18, 44)
                if code == "AG05"
                else rng.randint(18, 92)
            )
            indigenous = "Y" if rng.random() < 0.035 else "N"
            remoteness = rng.choices(
                ["Major Cities", "Inner Regional", "Outer Regional", "Remote"],
                weights=[72, 18, 8, 2],
                k=1,
            )[0]
            high_complexity = rng.random() < (0.14 if code in {"AG01", "AG03", "AG07"} else 0.04)
            hac_flag = "Y" if rng.random() < (0.035 if high_complexity else 0.01) else "N"

            rows.append(
                {
                    "encounter_id": f"ENC{encounter_number:07d}",
                    "patient_id": f"PAT{rng.randint(1, 4200):07d}",
                    "facility": FACILITY,
                    "service_line": service_line,
                    "care_type": care_type,
                    "admission_date": admission.isoformat(),
                    "discharge_date": discharge.isoformat(),
                    "episode_month": start.isoformat(),
                    "activity_group_code": code,
                    "length_of_stay": length_of_stay,
                    "separation_status": "Discharged",
                    "age_years": age,
                    "indigenous_status": indigenous,
                    "remoteness_area": remoteness,
                    "high_complexity_flag": "Y" if high_complexity else "N",
                    "hospital_acquired_complication_flag": hac_flag,
                }
            )
            encounter_number += 1

    # One deliberately unclassified but otherwise valid record.
    rows[-1]["activity_group_code"] = "UNCLASSIFIED"

    # Force a clear multi-month inpatient example.
    multi = next(row for row in rows if row["care_type"] == "Inpatient" and row["episode_month"] == "2025-01-01")
    multi["admission_date"] = "2025-01-28"
    multi["discharge_date"] = "2025-02-06"
    multi["length_of_stay"] = 9
    multi["high_complexity_flag"] = "Y"

    return rows


def resource_profile(row: dict, rng: random.Random) -> dict[str, int]:
    code = row["activity_group_code"]
    los = int(row["length_of_stay"])
    complexity = 1.65 if row["high_complexity_flag"] == "Y" else 1.0
    base = {
        "AG01": (0, 2, 8, 16, 10, 5),
        "AG02": (0, 1, 5, 9, 6, 3),
        "AG03": (180, 2, 7, 12, 9, 4),
        "AG04": (65, 1, 3, 4, 3, 1),
        "AG05": (35, 1, 4, 7, 4, 2),
        "AG06": (15, 1, 4, 7, 4, 2),
        "AG07": (0, 0, 2, 5, 8, 8),
        "AG08": (0, 1, 3, 4, 2, 1),
        "AG09": (0, 1, 2, 2, 1, 1),
        "UNCLASSIFIED": (0, 0, 1, 1, 1, 0),
    }[code]
    theatre, imaging, pathology, pharmacy, medical, allied = base
    def noise(mean: float) -> int:
        if mean <= 0:
            return 0
        return max(0, int(round(rng.gauss(mean * complexity, max(0.5, mean * 0.22)))))

    return {
        "theatre_minutes": noise(theatre),
        "imaging_weighted_units": noise(imaging),
        "pathology_weighted_units": noise(pathology),
        "pharmacy_units": noise(pharmacy),
        "medical_service_units": max(1, noise(medical + los)),
        "allied_health_units": noise(allied + los / 2),
    }


def generate_resource_usage(encounters: list[dict], rng: random.Random) -> list[dict]:
    rows: list[dict] = []
    resource_number = 1
    for encounter in encounters:
        admission = date.fromisoformat(encounter["admission_date"])
        discharge = date.fromisoformat(encounter["discharge_date"])
        profile = resource_profile(encounter, rng)
        current = date(admission.year, admission.month, 1)
        final_month = date(discharge.year, discharge.month, 1)
        months = []
        while current <= final_month:
            months.append(current)
            current = next_month(current)

        for index, service_month in enumerate(months):
            if encounter["care_type"] in {"Same-day", "Emergency", "Outpatient"}:
                bed_days = 0
            else:
                overlap_start = max(admission, service_month)
                overlap_end = min(discharge, month_end(service_month))
                bed_days = max(0, (overlap_end - overlap_start).days + (1 if overlap_end >= overlap_start else 0))
                if index == len(months) - 1 and bed_days > 0:
                    bed_days = max(1, bed_days - 1)

            divisor = len(months)
            rows.append(
                {
                    "resource_usage_id": f"RES{resource_number:08d}",
                    "encounter_id": encounter["encounter_id"],
                    "service_month": service_month.isoformat(),
                    "bed_days": bed_days,
                    "theatre_minutes": profile["theatre_minutes"] // divisor if index else profile["theatre_minutes"] - (profile["theatre_minutes"] // divisor) * (divisor - 1),
                    "imaging_weighted_units": profile["imaging_weighted_units"] // divisor if index else profile["imaging_weighted_units"] - (profile["imaging_weighted_units"] // divisor) * (divisor - 1),
                    "pathology_weighted_units": profile["pathology_weighted_units"] // divisor if index else profile["pathology_weighted_units"] - (profile["pathology_weighted_units"] // divisor) * (divisor - 1),
                    "pharmacy_units": profile["pharmacy_units"] // divisor if index else profile["pharmacy_units"] - (profile["pharmacy_units"] // divisor) * (divisor - 1),
                    "medical_service_units": profile["medical_service_units"] // divisor if index else profile["medical_service_units"] - (profile["medical_service_units"] // divisor) * (divisor - 1),
                    "allied_health_units": profile["allied_health_units"] // divisor if index else profile["allied_health_units"] - (profile["allied_health_units"] // divisor) * (divisor - 1),
                }
            )
            resource_number += 1

    # Intentional invalid resource value for validation testing.
    rows[100]["pathology_weighted_units"] = -2
    return rows


def generate_direct_costs(encounters: list[dict], rng: random.Random) -> list[dict]:
    rows: list[dict] = []
    selected = [row for row in encounters if row["activity_group_code"] in {"AG03", "AG04"}]
    rng.shuffle(selected)
    direct_number = 1

    for encounter in selected[:240]:
        prosthesis = rng.uniform(1800, 12500) if encounter["activity_group_code"] == "AG03" else rng.uniform(250, 2200)
        rows.append(
            {
                "direct_cost_id": f"DIR{direct_number:07d}",
                "encounter_id": encounter["encounter_id"],
                "service_month": encounter["episode_month"],
                "cost_centre_id": "CC_ORTHO",
                "natural_account": "540100",
                "direct_cost_type": "Prosthesis or implant",
                "quantity": 1,
                "amount": money(prosthesis),
            }
        )
        direct_number += 1

    pharmacy_candidates = encounters.copy()
    rng.shuffle(pharmacy_candidates)
    for encounter in pharmacy_candidates[:420]:
        rows.append(
            {
                "direct_cost_id": f"DIR{direct_number:07d}",
                "encounter_id": encounter["encounter_id"],
                "service_month": encounter["episode_month"],
                "cost_centre_id": "CC_PHARMACY",
                "natural_account": "540200",
                "direct_cost_type": "Patient-specific medicine",
                "quantity": rng.randint(1, 12),
                "amount": money(rng.uniform(45, 2800)),
            }
        )
        direct_number += 1

    diagnostic_candidates = encounters.copy()
    rng.shuffle(diagnostic_candidates)
    for encounter in diagnostic_candidates[:180]:
        rows.append(
            {
                "direct_cost_id": f"DIR{direct_number:07d}",
                "encounter_id": encounter["encounter_id"],
                "service_month": encounter["episode_month"],
                "cost_centre_id": "CC_IMAGING",
                "natural_account": "540300",
                "direct_cost_type": "Patient-specific imaging",
                "quantity": 1,
                "amount": money(rng.uniform(120, 1650)),
            }
        )
        direct_number += 1

    rows.append(
        {
            "direct_cost_id": f"DIR{direct_number:07d}",
            "encounter_id": "ENC_NOT_FOUND",
            "service_month": "2025-02-01",
            "cost_centre_id": "CC_PHARMACY",
            "natural_account": "540200",
            "direct_cost_type": "Patient-specific medicine",
            "quantity": 1,
            "amount": "900.00",
        }
    )
    return rows


def gl_base_amount(cost_centre: str, account: str) -> float:
    base = {
        ("CC_MED_WARD", "500100"): 720000,
        ("CC_MED_WARD", "500110"): 42000,
        ("CC_SURG_WARD", "500100"): 680000,
        ("CC_SURG_WARD", "500110"): 38000,
        ("CC_WCH_WARD", "500100"): 500000,
        ("CC_WCH_WARD", "500110"): 25000,
        ("CC_MH_WARD", "500100"): 390000,
        ("CC_EMERGENCY", "500100"): 610000,
        ("CC_OUTPATIENT", "500100"): 260000,
        ("CC_MEDICAL", "500200"): 1050000,
        ("CC_THEATRE", "510100"): 530000,
        ("CC_IMAGING", "510200"): 260000,
        ("CC_PATHOLOGY", "510300"): 310000,
        ("CC_PHARMACY", "510400"): 390000,
        ("CC_ALLIED", "510500"): 250000,
        ("CC_ADMIN", "520100"): 230000,
        ("CC_ICT", "530100"): 190000,
        ("CC_FACILITIES", "530200"): 240000,
    }
    return base[(cost_centre, account)]


def generate_gl(
    direct_costs: list[dict],
    rng: random.Random,
) -> list[dict]:
    rows: list[dict] = []
    transaction_number = 1
    recurring = [
        ("CC_MED_WARD", "500100"), ("CC_MED_WARD", "500110"),
        ("CC_SURG_WARD", "500100"), ("CC_SURG_WARD", "500110"),
        ("CC_WCH_WARD", "500100"), ("CC_WCH_WARD", "500110"),
        ("CC_MH_WARD", "500100"), ("CC_EMERGENCY", "500100"),
        ("CC_OUTPATIENT", "500100"), ("CC_MEDICAL", "500200"),
        ("CC_THEATRE", "510100"), ("CC_IMAGING", "510200"),
        ("CC_PATHOLOGY", "510300"), ("CC_PHARMACY", "510400"),
        ("CC_ALLIED", "510500"), ("CC_ADMIN", "520100"),
        ("CC_ICT", "530100"), ("CC_FACILITIES", "530200"),
    ]
    centre_lookup = {row[0]: row for row in COST_CENTRES}
    account_lookup = {row[0]: row for row in ACCOUNT_ROWS}

    for month_index in range(12):
        reporting_month = month_start(month_index).isoformat()
        seasonal = 1 + (month_index - 5.5) * 0.004
        for cost_centre, account in recurring:
            amount = gl_base_amount(cost_centre, account) * seasonal * rng.uniform(0.965, 1.04)
            if reporting_month == "2025-03-01" and (cost_centre, account) in {
                ("CC_SURG_WARD", "500110"),
                ("CC_THEATRE", "510100"),
            }:
                amount *= 1.38
            rows.append(
                {
                    "gl_transaction_id": f"GL{transaction_number:08d}",
                    "reporting_month": reporting_month,
                    "entity": "Synthetic Health Service",
                    "facility": FACILITY,
                    "cost_centre_id": cost_centre,
                    "natural_account": account,
                    "account_description": account_lookup[account][1],
                    "signed_amount": money(amount),
                    "adjustment_type": "Standard expense",
                    "source_reference": f"MONTHLY-{reporting_month}-{cost_centre}-{account}",
                }
            )
            transaction_number += 1

    grouped_direct: dict[tuple[str, str, str], Decimal] = defaultdict(Decimal)
    for row in direct_costs:
        grouped_direct[(row["service_month"], row["cost_centre_id"], row["natural_account"])] += Decimal(row["amount"])
    for (reporting_month, cost_centre, account), amount in sorted(grouped_direct.items()):
        rows.append(
            {
                "gl_transaction_id": f"GL{transaction_number:08d}",
                "reporting_month": reporting_month,
                "entity": "Synthetic Health Service",
                "facility": FACILITY,
                "cost_centre_id": cost_centre,
                "natural_account": account,
                "account_description": account_lookup[account][1],
                "signed_amount": money(amount),
                "adjustment_type": "Standard expense",
                "source_reference": f"DIRECT-CONTROL-{reporting_month}-{cost_centre}-{account}",
            }
        )
        transaction_number += 1

    special_rows = [
        ("2024-11-01", "CC_PHARMACY", "510400", -24000, "Credit", "Supplier credit"),
        ("2025-01-01", "CC_THEATRE", "510100", -18000, "Reversal", "Reversal of duplicate accrual"),
        ("2025-04-01", "CC_MED_WARD", "500110", 32000, "Journal adjustment", "Agency invoice true-up"),
        ("2025-06-01", "CC_ALLIED_UNUSED", "510500", 45000, "Standard expense", "Zero-driver test pool"),
        ("2025-02-01", "CC_UNKNOWN", "510100", 25000, "Standard expense", "Unmapped cost-centre test"),
    ]
    for reporting_month, cost_centre, account, amount, adjustment, reference in special_rows:
        rows.append(
            {
                "gl_transaction_id": f"GL{transaction_number:08d}",
                "reporting_month": reporting_month,
                "entity": "Synthetic Health Service",
                "facility": FACILITY,
                "cost_centre_id": cost_centre,
                "natural_account": account,
                "account_description": account_lookup[account][1],
                "signed_amount": money(amount),
                "adjustment_type": adjustment,
                "source_reference": reference,
            }
        )
        transaction_number += 1

    return rows


def reference_rows() -> dict[str, tuple[list[str], list[dict]]]:
    activity_rows = [
        {
            "activity_group_code": code,
            "activity_group_name": profile["name"],
            "default_service_line": profile["service_line"],
            "default_care_type": profile["care_type"],
            "official_classification_flag": "N",
        }
        for code, profile in ACTIVITY_PROFILES.items()
    ] + [{
        "activity_group_code": "UNCLASSIFIED",
        "activity_group_name": "Unclassified exception",
        "default_service_line": "",
        "default_care_type": "",
        "official_classification_flag": "N",
    }]

    cost_centre_rows = [
        {
            "cost_centre_id": code,
            "cost_centre_name": name,
            "service_line": service,
            "cost_pool_code": pool,
            "active_flag": active,
            "effective_from": FY_START.isoformat(),
            "effective_to": FY_END.isoformat(),
        }
        for code, name, service, pool, active in COST_CENTRES
    ]
    account_rows = [
        {
            "natural_account": account,
            "account_description": description,
            "cost_category": category,
            "costing_treatment": treatment,
            "default_driver": driver,
            "active_flag": "Y",
        }
        for account, description, category, treatment, driver in ACCOUNT_ROWS
    ]
    allocation_rows = [
        {
            "allocation_rule_id": rule,
            "cost_pool_code": pool,
            "cost_category": category,
            "allocation_driver": driver,
            "eligible_scope": scope,
            "business_rationale": rationale,
            "effective_from": FY_START.isoformat(),
            "effective_to": FY_END.isoformat(),
            "active_flag": "Y",
        }
        for rule, pool, category, driver, scope, rationale in POOL_RULES
    ]
    reporting_rows = []
    for index in range(12):
        start = month_start(index)
        reporting_rows.append(
            {
                "reporting_month": start.isoformat(),
                "period_start": start.isoformat(),
                "period_end": month_end(start).isoformat(),
                "financial_year": "2024-25",
                "period_number": index + 1,
            }
        )

    return {
        "service_line.csv": (
            ["service_line", "description"],
            [{"service_line": code, "description": description} for code, description in SERVICE_LINES],
        ),
        "care_type.csv": (
            ["care_type", "description"],
            [{"care_type": code, "description": description} for code, description in CARE_TYPES],
        ),
        "activity_group.csv": (
            ["activity_group_code", "activity_group_name", "default_service_line", "default_care_type", "official_classification_flag"],
            activity_rows,
        ),
        "cost_centre.csv": (
            ["cost_centre_id", "cost_centre_name", "service_line", "cost_pool_code", "active_flag", "effective_from", "effective_to"],
            cost_centre_rows,
        ),
        "account_mapping.csv": (
            ["natural_account", "account_description", "cost_category", "costing_treatment", "default_driver", "active_flag"],
            account_rows,
        ),
        "allocation_rule.csv": (
            ["allocation_rule_id", "cost_pool_code", "cost_category", "allocation_driver", "eligible_scope", "business_rationale", "effective_from", "effective_to", "active_flag"],
            allocation_rows,
        ),
        "reporting_period.csv": (
            ["reporting_month", "period_start", "period_end", "financial_year", "period_number"],
            reporting_rows,
        ),
    }


def expected_issues() -> list[dict]:
    return [
        {
            "scenario_id": "DQ001",
            "source_file": "patient_encounter.csv",
            "expected_issue": "Unclassified activity group",
            "expected_treatment": "Non-blocking for costing; ABF funding requires review",
        },
        {
            "scenario_id": "DQ002",
            "source_file": "resource_usage.csv",
            "expected_issue": "Negative pathology weighted units",
            "expected_treatment": "Blocking for affected driver record",
        },
        {
            "scenario_id": "DQ003",
            "source_file": "general_ledger_transaction.csv",
            "expected_issue": "Unmapped cost centre CC_UNKNOWN",
            "expected_treatment": "Retain as unallocated cost",
        },
        {
            "scenario_id": "DQ004",
            "source_file": "general_ledger_transaction.csv",
            "expected_issue": "ALLIED_SPECIAL cost pool has zero eligible driver units",
            "expected_treatment": "Retain full pool as unallocated cost",
        },
        {
            "scenario_id": "DQ005",
            "source_file": "direct_cost_detail.csv",
            "expected_issue": "Direct cost encounter ENC_NOT_FOUND does not exist",
            "expected_treatment": "Failed direct assignment; retain as unallocated cost",
        },
    ]


def write_controls(
    output_dir: Path,
    datasets: dict[str, tuple[str, list[dict]]],
    gl_rows: list[dict],
) -> None:
    row_controls = [
        {
            "data_area": data_area,
            "file_name": name,
            "expected_row_count": len(rows),
        }
        for name, (data_area, rows) in sorted(datasets.items())
    ]
    write_csv(
        output_dir / "control_row_count.csv",
        ["data_area", "file_name", "expected_row_count"],
        row_controls,
    )

    monthly: dict[str, Decimal] = defaultdict(Decimal)
    centre: dict[tuple[str, str], Decimal] = defaultdict(Decimal)
    total = Decimal("0")
    for row in gl_rows:
        amount = Decimal(row["signed_amount"])
        total += amount
        monthly[row["reporting_month"]] += amount
        centre[(row["reporting_month"], row["cost_centre_id"])] += amount

    write_csv(
        output_dir / "control_gl_monthly.csv",
        ["reporting_month", "expected_signed_gl_total"],
        [{"reporting_month": key, "expected_signed_gl_total": money(value)} for key, value in sorted(monthly.items())],
    )
    write_csv(
        output_dir / "control_gl_cost_centre.csv",
        ["reporting_month", "cost_centre_id", "expected_signed_gl_total"],
        [
            {"reporting_month": month, "cost_centre_id": centre_id, "expected_signed_gl_total": money(value)}
            for (month, centre_id), value in sorted(centre.items())
        ],
    )
    with (output_dir / "patient_costing_generation_manifest.json").open("w", encoding="utf-8") as handle:
        json.dump(
            {
                "generator": "generate_patient_costing_data.py",
                "seed": SEED,
                "generated_at_utc": datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
                "financial_year": "2024-25",
                "facility": FACILITY,
                "total_signed_gl_amount": money(total),
                "row_counts": {
                    f"{data_area}/{name}": len(rows)
                    for name, (data_area, rows) in sorted(datasets.items())
                },
                "synthetic_data_notice": "All records are synthetic and must not be treated as real hospital data.",
            },
            handle,
            indent=2,
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--data-root",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "data",
    )
    args = parser.parse_args()
    data_root: Path = args.data_root
    raw_dir = data_root / "raw"
    reference_dir = data_root / "reference"
    controls_dir = data_root / "controls"
    for directory in (raw_dir, reference_dir, controls_dir):
        directory.mkdir(parents=True, exist_ok=True)

    rng = random.Random(SEED)
    encounters = generate_encounters(rng)
    resources = generate_resource_usage(encounters, rng)
    direct_costs = generate_direct_costs(encounters, rng)
    gl_rows = generate_gl(direct_costs, rng)

    raw_datasets: dict[str, tuple[list[str], list[dict]]] = {
        "patient_encounter.csv": (
            [
                "encounter_id", "patient_id", "facility", "service_line", "care_type",
                "admission_date", "discharge_date", "episode_month", "activity_group_code",
                "length_of_stay", "separation_status", "age_years", "indigenous_status",
                "remoteness_area", "high_complexity_flag", "hospital_acquired_complication_flag",
            ],
            encounters,
        ),
        "resource_usage.csv": (
            [
                "resource_usage_id", "encounter_id", "service_month", "bed_days",
                "theatre_minutes", "imaging_weighted_units", "pathology_weighted_units",
                "pharmacy_units", "medical_service_units", "allied_health_units",
            ],
            resources,
        ),
        "direct_cost_detail.csv": (
            [
                "direct_cost_id", "encounter_id", "service_month", "cost_centre_id",
                "natural_account", "direct_cost_type", "quantity", "amount",
            ],
            direct_costs,
        ),
        "general_ledger_transaction.csv": (
            [
                "gl_transaction_id", "reporting_month", "entity", "facility",
                "cost_centre_id", "natural_account", "account_description",
                "signed_amount", "adjustment_type", "source_reference",
            ],
            gl_rows,
        ),
    }
    reference_datasets = reference_rows()

    for file_name, (fields, rows) in raw_datasets.items():
        write_csv(raw_dir / file_name, fields, rows)
    for file_name, (fields, rows) in reference_datasets.items():
        write_csv(reference_dir / file_name, fields, rows)
    write_csv(
        controls_dir / "expected_data_quality_issue.csv",
        ["scenario_id", "source_file", "expected_issue", "expected_treatment"],
        expected_issues(),
    )

    controlled_datasets = {
        **{
            name: ("raw", rows)
            for name, (_, rows) in raw_datasets.items()
        },
        **{
            name: ("reference", rows)
            for name, (_, rows) in reference_datasets.items()
        },
    }
    write_controls(controls_dir, controlled_datasets, gl_rows)
    print(f"Generated raw data in {raw_dir}")
    print(f"Generated reference data in {reference_dir}")
    print(f"Generated controls in {controls_dir}")
    print(f"Encounters: {len(encounters):,}")
    print(f"Resource rows: {len(resources):,}")
    print(f"GL transactions: {len(gl_rows):,}")


if __name__ == "__main__":
    main()

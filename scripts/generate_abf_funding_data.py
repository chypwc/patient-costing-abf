#!/usr/bin/env python3
"""Generate a synthetic ABF funding layer from the shared encounter population.

The model follows the broad classification -> weighted activity -> price
structure used in Australian public hospital ABF, but all groups, weights,
adjustments and prices in this script are synthetic and non-official.
"""

from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from datetime import UTC, datetime
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path


SYNTHETIC_BASE_PRICE = Decimal("10750.00")

GROUPS = {
    "AG01": ("Complex Medical", "Admitted acute", Decimal("1.8500"), 12, Decimal("0.0550")),
    "AG02": ("General Medical", "Admitted acute", Decimal("0.9000"), 7, Decimal("0.0400")),
    "AG03": ("Major Surgical", "Admitted acute", Decimal("3.2000"), 14, Decimal("0.0700")),
    "AG04": ("Minor Surgical or Same-day", "Admitted acute", Decimal("0.7500"), 1, Decimal("0.0300")),
    "AG05": ("Maternity", "Admitted acute", Decimal("1.1500"), 6, Decimal("0.0450")),
    "AG06": ("Paediatric", "Admitted acute", Decimal("1.0500"), 8, Decimal("0.0450")),
    "AG07": ("Mental Health", "Mental health", Decimal("1.4000"), 21, Decimal("0.0350")),
    "AG08": ("Emergency", "Emergency", Decimal("0.3500"), 0, Decimal("0.0000")),
    "AG09": ("Outpatient", "Non-admitted", Decimal("0.1800"), 0, Decimal("0.0000")),
}


def decimal_text(value: Decimal, places: str = "0.000000") -> str:
    return str(value.quantize(Decimal(places), rounding=ROUND_HALF_UP))


def money(value: Decimal) -> str:
    return decimal_text(value, "0.01")


def read_csv(path: Path) -> list[dict]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def write_csv(path: Path, fieldnames: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def group_reference_rows() -> list[dict]:
    return [
        {
            "activity_group_code": code,
            "activity_group_name": values[0],
            "service_stream": values[1],
            "synthetic_base_weight": decimal_text(values[2], "0.0000"),
            "high_length_of_stay_trim_days": values[3],
            "synthetic_outlier_nwau_per_day": decimal_text(values[4], "0.0000"),
            "official_price_weight_flag": "N",
        }
        for code, values in GROUPS.items()
    ]


def adjustment_rows() -> list[dict]:
    return [
        {
            "adjustment_code": "INDIGENOUS",
            "description": "Synthetic demonstration adjustment for Indigenous status",
            "factor": "1.0400",
            "application": "Multiplicative",
            "official_adjustment_flag": "N",
        },
        {
            "adjustment_code": "REMOTE",
            "description": "Synthetic demonstration adjustment for remote residence",
            "factor": "1.0600",
            "application": "Multiplicative",
            "official_adjustment_flag": "N",
        },
        {
            "adjustment_code": "PAEDIATRIC",
            "description": "Synthetic demonstration adjustment for admitted patients under 18",
            "factor": "1.0500",
            "application": "Multiplicative",
            "official_adjustment_flag": "N",
        },
        {
            "adjustment_code": "SAME_DAY",
            "description": "Synthetic same-day adjustment for AG04",
            "factor": "0.9200",
            "application": "Multiplicative",
            "official_adjustment_flag": "N",
        },
        {
            "adjustment_code": "LONG_STAY",
            "description": "Synthetic additional weighted activity above the group high trim point",
            "factor": "Varies by group",
            "application": "Additive NWAU",
            "official_adjustment_flag": "N",
        },
    ]


def calculate_funding(encounter: dict) -> dict:
    code = encounter["activity_group_code"]
    if code not in GROUPS:
        return {
            "encounter_id": encounter["encounter_id"],
            "episode_month": encounter["episode_month"],
            "activity_group_code": code,
            "service_stream": "",
            "base_weight": "",
            "demographic_adjustment_factor": "",
            "long_stay_outlier_nwau": "",
            "final_synthetic_nwau": "",
            "synthetic_base_price": money(SYNTHETIC_BASE_PRICE),
            "estimated_synthetic_funding": "",
            "funding_status": "UNFUNDED_REVIEW",
            "funding_note": "Activity group is unclassified or unsupported",
        }

    _, stream, base_weight, high_trim, outlier_rate = GROUPS[code]
    factor = Decimal("1.0000")
    notes: list[str] = []
    if encounter["indigenous_status"] == "Y":
        factor *= Decimal("1.0400")
        notes.append("Synthetic Indigenous adjustment")
    if encounter["remoteness_area"] == "Remote":
        factor *= Decimal("1.0600")
        notes.append("Synthetic remote adjustment")
    if int(encounter["age_years"]) < 18 and stream == "Admitted acute":
        factor *= Decimal("1.0500")
        notes.append("Synthetic paediatric adjustment")
    if encounter["care_type"] == "Same-day" and code == "AG04":
        factor *= Decimal("0.9200")
        notes.append("Synthetic same-day adjustment")

    length_of_stay = int(encounter["length_of_stay"])
    outlier_days = max(0, length_of_stay - high_trim)
    outlier_nwau = Decimal(outlier_days) * outlier_rate
    final_nwau = base_weight * factor + outlier_nwau
    funding = final_nwau * SYNTHETIC_BASE_PRICE

    if outlier_days:
        notes.append(f"Synthetic long-stay outlier: {outlier_days} days")

    return {
        "encounter_id": encounter["encounter_id"],
        "episode_month": encounter["episode_month"],
        "activity_group_code": code,
        "service_stream": stream,
        "base_weight": decimal_text(base_weight),
        "demographic_adjustment_factor": decimal_text(factor),
        "long_stay_outlier_nwau": decimal_text(outlier_nwau),
        "final_synthetic_nwau": decimal_text(final_nwau),
        "synthetic_base_price": money(SYNTHETIC_BASE_PRICE),
        "estimated_synthetic_funding": money(funding),
        "funding_status": "CALCULATED",
        "funding_note": "; ".join(notes) if notes else "Base synthetic weight only",
    }


def main() -> None:
    repo_root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--data-root",
        type=Path,
        default=repo_root / "data",
    )
    args = parser.parse_args()

    raw_dir = args.data_root / "raw"
    reference_dir = args.data_root / "reference"
    controls_dir = args.data_root / "controls"
    expected_dir = args.data_root / "expected_outputs"
    encounter_path = raw_dir / "patient_encounter.csv"
    if not encounter_path.exists():
        raise SystemExit(
            f"Missing {encounter_path}. Run generate_patient_costing_data.py first."
        )

    encounters = read_csv(encounter_path)
    encounter_ids = [row["encounter_id"] for row in encounters]
    if len(encounter_ids) != len(set(encounter_ids)):
        raise SystemExit("Encounter IDs are not unique; ABF generation stopped.")

    funding_rows = [calculate_funding(row) for row in encounters]
    for directory in (reference_dir, controls_dir, expected_dir):
        directory.mkdir(parents=True, exist_ok=True)

    write_csv(
        reference_dir / "abf_activity_group.csv",
        [
            "activity_group_code", "activity_group_name", "service_stream",
            "synthetic_base_weight", "high_length_of_stay_trim_days",
            "synthetic_outlier_nwau_per_day", "official_price_weight_flag",
        ],
        group_reference_rows(),
    )
    write_csv(
        reference_dir / "abf_adjustment_rule.csv",
        ["adjustment_code", "description", "factor", "application", "official_adjustment_flag"],
        adjustment_rows(),
    )
    write_csv(
        expected_dir / "abf_encounter_funding.csv",
        [
            "encounter_id", "episode_month", "activity_group_code", "service_stream",
            "base_weight", "demographic_adjustment_factor", "long_stay_outlier_nwau",
            "final_synthetic_nwau", "synthetic_base_price",
            "estimated_synthetic_funding", "funding_status", "funding_note",
        ],
        funding_rows,
    )

    monthly: dict[str, dict[str, Decimal | int]] = defaultdict(
        lambda: {"encounters": 0, "funded": 0, "nwau": Decimal("0"), "funding": Decimal("0")}
    )
    for row in funding_rows:
        bucket = monthly[row["episode_month"]]
        bucket["encounters"] += 1
        if row["funding_status"] == "CALCULATED":
            bucket["funded"] += 1
            bucket["nwau"] += Decimal(row["final_synthetic_nwau"])
            bucket["funding"] += Decimal(row["estimated_synthetic_funding"])

    monthly_rows = [
        {
            "episode_month": month,
            "encounter_count": values["encounters"],
            "funded_encounter_count": values["funded"],
            "unfunded_review_count": values["encounters"] - values["funded"],
            "total_synthetic_nwau": decimal_text(values["nwau"]),
            "total_estimated_synthetic_funding": money(values["funding"]),
        }
        for month, values in sorted(monthly.items())
    ]
    write_csv(
        expected_dir / "abf_monthly_control_total.csv",
        [
            "episode_month", "encounter_count", "funded_encounter_count",
            "unfunded_review_count", "total_synthetic_nwau",
            "total_estimated_synthetic_funding",
        ],
        monthly_rows,
    )

    row_control_path = controls_dir / "control_row_count.csv"
    existing_controls = read_csv(row_control_path) if row_control_path.exists() else []
    abf_files = {
        ("reference", "abf_activity_group.csv"): len(group_reference_rows()),
        ("reference", "abf_adjustment_rule.csv"): len(adjustment_rows()),
        ("expected_outputs", "abf_encounter_funding.csv"): len(funding_rows),
        ("expected_outputs", "abf_monthly_control_total.csv"): len(monthly_rows),
    }
    retained_controls = [
        row
        for row in existing_controls
        if (row["data_area"], row["file_name"]) not in abf_files
    ]
    retained_controls.extend(
        {
            "data_area": data_area,
            "file_name": file_name,
            "expected_row_count": row_count,
        }
        for (data_area, file_name), row_count in abf_files.items()
    )
    write_csv(
        row_control_path,
        ["data_area", "file_name", "expected_row_count"],
        sorted(retained_controls, key=lambda row: (row["data_area"], row["file_name"])),
    )

    total_funding = sum(
        (Decimal(row["estimated_synthetic_funding"]) for row in funding_rows if row["funding_status"] == "CALCULATED"),
        Decimal("0"),
    )
    total_nwau = sum(
        (Decimal(row["final_synthetic_nwau"]) for row in funding_rows if row["funding_status"] == "CALCULATED"),
        Decimal("0"),
    )
    with (controls_dir / "abf_generation_manifest.json").open("w", encoding="utf-8") as handle:
        json.dump(
            {
                "generator": "generate_abf_funding_data.py",
                "generated_at_utc": datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z"),
                "source_encounter_file": str(encounter_path),
                "source_encounter_count": len(encounters),
                "funded_encounter_count": sum(row["funding_status"] == "CALCULATED" for row in funding_rows),
                "unfunded_review_count": sum(row["funding_status"] != "CALCULATED" for row in funding_rows),
                "synthetic_base_price": money(SYNTHETIC_BASE_PRICE),
                "total_synthetic_nwau": decimal_text(total_nwau),
                "total_estimated_synthetic_funding": money(total_funding),
                "model_notice": "Synthetic educational ABF model. It is not an official IHACPA NWAU calculation or funding determination.",
            },
            handle,
            indent=2,
        )

    print(f"Generated ABF reference data in {reference_dir}")
    print(f"Generated ABF expected outputs in {expected_dir}")
    print(f"Generated ABF controls in {controls_dir}")
    print(f"Source encounters: {len(encounters):,}")
    print(f"Funded encounters: {sum(row['funding_status'] == 'CALCULATED' for row in funding_rows):,}")
    print(f"Unfunded review: {sum(row['funding_status'] != 'CALCULATED' for row in funding_rows):,}")


if __name__ == "__main__":
    main()

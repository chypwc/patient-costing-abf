#!/usr/bin/env python3
"""Validate generated patient-costing and synthetic ABF CSV data.

The validator is read-only. It checks:

- required files and columns;
- uniqueness and referential integrity;
- clinical and resource-use plausibility;
- GL mappings, signs, totals and direct-cost controls;
- expected deliberate exception scenarios;
- ABF population, calculations and monthly control totals;
- high-level statistical reasonableness.

Unexpected ERROR results cause a non-zero exit code. Expected synthetic test
exceptions are reported as EXPECTED and do not fail the validation run.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import statistics
import sys
from collections import Counter, defaultdict
from dataclasses import asdict, dataclass
from datetime import UTC, date, datetime
from decimal import Decimal
from pathlib import Path
from typing import Iterable


EXPECTED_SERVICE_LINES = {
    "Medical",
    "Surgical",
    "Women's and Children's",
    "Mental Health",
    "Emergency",
    "Outpatients",
}
EXPECTED_CARE_TYPES = {"Inpatient", "Same-day", "Emergency", "Outpatient"}
EXPECTED_MONTHS = {
    "2024-07-01",
    "2024-08-01",
    "2024-09-01",
    "2024-10-01",
    "2024-11-01",
    "2024-12-01",
    "2025-01-01",
    "2025-02-01",
    "2025-03-01",
    "2025-04-01",
    "2025-05-01",
    "2025-06-01",
}

RAW_SCHEMAS = {
    "patient_encounter.csv": {
        "encounter_id",
        "patient_id",
        "facility",
        "service_line",
        "care_type",
        "admission_date",
        "discharge_date",
        "episode_month",
        "activity_group_code",
        "length_of_stay",
        "separation_status",
        "age_years",
        "indigenous_status",
        "remoteness_area",
        "high_complexity_flag",
        "hospital_acquired_complication_flag",
    },
    "resource_usage.csv": {
        "resource_usage_id",
        "encounter_id",
        "service_month",
        "bed_days",
        "theatre_minutes",
        "imaging_weighted_units",
        "pathology_weighted_units",
        "pharmacy_units",
        "medical_service_units",
        "allied_health_units",
    },
    "direct_cost_detail.csv": {
        "direct_cost_id",
        "encounter_id",
        "service_month",
        "cost_centre_id",
        "natural_account",
        "direct_cost_type",
        "quantity",
        "amount",
    },
    "general_ledger_transaction.csv": {
        "gl_transaction_id",
        "reporting_month",
        "entity",
        "facility",
        "cost_centre_id",
        "natural_account",
        "account_description",
        "signed_amount",
        "adjustment_type",
        "source_reference",
    },
}

REFERENCE_SCHEMAS = {
    "cost_centre.csv": {
        "cost_centre_id",
        "cost_centre_name",
        "service_line",
        "cost_pool_code",
        "active_flag",
        "effective_from",
        "effective_to",
    },
    "account_mapping.csv": {
        "natural_account",
        "account_description",
        "cost_category",
        "costing_treatment",
        "default_driver",
        "active_flag",
    },
    "service_line.csv": {"service_line", "description"},
    "care_type.csv": {"care_type", "description"},
    "activity_group.csv": {
        "activity_group_code",
        "activity_group_name",
        "default_service_line",
        "default_care_type",
        "official_classification_flag",
    },
    "allocation_rule.csv": {
        "allocation_rule_id",
        "cost_pool_code",
        "cost_category",
        "allocation_driver",
        "eligible_scope",
        "business_rationale",
        "effective_from",
        "effective_to",
        "active_flag",
    },
    "reporting_period.csv": {
        "reporting_month",
        "period_start",
        "period_end",
        "financial_year",
        "period_number",
    },
    "abf_activity_group.csv": {
        "activity_group_code",
        "activity_group_name",
        "service_stream",
        "synthetic_base_weight",
        "high_length_of_stay_trim_days",
        "synthetic_outlier_nwau_per_day",
        "official_price_weight_flag",
    },
    "abf_adjustment_rule.csv": {
        "adjustment_code",
        "description",
        "factor",
        "application",
        "official_adjustment_flag",
    },
}

CONTROL_SCHEMAS = {
    "control_row_count.csv": {"data_area", "file_name", "expected_row_count"},
    "control_gl_monthly.csv": {"reporting_month", "expected_signed_gl_total"},
    "control_gl_cost_centre.csv": {
        "reporting_month",
        "cost_centre_id",
        "expected_signed_gl_total",
    },
    "expected_data_quality_issue.csv": {
        "scenario_id",
        "source_file",
        "expected_issue",
        "expected_treatment",
    },
}

EXPECTED_OUTPUT_SCHEMAS = {
    "abf_encounter_funding.csv": {
        "encounter_id",
        "episode_month",
        "activity_group_code",
        "service_stream",
        "base_weight",
        "demographic_adjustment_factor",
        "long_stay_outlier_nwau",
        "final_synthetic_nwau",
        "synthetic_base_price",
        "estimated_synthetic_funding",
        "funding_status",
        "funding_note",
    },
    "abf_monthly_control_total.csv": {
        "episode_month",
        "encounter_count",
        "funded_encounter_count",
        "unfunded_review_count",
        "total_synthetic_nwau",
        "total_estimated_synthetic_funding",
    },
}


@dataclass
class CheckResult:
    check_id: str
    area: str
    status: str
    message: str
    observed: str = ""
    expected: str = ""


class ValidationReport:
    def __init__(self) -> None:
        self.results: list[CheckResult] = []
        self.statistics: dict[str, object] = {}

    def add(
        self,
        check_id: str,
        area: str,
        status: str,
        message: str,
        observed: object = "",
        expected: object = "",
    ) -> None:
        self.results.append(
            CheckResult(
                check_id,
                area,
                status,
                message,
                str(observed),
                str(expected),
            )
        )

    def pass_check(self, check_id: str, area: str, message: str, observed: object = "") -> None:
        self.add(check_id, area, "PASS", message, observed)

    def error(
        self,
        check_id: str,
        area: str,
        message: str,
        observed: object = "",
        expected: object = "",
    ) -> None:
        self.add(check_id, area, "ERROR", message, observed, expected)

    def warn(
        self,
        check_id: str,
        area: str,
        message: str,
        observed: object = "",
        expected: object = "",
    ) -> None:
        self.add(check_id, area, "WARNING", message, observed, expected)

    def expected(self, check_id: str, area: str, message: str, observed: object = "") -> None:
        self.add(check_id, area, "EXPECTED", message, observed)

    @property
    def counts(self) -> Counter:
        return Counter(result.status for result in self.results)

    @property
    def has_errors(self) -> bool:
        return any(result.status == "ERROR" for result in self.results)


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def decimal_sum(rows: Iterable[dict[str, str]], field: str) -> Decimal:
    return sum((Decimal(row[field]) for row in rows), Decimal("0"))


def percentile(values: list[float], probability: float) -> float:
    if not values:
        return math.nan
    ordered = sorted(values)
    position = (len(ordered) - 1) * probability
    lower = math.floor(position)
    upper = math.ceil(position)
    if lower == upper:
        return ordered[lower]
    return ordered[lower] + (ordered[upper] - ordered[lower]) * (position - lower)


def numeric_summary(values: list[float]) -> dict[str, float | int]:
    if not values:
        return {"count": 0}
    return {
        "count": len(values),
        "min": round(min(values), 3),
        "mean": round(statistics.fmean(values), 3),
        "median": round(statistics.median(values), 3),
        "p95": round(percentile(values, 0.95), 3),
        "max": round(max(values), 3),
    }


def check_required_files(
    report: ValidationReport,
    directory: Path,
    schemas: dict[str, set[str]],
    area: str,
) -> dict[str, list[dict[str, str]]]:
    datasets: dict[str, list[dict[str, str]]] = {}
    for file_name, required_columns in schemas.items():
        path = directory / file_name
        check_id = f"{area[:3].upper()}-FILE-{file_name}"
        if not path.exists():
            report.error(check_id, area, "Required file is missing", path)
            continue
        with path.open(newline="", encoding="utf-8") as handle:
            reader = csv.DictReader(handle)
            actual_columns = set(reader.fieldnames or [])
            rows = list(reader)
        missing_columns = sorted(required_columns - actual_columns)
        if missing_columns:
            report.error(
                check_id,
                area,
                "Required columns are missing",
                ", ".join(missing_columns),
            )
            continue
        datasets[file_name] = rows
        report.pass_check(check_id, area, "File and required columns are present", len(rows))
    return datasets


def check_row_controls(
    report: ValidationReport,
    data_root: Path,
    control_data: dict[str, list[dict[str, str]]],
) -> None:
    controls = control_data.get("control_row_count.csv", [])
    mismatches = []
    for control in controls:
        file_name = control["file_name"]
        path = data_root / control["data_area"] / file_name
        actual = len(read_csv(path)) if path.exists() else -1
        expected = int(control["expected_row_count"])
        if actual != expected:
            mismatches.append(f"{file_name}: {actual} vs {expected}")
    if mismatches:
        report.error(
            "SRC-ROW-CONTROL",
            "Source controls",
            "One or more file row counts do not match controls",
            "; ".join(mismatches),
        )
    else:
        report.pass_check(
            "SRC-ROW-CONTROL",
            "Source controls",
            "All controlled source row counts agree",
            len(controls),
        )


def check_encounters(
    report: ValidationReport,
    encounters: list[dict[str, str]],
    resources: list[dict[str, str]],
) -> dict[str, dict[str, str]]:
    encounter_ids = [row["encounter_id"] for row in encounters]
    duplicate_count = len(encounter_ids) - len(set(encounter_ids))
    if duplicate_count:
        report.error("ENC-UNIQUE", "Encounters", "Encounter IDs are not unique", duplicate_count)
    else:
        report.pass_check("ENC-UNIQUE", "Encounters", "Encounter IDs are unique", len(encounters))

    encounter_map = {row["encounter_id"]: row for row in encounters}
    service_lines = {row["service_line"] for row in encounters}
    care_types = {row["care_type"] for row in encounters}
    months = {row["episode_month"] for row in encounters}
    if service_lines == EXPECTED_SERVICE_LINES:
        report.pass_check("ENC-SERVICES", "Encounters", "All expected service lines are represented")
    else:
        report.error("ENC-SERVICES", "Encounters", "Service-line coverage differs", service_lines, EXPECTED_SERVICE_LINES)
    if care_types == EXPECTED_CARE_TYPES:
        report.pass_check("ENC-CARE", "Encounters", "All expected care types are represented")
    else:
        report.error("ENC-CARE", "Encounters", "Care-type coverage differs", care_types, EXPECTED_CARE_TYPES)
    if months == EXPECTED_MONTHS:
        report.pass_check("ENC-MONTHS", "Encounters", "All 12 reporting months are represented")
    else:
        report.error("ENC-MONTHS", "Encounters", "Reporting-month coverage differs", months, EXPECTED_MONTHS)

    bad_dates = []
    bad_age = []
    bad_care_los = []
    for row in encounters:
        admission = date.fromisoformat(row["admission_date"])
        discharge = date.fromisoformat(row["discharge_date"])
        los = int(row["length_of_stay"])
        age = int(row["age_years"])
        if discharge < admission or los < 0:
            bad_dates.append(row["encounter_id"])
        if not 0 <= age <= 110:
            bad_age.append(row["encounter_id"])
        if row["care_type"] in {"Same-day", "Emergency", "Outpatient"} and los != 0:
            bad_care_los.append(row["encounter_id"])
        if row["care_type"] == "Inpatient" and los < 1:
            bad_care_los.append(row["encounter_id"])

    if bad_dates:
        report.error("ENC-DATES", "Encounters", "Invalid encounter date or LOS relationships", len(bad_dates))
    else:
        report.pass_check("ENC-DATES", "Encounters", "Encounter dates and LOS are internally valid")
    if bad_age:
        report.error("ENC-AGE", "Encounters", "Ages fall outside 0-110", len(bad_age))
    else:
        report.pass_check("ENC-AGE", "Encounters", "Encounter ages are within 0-110")
    if bad_care_los:
        report.error("ENC-CARE-LOS", "Encounters", "Care type and LOS are inconsistent", len(bad_care_los))
    else:
        report.pass_check("ENC-CARE-LOS", "Encounters", "Care type and LOS are consistent")

    unclassified = [row for row in encounters if row["activity_group_code"] == "UNCLASSIFIED"]
    if len(unclassified) == 1:
        report.expected(
            "ENC-UNCLASSIFIED",
            "Encounters",
            "One deliberate unclassified encounter is present",
            unclassified[0]["encounter_id"],
        )
    else:
        report.error(
            "ENC-UNCLASSIFIED",
            "Encounters",
            "Expected exactly one unclassified encounter",
            len(unclassified),
            1,
        )

    resource_months = defaultdict(set)
    for row in resources:
        resource_months[row["encounter_id"]].add(row["service_month"])
    multi_month = [enc_id for enc_id, values in resource_months.items() if len(values) > 1]
    if multi_month:
        report.pass_check(
            "ENC-MULTI-MONTH",
            "Encounters",
            "Multi-month encounter resource records are present",
            len(multi_month),
        )
    else:
        report.error("ENC-MULTI-MONTH", "Encounters", "No multi-month resource example was generated")

    report.statistics["encounter_count"] = len(encounters)
    report.statistics["encounters_by_month"] = dict(sorted(Counter(row["episode_month"] for row in encounters).items()))
    report.statistics["encounters_by_service_line"] = dict(sorted(Counter(row["service_line"] for row in encounters).items()))
    report.statistics["encounters_by_care_type"] = dict(sorted(Counter(row["care_type"] for row in encounters).items()))
    report.statistics["encounters_by_activity_group"] = dict(sorted(Counter(row["activity_group_code"] for row in encounters).items()))
    report.statistics["age_summary"] = numeric_summary([float(row["age_years"]) for row in encounters])
    report.statistics["los_summary_inpatient"] = numeric_summary(
        [float(row["length_of_stay"]) for row in encounters if row["care_type"] == "Inpatient"]
    )

    return encounter_map


def check_resources(
    report: ValidationReport,
    resources: list[dict[str, str]],
    encounter_map: dict[str, dict[str, str]],
) -> None:
    resource_ids = [row["resource_usage_id"] for row in resources]
    if len(resource_ids) != len(set(resource_ids)):
        report.error("RES-UNIQUE", "Resources", "Resource usage IDs are not unique")
    else:
        report.pass_check("RES-UNIQUE", "Resources", "Resource usage IDs are unique", len(resources))

    orphan_rows = [row for row in resources if row["encounter_id"] not in encounter_map]
    if orphan_rows:
        report.error("RES-FK", "Resources", "Resource rows contain unknown encounters", len(orphan_rows))
    else:
        report.pass_check("RES-FK", "Resources", "All resource rows reference valid encounters")

    measure_fields = [
        "bed_days",
        "theatre_minutes",
        "imaging_weighted_units",
        "pathology_weighted_units",
        "pharmacy_units",
        "medical_service_units",
        "allied_health_units",
    ]
    negatives = {
        field: [row for row in resources if int(row[field]) < 0]
        for field in measure_fields
    }
    expected_negative_pathology = len(negatives["pathology_weighted_units"])
    unexpected_negatives = sum(
        len(rows)
        for field, rows in negatives.items()
        if field != "pathology_weighted_units"
    )
    if expected_negative_pathology == 1:
        report.expected(
            "RES-NEG-PATH",
            "Resources",
            "One deliberate negative pathology driver is present",
            expected_negative_pathology,
        )
    else:
        report.error(
            "RES-NEG-PATH",
            "Resources",
            "Expected exactly one negative pathology driver",
            expected_negative_pathology,
            1,
        )
    if unexpected_negatives:
        report.error(
            "RES-NEG-OTHER",
            "Resources",
            "Unexpected negative resource measures are present",
            unexpected_negatives,
            0,
        )
    else:
        report.pass_check("RES-NEG-OTHER", "Resources", "No unexpected negative resource measures")

    admitted_bed_days = sum(
        int(row["bed_days"])
        for row in resources
        if encounter_map[row["encounter_id"]]["care_type"] in {"Inpatient", "Same-day"}
    )
    non_admitted_bed_days = sum(
        int(row["bed_days"])
        for row in resources
        if encounter_map[row["encounter_id"]]["care_type"] in {"Emergency", "Outpatient"}
    )
    if admitted_bed_days > 0 and non_admitted_bed_days == 0:
        report.pass_check(
            "RES-BED-DAY",
            "Resources",
            "Bed days are confined to admitted activity",
            admitted_bed_days,
        )
    else:
        report.error(
            "RES-BED-DAY",
            "Resources",
            "Bed-day distribution is implausible",
            f"admitted={admitted_bed_days}, non-admitted={non_admitted_bed_days}",
        )

    procedural_theatre = sum(
        int(row["theatre_minutes"])
        for row in resources
        if encounter_map[row["encounter_id"]]["service_line"]
        in {"Surgical", "Women's and Children's"}
    )
    all_theatre = sum(int(row["theatre_minutes"]) for row in resources)
    theatre_share = Decimal(procedural_theatre) / Decimal(all_theatre) if all_theatre else Decimal("0")
    if theatre_share >= Decimal("0.95"):
        report.pass_check(
            "RES-THEATRE",
            "Resources",
            "Theatre minutes are concentrated in procedural services",
            f"{theatre_share:.1%}",
        )
    else:
        report.warn(
            "RES-THEATRE",
            "Resources",
            "Theatre minutes are less concentrated in procedural services than expected",
            f"{theatre_share:.1%}",
            ">=95%",
        )

    report.statistics["resource_row_count"] = len(resources)
    report.statistics["resource_summaries"] = {
        field: numeric_summary([float(row[field]) for row in resources if int(row[field]) >= 0])
        for field in measure_fields
    }


def check_financials(
    report: ValidationReport,
    source_data: dict[str, list[dict[str, str]]],
    encounter_map: dict[str, dict[str, str]],
) -> None:
    gl_rows = source_data["general_ledger_transaction.csv"]
    direct_rows = source_data["direct_cost_detail.csv"]
    cost_centres = {row["cost_centre_id"] for row in source_data["cost_centre.csv"]}
    accounts = {row["natural_account"] for row in source_data["account_mapping.csv"]}

    gl_ids = [row["gl_transaction_id"] for row in gl_rows]
    if len(gl_ids) != len(set(gl_ids)):
        report.error("GL-UNIQUE", "Financial", "GL transaction IDs are not unique")
    else:
        report.pass_check("GL-UNIQUE", "Financial", "GL transaction IDs are unique", len(gl_rows))

    unknown_centres = [row for row in gl_rows if row["cost_centre_id"] not in cost_centres]
    if len(unknown_centres) == 1 and unknown_centres[0]["cost_centre_id"] == "CC_UNKNOWN":
        report.expected(
            "GL-UNKNOWN-CC",
            "Financial",
            "One deliberate unmapped cost centre is present",
            unknown_centres[0]["signed_amount"],
        )
    else:
        report.error(
            "GL-UNKNOWN-CC",
            "Financial",
            "Unexpected unmapped cost-centre population",
            len(unknown_centres),
            1,
        )

    unknown_accounts = [row for row in gl_rows if row["natural_account"] not in accounts]
    if unknown_accounts:
        report.error("GL-UNKNOWN-ACCOUNT", "Financial", "Unmapped natural accounts are present", len(unknown_accounts))
    else:
        report.pass_check("GL-UNKNOWN-ACCOUNT", "Financial", "All GL natural accounts are mapped")

    negative_rows = [row for row in gl_rows if Decimal(row["signed_amount"]) < 0]
    negative_types = {row["adjustment_type"] for row in negative_rows}
    if negative_rows and negative_types <= {"Credit", "Reversal"}:
        report.pass_check(
            "GL-NEGATIVE",
            "Financial",
            "Negative GL amounts are classified as credits or reversals",
            len(negative_rows),
        )
    else:
        report.error(
            "GL-NEGATIVE",
            "Financial",
            "Negative GL amounts have unexpected classifications",
            negative_types,
        )

    monthly_expected = {
        row["reporting_month"]: Decimal(row["expected_signed_gl_total"])
        for row in source_data["control_gl_monthly.csv"]
    }
    monthly_actual: dict[str, Decimal] = defaultdict(Decimal)
    for row in gl_rows:
        monthly_actual[row["reporting_month"]] += Decimal(row["signed_amount"])
    mismatches = {
        month: (monthly_actual[month], expected)
        for month, expected in monthly_expected.items()
        if monthly_actual[month] != expected
    }
    if mismatches:
        report.error("GL-MONTH-CONTROL", "Financial", "Monthly GL totals do not match controls", mismatches)
    else:
        report.pass_check("GL-MONTH-CONTROL", "Financial", "Monthly GL totals match controls", len(monthly_expected))

    centre_expected = {
        (row["reporting_month"], row["cost_centre_id"]): Decimal(row["expected_signed_gl_total"])
        for row in source_data["control_gl_cost_centre.csv"]
    }
    centre_actual: dict[tuple[str, str], Decimal] = defaultdict(Decimal)
    for row in gl_rows:
        centre_actual[(row["reporting_month"], row["cost_centre_id"])] += Decimal(row["signed_amount"])
    centre_mismatches = {
        key: (centre_actual[key], expected)
        for key, expected in centre_expected.items()
        if centre_actual[key] != expected
    }
    if centre_mismatches:
        report.error("GL-CC-CONTROL", "Financial", "Cost-centre GL totals do not match controls", len(centre_mismatches))
    else:
        report.pass_check("GL-CC-CONTROL", "Financial", "Cost-centre GL totals match controls", len(centre_expected))

    direct_expected: dict[tuple[str, str, str], Decimal] = defaultdict(Decimal)
    for row in direct_rows:
        direct_expected[
            (row["service_month"], row["cost_centre_id"], row["natural_account"])
        ] += Decimal(row["amount"])
    direct_gl = {
        (row["reporting_month"], row["cost_centre_id"], row["natural_account"]): Decimal(row["signed_amount"])
        for row in gl_rows
        if row["source_reference"].startswith("DIRECT-CONTROL-")
    }
    direct_mismatches = {
        key: (direct_gl.get(key), value)
        for key, value in direct_expected.items()
        if direct_gl.get(key) != value
    }
    if direct_mismatches:
        report.error("GL-DIRECT-CONTROL", "Financial", "Direct-cost detail does not agree with GL controls", len(direct_mismatches))
    else:
        report.pass_check("GL-DIRECT-CONTROL", "Financial", "Direct-cost detail agrees with GL controls")

    failed_direct = [
        row for row in direct_rows if row["encounter_id"] not in encounter_map
    ]
    if len(failed_direct) == 1 and failed_direct[0]["encounter_id"] == "ENC_NOT_FOUND":
        report.expected(
            "DIR-FAILED",
            "Financial",
            "One deliberate failed direct assignment is present",
            failed_direct[0]["amount"],
        )
    else:
        report.error("DIR-FAILED", "Financial", "Unexpected failed direct-assignment population", len(failed_direct), 1)

    zero_driver_pool = [
        row for row in gl_rows if row["cost_centre_id"] == "CC_ALLIED_UNUSED"
    ]
    zero_driver_amount = decimal_sum(zero_driver_pool, "signed_amount")
    if zero_driver_amount == Decimal("45000.00"):
        report.expected(
            "GL-ZERO-DRIVER",
            "Financial",
            "Deliberate zero-driver cost pool is present",
            zero_driver_amount,
        )
    else:
        report.error(
            "GL-ZERO-DRIVER",
            "Financial",
            "Zero-driver test pool does not have the expected amount",
            zero_driver_amount,
            "45000.00",
        )

    gl_total = decimal_sum(gl_rows, "signed_amount")
    direct_total = decimal_sum(direct_rows, "amount")
    monthly_values = [float(value) for value in monthly_actual.values()]
    report.statistics["gl_transaction_count"] = len(gl_rows)
    report.statistics["total_signed_gl"] = f"{gl_total:.2f}"
    report.statistics["total_direct_cost"] = f"{direct_total:.2f}"
    report.statistics["monthly_gl_summary"] = numeric_summary(monthly_values)
    report.statistics["gl_by_month"] = {
        month: f"{value:.2f}" for month, value in sorted(monthly_actual.items())
    }
    report.statistics["gl_adjustment_types"] = dict(sorted(Counter(row["adjustment_type"] for row in gl_rows).items()))


def check_abf(
    report: ValidationReport,
    abf_data: dict[str, list[dict[str, str]]],
    encounter_map: dict[str, dict[str, str]],
) -> None:
    funding_rows = abf_data["abf_encounter_funding.csv"]
    monthly_controls = abf_data["abf_monthly_control_total.csv"]
    group_rows = abf_data["abf_activity_group.csv"]
    group_map = {row["activity_group_code"]: row for row in group_rows}

    funding_ids = [row["encounter_id"] for row in funding_rows]
    if len(funding_ids) == len(set(funding_ids)) == len(encounter_map) and set(funding_ids) == set(encounter_map):
        report.pass_check("ABF-POPULATION", "ABF", "ABF population exactly matches the encounter population", len(funding_rows))
    else:
        report.error(
            "ABF-POPULATION",
            "ABF",
            "ABF population does not match encounters",
            f"rows={len(funding_ids)}, unique={len(set(funding_ids))}",
            len(encounter_map),
        )

    unfunded = [row for row in funding_rows if row["funding_status"] == "UNFUNDED_REVIEW"]
    if (
        len(unfunded) == 1
        and encounter_map[unfunded[0]["encounter_id"]]["activity_group_code"] == "UNCLASSIFIED"
    ):
        report.expected(
            "ABF-UNFUNDED",
            "ABF",
            "One unclassified encounter is held for funding review",
            unfunded[0]["encounter_id"],
        )
    else:
        report.error("ABF-UNFUNDED", "ABF", "Unexpected unfunded-review population", len(unfunded), 1)

    calculation_errors = []
    base_prices = set()
    for row in funding_rows:
        if row["funding_status"] != "CALCULATED":
            continue
        base_price = Decimal(row["synthetic_base_price"])
        final_nwau = Decimal(row["final_synthetic_nwau"])
        funding = Decimal(row["estimated_synthetic_funding"])
        base_prices.add(base_price)
        if abs(funding - (final_nwau * base_price).quantize(Decimal("0.01"))) > Decimal("0.01"):
            calculation_errors.append(row["encounter_id"])
        if final_nwau <= 0:
            calculation_errors.append(row["encounter_id"])
        if not Decimal("0.85") <= Decimal(row["demographic_adjustment_factor"]) <= Decimal("1.20"):
            calculation_errors.append(row["encounter_id"])
    if calculation_errors:
        report.error("ABF-CALC", "ABF", "Encounter funding calculations contain errors", len(set(calculation_errors)))
    else:
        report.pass_check("ABF-CALC", "ABF", "Encounter funding calculations are arithmetically consistent")

    if len(base_prices) == 1:
        report.pass_check("ABF-PRICE", "ABF", "One synthetic base price is applied consistently", next(iter(base_prices)))
    else:
        report.error("ABF-PRICE", "ABF", "Multiple synthetic base prices are present", base_prices)

    monthly_actual: dict[str, dict[str, Decimal | int]] = defaultdict(
        lambda: {"encounters": 0, "funded": 0, "nwau": Decimal("0"), "funding": Decimal("0")}
    )
    for row in funding_rows:
        bucket = monthly_actual[row["episode_month"]]
        bucket["encounters"] += 1
        if row["funding_status"] == "CALCULATED":
            bucket["funded"] += 1
            bucket["nwau"] += Decimal(row["final_synthetic_nwau"])
            bucket["funding"] += Decimal(row["estimated_synthetic_funding"])

    monthly_errors = []
    for control in monthly_controls:
        actual = monthly_actual[control["episode_month"]]
        if (
            actual["encounters"] != int(control["encounter_count"])
            or actual["funded"] != int(control["funded_encounter_count"])
            or actual["encounters"] - actual["funded"] != int(control["unfunded_review_count"])
            or actual["nwau"] != Decimal(control["total_synthetic_nwau"])
            or actual["funding"] != Decimal(control["total_estimated_synthetic_funding"])
        ):
            monthly_errors.append(control["episode_month"])
    if monthly_errors:
        report.error("ABF-MONTH-CONTROL", "ABF", "Monthly ABF controls do not agree", monthly_errors)
    else:
        report.pass_check("ABF-MONTH-CONTROL", "ABF", "Monthly ABF controls agree", len(monthly_controls))

    missing_groups = {
        row["activity_group_code"]
        for row in funding_rows
        if row["funding_status"] == "CALCULATED"
        and row["activity_group_code"] not in group_map
    }
    if missing_groups:
        report.error("ABF-GROUPS", "ABF", "Calculated funding uses missing group references", missing_groups)
    else:
        report.pass_check("ABF-GROUPS", "ABF", "All calculated funding rows have group references")

    total_nwau = sum(
        (Decimal(row["final_synthetic_nwau"]) for row in funding_rows if row["funding_status"] == "CALCULATED"),
        Decimal("0"),
    )
    total_funding = sum(
        (Decimal(row["estimated_synthetic_funding"]) for row in funding_rows if row["funding_status"] == "CALCULATED"),
        Decimal("0"),
    )
    report.statistics["funded_encounter_count"] = len(funding_rows) - len(unfunded)
    report.statistics["unfunded_review_count"] = len(unfunded)
    report.statistics["total_synthetic_nwau"] = f"{total_nwau:.6f}"
    report.statistics["total_synthetic_funding"] = f"{total_funding:.2f}"
    report.statistics["synthetic_nwau_summary"] = numeric_summary(
        [
            float(row["final_synthetic_nwau"])
            for row in funding_rows
            if row["funding_status"] == "CALCULATED"
        ]
    )


def check_reasonableness(report: ValidationReport) -> None:
    stats = report.statistics
    encounter_count = int(stats.get("encounter_count", 0))
    service_counts = stats.get("encounters_by_service_line", {})
    monthly_counts = stats.get("encounters_by_month", {})
    total_gl = Decimal(str(stats.get("total_signed_gl", "0")))
    funding = Decimal(str(stats.get("total_synthetic_funding", "0")))

    if 5_000 <= encounter_count <= 10_000:
        report.pass_check("PLAUS-VOLUME", "Plausibility", "Annual encounter volume is suitable for the portfolio scale", encounter_count)
    else:
        report.warn("PLAUS-VOLUME", "Plausibility", "Annual encounter volume is outside the portfolio target", encounter_count, "5,000-10,000")

    small_services = {
        name: count
        for name, count in service_counts.items()
        if count < max(100, encounter_count * 0.02)
    }
    if small_services:
        report.warn(
            "PLAUS-SERVICE-MIX",
            "Plausibility",
            "Some service lines have very small analytical populations",
            small_services,
        )
    else:
        report.pass_check("PLAUS-SERVICE-MIX", "Plausibility", "All service lines have usable analytical populations")

    if monthly_counts:
        minimum = min(monthly_counts.values())
        maximum = max(monthly_counts.values())
        ratio = Decimal(maximum) / Decimal(minimum)
        if ratio <= Decimal("1.50"):
            report.pass_check(
                "PLAUS-MONTH-VOLUME",
                "Plausibility",
                "Monthly encounter volumes vary without implausible discontinuity",
                f"{minimum}-{maximum}",
            )
        else:
            report.warn(
                "PLAUS-MONTH-VOLUME",
                "Plausibility",
                "Monthly encounter-volume spread is large",
                f"{minimum}-{maximum}",
            )

    if total_gl > 0 and funding > 0:
        funding_to_gl = funding / total_gl
        report.statistics["funding_to_gl_ratio"] = f"{funding_to_gl:.4f}"
        if Decimal("0.80") <= funding_to_gl <= Decimal("1.20"):
            report.pass_check(
                "PLAUS-COST-FUNDING",
                "Plausibility",
                "Portfolio-wide synthetic funding is reasonably calibrated to the GL cost base",
                f"{funding_to_gl:.1%}",
            )
        else:
            report.warn(
                "PLAUS-COST-FUNDING",
                "Plausibility",
                "Synthetic funding is poorly calibrated to the GL cost base",
                f"{funding_to_gl:.1%}",
                "80%-120%",
            )


def write_reports(report: ValidationReport, output_dir: Path) -> tuple[Path, Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    generated_at = datetime.now(UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    json_path = output_dir / "synthetic_data_validation_report.json"
    markdown_path = output_dir / "synthetic_data_validation_report.md"

    payload = {
        "generated_at_utc": generated_at,
        "overall_status": "FAIL" if report.has_errors else "PASS",
        "result_counts": dict(report.counts),
        "checks": [asdict(result) for result in report.results],
        "statistics": report.statistics,
    }
    json_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    status_order = {"ERROR": 0, "WARNING": 1, "EXPECTED": 2, "PASS": 3}
    lines = [
        "# Synthetic Data Validation Report",
        "",
        f"- Generated: `{generated_at}`",
        f"- Overall status: **{'FAIL' if report.has_errors else 'PASS'}**",
        f"- Checks: {len(report.results)}",
        f"- Errors: {report.counts.get('ERROR', 0)}",
        f"- Warnings: {report.counts.get('WARNING', 0)}",
        f"- Expected test exceptions: {report.counts.get('EXPECTED', 0)}",
        "",
        "## Executive Statistics",
        "",
        f"- Encounters: `{int(report.statistics.get('encounter_count', 0)):,}`",
        f"- Resource rows: `{int(report.statistics.get('resource_row_count', 0)):,}`",
        f"- GL transactions: `{int(report.statistics.get('gl_transaction_count', 0)):,}`",
        f"- Total signed GL: `${Decimal(str(report.statistics.get('total_signed_gl', '0'))):,.2f}`",
        f"- Direct costs: `${Decimal(str(report.statistics.get('total_direct_cost', '0'))):,.2f}`",
        f"- Funded encounters: `{int(report.statistics.get('funded_encounter_count', 0)):,}`",
        f"- Unfunded review encounters: `{int(report.statistics.get('unfunded_review_count', 0)):,}`",
        f"- Total synthetic NWAU: `{report.statistics.get('total_synthetic_nwau', '0')}`",
        f"- Total synthetic funding: `${Decimal(str(report.statistics.get('total_synthetic_funding', '0'))):,.2f}`",
        f"- Funding-to-GL ratio: `{Decimal(str(report.statistics.get('funding_to_gl_ratio', '0'))):.1%}`",
        "",
        "## Encounter Distribution",
        "",
        "### By service line",
        "",
        "| Service line | Encounters | Share |",
        "|---|---:|---:|",
    ]
    total_encounters = int(report.statistics.get("encounter_count", 0))
    for name, count in report.statistics.get("encounters_by_service_line", {}).items():
        share = count / total_encounters if total_encounters else 0
        lines.append(f"| {name} | {count:,} | {share:.1%} |")

    lines.extend(
        [
            "",
            "### By care type",
            "",
            "| Care type | Encounters | Share |",
            "|---|---:|---:|",
        ]
    )
    for name, count in report.statistics.get("encounters_by_care_type", {}).items():
        share = count / total_encounters if total_encounters else 0
        lines.append(f"| {name} | {count:,} | {share:.1%} |")

    lines.extend(
        [
            "",
            "## Statistical Summaries",
            "",
            "| Measure | Count | Min | Mean | Median | P95 | Max |",
            "|---|---:|---:|---:|---:|---:|---:|",
        ]
    )
    summaries = {
        "Age (years)": report.statistics.get("age_summary", {}),
        "Inpatient LOS (days)": report.statistics.get("los_summary_inpatient", {}),
        "Synthetic NWAU": report.statistics.get("synthetic_nwau_summary", {}),
    }
    for field, summary in report.statistics.get("resource_summaries", {}).items():
        summaries[field.replace("_", " ").title()] = summary
    for name, summary in summaries.items():
        lines.append(
            f"| {name} | {summary.get('count', 0):,} | {summary.get('min', '')} | "
            f"{summary.get('mean', '')} | {summary.get('median', '')} | "
            f"{summary.get('p95', '')} | {summary.get('max', '')} |"
        )

    lines.extend(
        [
            "",
            "## Validation Checks",
            "",
            "| Status | Area | Check | Result |",
            "|---|---|---|---|",
        ]
    )
    for result in sorted(report.results, key=lambda item: (status_order[item.status], item.area, item.check_id)):
        detail = result.message
        if result.observed:
            detail += f" Observed: `{result.observed}`."
        if result.expected:
            detail += f" Expected: `{result.expected}`."
        lines.append(f"| {result.status} | {result.area} | `{result.check_id}` | {detail} |")

    lines.extend(
        [
            "",
            "## Interpretation",
            "",
            "- `PASS` means the generated data met the check.",
            "- `EXPECTED` identifies a deliberate exception included to test later SQL controls.",
            "- `WARNING` identifies a plausible but reviewable distribution or calibration issue.",
            "- `ERROR` indicates an unexpected inconsistency and causes the script to exit non-zero.",
            "- Statistical plausibility does not make the synthetic data clinically authoritative.",
            "",
        ]
    )
    markdown_path.write_text("\n".join(lines), encoding="utf-8")
    return json_path, markdown_path


def main() -> int:
    repo_root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--data-root", type=Path, default=repo_root / "data")
    parser.add_argument("--output-dir", type=Path, default=repo_root / "outputs" / "validation")
    args = parser.parse_args()

    report = ValidationReport()
    raw_data = check_required_files(
        report, args.data_root / "raw", RAW_SCHEMAS, "Raw files"
    )
    reference_data = check_required_files(
        report,
        args.data_root / "reference",
        REFERENCE_SCHEMAS,
        "Reference files",
    )
    control_data = check_required_files(
        report, args.data_root / "controls", CONTROL_SCHEMAS, "Control files"
    )
    expected_data = check_required_files(
        report,
        args.data_root / "expected_outputs",
        EXPECTED_OUTPUT_SCHEMAS,
        "Expected outputs",
    )
    source_data = {**raw_data, **reference_data, **control_data}
    abf_data = {**reference_data, **expected_data}

    required_source_loaded = {
        "patient_encounter.csv",
        "resource_usage.csv",
        "direct_cost_detail.csv",
        "general_ledger_transaction.csv",
        "cost_centre.csv",
        "account_mapping.csv",
        "control_row_count.csv",
        "control_gl_monthly.csv",
        "control_gl_cost_centre.csv",
    } <= source_data.keys()
    required_abf_loaded = {
        "abf_activity_group.csv",
        "abf_encounter_funding.csv",
        "abf_monthly_control_total.csv",
    } <= abf_data.keys()

    if required_source_loaded:
        check_row_controls(report, args.data_root, control_data)
        encounter_map = check_encounters(
            report,
            source_data["patient_encounter.csv"],
            source_data["resource_usage.csv"],
        )
        check_resources(report, source_data["resource_usage.csv"], encounter_map)
        check_financials(report, source_data, encounter_map)
        if required_abf_loaded:
            check_abf(report, abf_data, encounter_map)
    check_reasonableness(report)

    json_path, markdown_path = write_reports(report, args.output_dir)
    counts = report.counts
    print(f"Validation status: {'FAIL' if report.has_errors else 'PASS'}")
    print(
        f"Checks: {len(report.results)} | "
        f"PASS={counts.get('PASS', 0)} | "
        f"EXPECTED={counts.get('EXPECTED', 0)} | "
        f"WARNING={counts.get('WARNING', 0)} | "
        f"ERROR={counts.get('ERROR', 0)}"
    )
    print(f"Markdown report: {markdown_path}")
    print(f"JSON report: {json_path}")
    return 1 if report.has_errors else 0


if __name__ == "__main__":
    sys.exit(main())

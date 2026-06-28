USE CostAnalysisABF;
GO

/* ============================================================
   09_create_reporting_views.sql

   Purpose:
   Publish Excel-ready fact and dimension views.

   Design:
   SQL Server owns costing, reconciliation, validation and
   official measures. Excel consumes these views through
   Power Query and the Excel Data Model.
   ============================================================ */


/* ============================================================
   Block 1: Dimension views

    reporting.vw_dim_month
    reporting.vw_dim_facility
    reporting.vw_dim_service_line
    reporting.vw_dim_care_type
    reporting.vw_dim_activity_group
    reporting.vw_dim_cost_category
   ============================================================ */

CREATE OR ALTER VIEW reporting.vw_dim_month
AS
SELECT
    rp.reporting_month,
    rp.period_start,
    rp.period_end,
    rp.financial_year,
    rp.period_number,
    CONCAT(rp.financial_year, ' P', FORMAT(rp.period_number, '00')) AS period_label
FROM ref.reporting_period AS rp;
GO

CREATE OR ALTER VIEW reporting.vw_dim_facility
AS
SELECT DISTINCT
    pe.facility
FROM stg.patient_encounter AS pe;
GO

CREATE OR ALTER VIEW reporting.vw_dim_service_line
AS
SELECT
    sl.service_line,
    sl.description AS service_line_description
FROM ref.service_line AS sl;
GO

CREATE OR ALTER VIEW reporting.vw_dim_care_type
AS
SELECT
    ct.care_type,
    ct.description AS care_type_description
FROM ref.care_type AS ct;
GO

CREATE OR ALTER VIEW reporting.vw_dim_activity_group
AS
SELECT
    ag.activity_group_code,
    ag.activity_group_name,
    ag.default_service_line,
    ag.default_care_type,
    ag.official_classification_flag
FROM ref.activity_group AS ag;
GO

CREATE OR ALTER VIEW reporting.vw_dim_cost_category
AS
SELECT DISTINCT
    cp.cost_category
FROM costing.cost_pool AS cp
WHERE cp.cost_category IS NOT NULL;
GO




--SELECT 'vw_dim_month' AS view_name, COUNT(*) AS row_count
--FROM reporting.vw_dim_month
--UNION ALL
--SELECT 'vw_dim_facility', COUNT(*)
--FROM reporting.vw_dim_facility
--UNION ALL
--SELECT 'vw_dim_service_line', COUNT(*)
--FROM reporting.vw_dim_service_line
--UNION ALL
--SELECT 'vw_dim_care_type', COUNT(*)
--FROM reporting.vw_dim_care_type
--UNION ALL
--SELECT 'vw_dim_activity_group', COUNT(*)
--FROM reporting.vw_dim_activity_group
--UNION ALL
--SELECT 'vw_dim_cost_category', COUNT(*)
--FROM reporting.vw_dim_cost_category;




/* ============================================================
   Block 2: Patient cost fact view

   
    reporting.vw_fact_patient_cost
    reporting.vw_fact_abf_comparison
    reporting.vw_fact_reconciliation
    reporting.vw_fact_data_quality_issue
   ============================================================ */

CREATE OR ALTER VIEW reporting.vw_fact_patient_cost
AS
SELECT
    plc.load_run_id,
    plc.reporting_month,
    plc.encounter_id,
    plc.facility,
    plc.service_line,
    plc.care_type,
    plc.activity_group_code,

    plc.direct_cost_amount,
    plc.indirect_cost_amount,
    plc.overhead_cost_amount,
    plc.total_patient_cost,

    CASE
        WHEN plc.total_patient_cost <> 0
            THEN plc.direct_cost_amount / plc.total_patient_cost
        ELSE NULL
    END AS direct_cost_share,

    CASE
        WHEN plc.total_patient_cost <> 0
            THEN plc.indirect_cost_amount / plc.total_patient_cost
        ELSE NULL
    END AS indirect_cost_share,

    CASE
        WHEN plc.total_patient_cost <> 0
            THEN plc.overhead_cost_amount / plc.total_patient_cost
        ELSE NULL
    END AS overhead_cost_share,

    plc.cost_status,
    plc.high_cost_flag,
    plc.review_note,

    pe.length_of_stay,
    pe.age_years,
    pe.indigenous_status,
    pe.remoteness_area,
    pe.high_complexity_flag,
    pe.hospital_acquired_complication_flag
FROM costing.patient_level_cost AS plc
INNER JOIN stg.patient_encounter AS pe
    ON pe.load_run_id = plc.load_run_id
   AND pe.encounter_id = plc.encounter_id;
GO


--SELECT
--    COUNT(*) AS patient_cost_rows,
--    SUM(direct_cost_amount) AS direct_cost_amount,
--    SUM(indirect_cost_amount) AS indirect_cost_amount,
--    SUM(overhead_cost_amount) AS overhead_cost_amount,
--    SUM(total_patient_cost) AS total_patient_cost,
--    SUM(CASE WHEN high_cost_flag = 'Y' THEN 1 ELSE 0 END) AS high_cost_count
--FROM reporting.vw_fact_patient_cost;


/* ============================================================
   Block 3: ABF comparison fact view
   ============================================================ */

CREATE OR ALTER VIEW reporting.vw_fact_abf_comparison
AS
SELECT
    abf.load_run_id,
    abf.reporting_month,
    abf.encounter_id,
    abf.facility,
    abf.service_line,
    abf.care_type,
    abf.activity_group_code,

    abf.total_patient_cost,
    abf.synthetic_base_weight,
    abf.synthetic_adjustment_factor,
    abf.synthetic_nwau,
    abf.synthetic_funding_amount,
    abf.cost_funding_variance,

    CASE
        WHEN abf.synthetic_funding_amount IS NOT NULL
         AND abf.synthetic_funding_amount <> 0
            THEN abf.cost_funding_variance / abf.synthetic_funding_amount
        ELSE NULL
    END AS cost_funding_variance_pct,

    abf.funding_status,
    abf.review_note
FROM costing.abf_comparison AS abf;
GO


--SELECT
--    funding_status,
--    COUNT(*) AS encounter_count,
--    SUM(total_patient_cost) AS total_patient_cost,
--    SUM(synthetic_nwau) AS synthetic_nwau,
--    SUM(synthetic_funding_amount) AS synthetic_funding_amount,
--    SUM(cost_funding_variance) AS cost_funding_variance
--FROM reporting.vw_fact_abf_comparison
--GROUP BY funding_status
--ORDER BY funding_status;



/* ============================================================
   Block 4: Reconciliation fact view

   Excel usage:
   - Filter reconciliation_level = 'TOTAL' for the headline
     whole-run control total.
   - Filter reconciliation_level = 'COST_POOL' for detailed
     slicing by month, facility, cost centre, cost pool and
     cost category.
   ============================================================ */

CREATE OR ALTER VIEW reporting.vw_fact_reconciliation
AS
SELECT
    r.load_run_id,
    r.reconciliation_level,
    r.reporting_month,
    r.facility,
    r.cost_centre_id,
    r.cost_pool_code,
    r.cost_category,

    r.gl_amount,
    r.direct_assigned_amount,
    r.indirect_allocated_amount,
    r.overhead_allocated_amount,
    r.unallocated_amount,
    r.excluded_amount,
    r.reconciliation_difference,

    CASE
        WHEN r.gl_amount <> 0
            THEN r.reconciliation_difference / r.gl_amount
        ELSE NULL
    END AS reconciliation_difference_pct,

    r.reconciliation_status,
    r.checked_at_utc,
    r.review_note,

    CASE
        WHEN r.reconciliation_level = 'TOTAL'
            THEN 'Total reconciliation'
        ELSE 'Cost-pool reconciliation'
    END AS reconciliation_level_label
FROM recon.costing_reconciliation AS r;
GO


--SELECT
--    reconciliation_level,
--    COUNT(*) AS row_count,
--    COUNT(DISTINCT cost_category) AS cost_category_count,
--    COUNT(DISTINCT cost_pool_code) AS cost_pool_count,
--    SUM(gl_amount) AS gl_amount,
--    SUM(unallocated_amount) AS unallocated_amount,
--    SUM(reconciliation_difference) AS reconciliation_difference
--FROM reporting.vw_fact_reconciliation
--GROUP BY reconciliation_level
--ORDER BY reconciliation_level;


/* ============================================================
   Block 5: Data quality issue fact view
   ============================================================ */

CREATE OR ALTER VIEW reporting.vw_fact_data_quality_issue
AS
SELECT
    vr.load_run_id,
    ir.issue_id,
    vr.validation_rule_id,
    r.rule_name,
    r.rule_category,
    r.severity,
    r.blocking_flag,
    vr.validation_status,

    ir.source_entity,
    ir.landing_row_id,
    ir.source_file_name,
    ir.source_row_number,
    ir.business_key,
    ir.field_name,
    ir.invalid_value,
    ir.financial_impact,
    ir.issue_status,
    ir.recommended_owner,
    ir.recommended_action,
    ir.created_at_utc,
    ir.resolved_at_utc
FROM dq.issue_register AS ir
INNER JOIN dq.validation_result AS vr
    ON vr.validation_result_id = ir.validation_result_id
INNER JOIN dq.validation_rule AS r
    ON r.validation_rule_id = vr.validation_rule_id;
GO


--SELECT
--    severity,
--    blocking_flag,
--    issue_status,
--    COUNT(*) AS issue_count,
--    SUM(COALESCE(financial_impact, 0)) AS financial_impact
--FROM reporting.vw_fact_data_quality_issue
--GROUP BY
--    severity,
--    blocking_flag,
--    issue_status
--ORDER BY
--    severity,
--    blocking_flag,
--    issue_status;



/* ============================================================
   Block 6: Reporting view sanity checks
   ============================================================ */

SELECT
    'vw_fact_patient_cost' AS view_name,
    COUNT(*) AS row_count,
    COUNT(DISTINCT encounter_id) AS distinct_encounters
FROM reporting.vw_fact_patient_cost

UNION ALL

SELECT
    'vw_fact_abf_comparison' AS view_name,
    COUNT(*) AS row_count,
    COUNT(DISTINCT encounter_id) AS distinct_encounters
FROM reporting.vw_fact_abf_comparison;
GO


SELECT
    'patient_cost_vs_abf' AS check_name,
    pc.patient_cost_rows,
    abf.abf_rows,
    pc.patient_cost_total,
    abf.abf_patient_cost_total,
    pc.patient_cost_total - abf.abf_patient_cost_total AS difference
FROM
(
    SELECT
        COUNT(*) AS patient_cost_rows,
        SUM(total_patient_cost) AS patient_cost_total
    FROM reporting.vw_fact_patient_cost
) AS pc
CROSS JOIN
(
    SELECT
        COUNT(*) AS abf_rows,
        SUM(total_patient_cost) AS abf_patient_cost_total
    FROM reporting.vw_fact_abf_comparison
) AS abf;
GO


SELECT
    'data_quality_issues' AS check_name,
    COUNT(*) AS issue_count,
    SUM(COALESCE(financial_impact, 0)) AS financial_impact
FROM reporting.vw_fact_data_quality_issue;
GO


SELECT
    reconciliation_level,
    COUNT(*) AS row_count,
    COUNT(DISTINCT cost_category) AS cost_category_count,
    COUNT(DISTINCT cost_pool_code) AS cost_pool_count,
    SUM(gl_amount) AS gl_amount,
    SUM(unallocated_amount) AS unallocated_amount,
    SUM(reconciliation_difference) AS reconciliation_difference
FROM reporting.vw_fact_reconciliation
GROUP BY reconciliation_level
ORDER BY reconciliation_level;
GO

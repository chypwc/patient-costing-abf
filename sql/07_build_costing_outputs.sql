USE CostAnalysisABF;
GO

/* ============================================================
   07_build_costing_outputs.sql

   Purpose:
   Build official costing outputs from validated staging data.

   Block 1:
   Create cost pools from staged GL transactions.

   Important:
   Unmapped cost centres or accounts are retained as REVIEW pools.
   They are not discarded.
   ============================================================ */


/* ============================================================
   Block 1: Build cost pools

    GL transactions
        ↓ grouped by month + facility + cost centre + account + cost pool
    costing.cost_pool
        ↓ allocated using driver
    patient-level cost
   ============================================================ */

DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

DELETE FROM costing.cost_pool
WHERE load_run_id = @load_run_id;

INSERT INTO costing.cost_pool
(
    load_run_id,
    reporting_month,
    facility,
    cost_centre_id,
    natural_account,
    cost_pool_code,
    cost_category,
    costing_treatment,
    allocation_driver,
    source_transaction_count,
    source_gl_amount,
    pool_status,
    review_note
)
SELECT
    gl.load_run_id,
    gl.reporting_month,
    gl.facility,
    gl.cost_centre_id,
    gl.natural_account,

    COALESCE(cc.cost_pool_code, 'UNMAPPED') AS cost_pool_code,
    COALESCE(am.cost_category, N'Unmapped') AS cost_category,
    COALESCE(am.costing_treatment, 'Review') AS costing_treatment,
    COALESCE(ar.allocation_driver, am.default_driver, 'review') AS allocation_driver,

    COUNT(*) AS source_transaction_count,
    SUM(gl.signed_amount) AS source_gl_amount,

    CASE
        WHEN cc.cost_centre_id IS NULL THEN 'REVIEW'
        WHEN am.natural_account IS NULL THEN 'REVIEW'
        WHEN COALESCE(am.costing_treatment, 'Review') = 'Exclude' THEN 'EXCLUDED'
        ELSE 'READY'
    END AS pool_status,

    CASE
        WHEN cc.cost_centre_id IS NULL THEN N'Cost centre is not mapped to an active governed reference row.'
        WHEN am.natural_account IS NULL THEN N'Natural account is not mapped to an active governed account mapping.'
        WHEN COALESCE(am.costing_treatment, 'Review') = 'Exclude' THEN N'Account mapping marks this cost as excluded from patient costing.'
        ELSE NULL
    END AS review_note
FROM stg.general_ledger_transaction AS gl
LEFT JOIN ref.cost_centre AS cc
    ON cc.cost_centre_id = gl.cost_centre_id
   AND cc.active_flag = 'Y'
   AND gl.reporting_month >= cc.effective_from
   AND gl.reporting_month <= cc.effective_to
LEFT JOIN ref.account_mapping AS am
    ON am.natural_account = gl.natural_account
   AND am.active_flag = 'Y'
LEFT JOIN ref.allocation_rule AS ar
    ON ar.cost_pool_code = cc.cost_pool_code
   AND ar.cost_category = am.cost_category
   AND ar.active_flag = 'Y'
   AND gl.reporting_month >= ar.effective_from
   AND gl.reporting_month <= ar.effective_to
WHERE gl.load_run_id = @load_run_id
GROUP BY
    gl.load_run_id,
    gl.reporting_month,
    gl.facility,
    gl.cost_centre_id,
    gl.natural_account,
    COALESCE(cc.cost_pool_code, 'UNMAPPED'),
    COALESCE(am.cost_category, N'Unmapped'),
    COALESCE(am.costing_treatment, 'Review'),
    COALESCE(ar.allocation_driver, am.default_driver, 'review'),
    CASE
        WHEN cc.cost_centre_id IS NULL THEN 'REVIEW'
        WHEN am.natural_account IS NULL THEN 'REVIEW'
        WHEN COALESCE(am.costing_treatment, 'Review') = 'Exclude' THEN 'EXCLUDED'
        ELSE 'READY'
    END,
    CASE
        WHEN cc.cost_centre_id IS NULL THEN N'Cost centre is not mapped to an active governed reference row.'
        WHEN am.natural_account IS NULL THEN N'Natural account is not mapped to an active governed account mapping.'
        WHEN COALESCE(am.costing_treatment, 'Review') = 'Exclude' THEN N'Account mapping marks this cost as excluded from patient costing.'
        ELSE NULL
    END;
GO



--DECLARE @load_run_id bigint;

--SELECT @load_run_id = MAX(load_run_id)
--FROM dq.load_run
--WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
--  AND load_status = 'COMPLETED';

--SELECT
--    pool_status,
--    COUNT(*) AS pool_count,
--    SUM(source_gl_amount) AS source_gl_amount
--FROM costing.cost_pool
--WHERE load_run_id = @load_run_id
--GROUP BY pool_status
--ORDER BY pool_status;

--SELECT
--    SUM(signed_amount) AS staged_gl_total
--FROM stg.general_ledger_transaction
--WHERE load_run_id = @load_run_id;

--SELECT
--    SUM(source_gl_amount) AS cost_pool_total
--FROM costing.cost_pool
--WHERE load_run_id = @load_run_id;

--SELECT
--    cost_pool_code,
--    cost_category,
--    allocation_driver,
--    source_gl_amount,
--    pool_status,
--    review_note
--FROM costing.cost_pool
--WHERE load_run_id = @load_run_id
--  AND pool_status <> 'READY'
--ORDER BY reporting_month, cost_pool_code;



/* ============================================================
   Block 2: Build encounter drivers
   ============================================================ */

DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

DELETE FROM costing.encounter_driver
WHERE load_run_id = @load_run_id;

INSERT INTO costing.encounter_driver
(
    load_run_id,
    reporting_month,
    encounter_id,
    cost_pool_code,
    allocation_driver,
    driver_units,
    driver_status,
    review_note
)
SELECT
    ru.load_run_id,
    ru.service_month AS reporting_month,
    ru.encounter_id,
    driver_map.cost_pool_code,
    driver_map.allocation_driver,
    driver_map.driver_units,
    CASE
        WHEN driver_map.driver_units > 0 THEN 'VALID'
        ELSE 'EXCLUDED'
    END AS driver_status,
    CASE
        WHEN driver_map.driver_units = 0 THEN N'Zero driver units for this encounter and cost pool.'
        ELSE NULL
    END AS review_note
FROM stg.resource_usage AS ru
/*

Example source row:
encounter_id	bed_days	theatre_minutes	pathology_weighted_units	pharmacy_units
ENC001	2	0	4	10

After CROSS APPLY, it becomes:
encounter_id	cost_pool_code	allocation_driver	driver_units
ENC001	WARD_NURSING	bed_days	2
ENC001	THEATRE	theatre_minutes	0
ENC001	PATHOLOGY	pathology_weighted_units	4
ENC001	PHARMACY	pharmacy_units	10

So CROSS APPLY is doing a manual “unpivot”.


Why convert to decimal(19,6)? allocation math later uses decimals:
allocated amount =
pool amount × encounter driver units / total driver units
*/
CROSS APPLY
(
    VALUES
        ('WARD_NURSING', 'bed_days', CONVERT(decimal(19,6), ru.bed_days)),
        ('THEATRE', 'theatre_minutes', CONVERT(decimal(19,6), ru.theatre_minutes)),
        ('IMAGING', 'imaging_weighted_units', CONVERT(decimal(19,6), ru.imaging_weighted_units)),
        ('PATHOLOGY', 'pathology_weighted_units', CONVERT(decimal(19,6), ru.pathology_weighted_units)),
        ('PHARMACY', 'pharmacy_units', CONVERT(decimal(19,6), ru.pharmacy_units)),
        ('MEDICAL', 'medical_service_units', CONVERT(decimal(19,6), ru.medical_service_units)),
        ('ALLIED_HEALTH', 'allied_health_units', CONVERT(decimal(19,6), ru.allied_health_units))
) AS driver_map
(
    cost_pool_code,
    allocation_driver,
    driver_units
)
WHERE ru.load_run_id = @load_run_id

/*
patient_encounter rows
    ↓ UNION ALL
encounter-count driver rows

| cost_pool_code | Eligible encounters | Driver |
|---|---|---|
| `EMERGENCY_CARE` | Emergency encounters | encounter_count |
| `OUTPATIENT_CARE` | Outpatient encounters | encounter_count |
| `PATIENT_ADMIN` | Other encounters | encounter_count |

EMERGENCY_CARE: emergency nursing/care cost allocated across emergency encounters.
OUTPATIENT_CARE: outpatient clinic nursing/care cost allocated across outpatient encounters.
PATIENT_ADMIN: general patient administration cost allocated across admitted/same-day/other encounters.

*/

UNION ALL

-- Emergency care cost pool:
-- one driver unit for each emergency encounter.
SELECT
    pe.load_run_id,
    pe.episode_month AS reporting_month,
    pe.encounter_id,
    'EMERGENCY_CARE' AS cost_pool_code,
    'encounter_count' AS allocation_driver,
    CONVERT(decimal(19,6), 1) AS driver_units,
    'VALID' AS driver_status,
    NULL AS review_note
FROM stg.patient_encounter AS pe
WHERE pe.load_run_id = @load_run_id
  AND pe.care_type = 'Emergency'

UNION ALL

-- Outpatient care cost pool:
-- one driver unit for each outpatient encounter.
SELECT
    pe.load_run_id,
    pe.episode_month AS reporting_month,
    pe.encounter_id,
    'OUTPATIENT_CARE' AS cost_pool_code,
    'encounter_count' AS allocation_driver,
    CONVERT(decimal(19,6), 1) AS driver_units,
    'VALID' AS driver_status,
    NULL AS review_note
FROM stg.patient_encounter AS pe
WHERE pe.load_run_id = @load_run_id
  AND pe.care_type = 'Outpatient'

UNION ALL

-- Patient administration cost pool:
-- one driver unit for every valid encounter.
SELECT
    pe.load_run_id,
    pe.episode_month AS reporting_month,
    pe.encounter_id,
    'PATIENT_ADMIN' AS cost_pool_code,
    'encounter_count' AS allocation_driver,
    CONVERT(decimal(19,6), 1) AS driver_units,
    'VALID' AS driver_status,
    NULL AS review_note
FROM stg.patient_encounter AS pe
WHERE pe.load_run_id = @load_run_id;
GO


--DECLARE @load_run_id bigint;

--SELECT @load_run_id = MAX(load_run_id)
--FROM dq.load_run
--WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
--  AND load_status = 'COMPLETED';

--SELECT
--    cost_pool_code,
--    allocation_driver,
--    driver_status,
--    COUNT(*) AS driver_rows,
--    SUM(driver_units) AS total_driver_units
--FROM costing.encounter_driver
--WHERE load_run_id = @load_run_id
--GROUP BY
--    cost_pool_code,
--    allocation_driver,
--    driver_status
--ORDER BY
--    cost_pool_code,
--    driver_status;


/* ============================================================
   Block 3: Assign valid direct costs
   ============================================================ */

DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

DELETE FROM costing.direct_cost_assignment
WHERE load_run_id = @load_run_id;

INSERT INTO costing.direct_cost_assignment
(
    load_run_id,
    direct_cost_id,
    encounter_id,
    service_month,
    cost_centre_id,
    natural_account,
    direct_cost_type,
    quantity,
    assigned_amount,
    assignment_status,
    review_note
)
SELECT
    dc.load_run_id,
    dc.direct_cost_id,
    dc.encounter_id,
    dc.service_month,
    dc.cost_centre_id,
    dc.natural_account,
    dc.direct_cost_type,
    dc.quantity,
    dc.amount AS assigned_amount,
    'ASSIGNED' AS assignment_status,
    NULL AS review_note
FROM stg.direct_cost_detail AS dc
WHERE dc.load_run_id = @load_run_id;
GO


--DECLARE @load_run_id bigint;

--SELECT @load_run_id = MAX(load_run_id)
--FROM dq.load_run
--WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
--  AND load_status = 'COMPLETED';

--SELECT
--    COUNT(*) AS assigned_direct_cost_rows,
--    SUM(assigned_amount) AS assigned_direct_cost_amount
--FROM costing.direct_cost_assignment
--WHERE load_run_id = @load_run_id;

--SELECT
--    COUNT(*) AS staged_direct_cost_rows,
--    SUM(amount) AS staged_direct_cost_amount
--FROM stg.direct_cost_detail
--WHERE load_run_id = @load_run_id;

--SELECT
--    COUNT(*) AS landing_direct_cost_rows,
--    SUM(TRY_CONVERT(decimal(19,6), amount)) AS landing_direct_cost_amount
--FROM landing.direct_cost_detail
--WHERE load_run_id = @load_run_id;


/* ============================================================
   Block 4: Allocate indirect costs
   ============================================================ */

DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

DELETE FROM costing.indirect_cost_allocation
WHERE load_run_id = @load_run_id;

;WITH driver_total AS
(
    SELECT
        load_run_id,
        reporting_month,
        cost_pool_code,
        allocation_driver,
        SUM(driver_units) AS total_driver_units
    FROM costing.encounter_driver
    WHERE load_run_id = @load_run_id
      AND driver_status = 'VALID'
    GROUP BY
        load_run_id,
        reporting_month,
        cost_pool_code,
        allocation_driver
),
allocatable_pool AS
(
    SELECT
        cp.cost_pool_id,
        cp.load_run_id,
        cp.reporting_month,
        cp.cost_pool_code,
        cp.allocation_driver,
        cp.source_gl_amount,
        dt.total_driver_units
    FROM costing.cost_pool AS cp
    INNER JOIN driver_total AS dt
        ON dt.load_run_id = cp.load_run_id
       AND dt.reporting_month = cp.reporting_month
       AND dt.cost_pool_code = cp.cost_pool_code
       AND dt.allocation_driver = cp.allocation_driver
    WHERE cp.load_run_id = @load_run_id
      AND cp.pool_status = 'READY'
      AND cp.costing_treatment = 'Indirect'
      AND dt.total_driver_units > 0
)
INSERT INTO costing.indirect_cost_allocation
(
    load_run_id,
    cost_pool_id,
    encounter_driver_id,
    reporting_month,
    encounter_id,
    cost_pool_code,
    allocation_driver,
    encounter_driver_units,
    total_driver_units,
    allocation_rate,
    allocated_amount,
    allocation_status,
    review_note
)
SELECT
    ap.load_run_id,
    ap.cost_pool_id,
    ed.encounter_driver_id,
    ap.reporting_month,
    ed.encounter_id,
    ap.cost_pool_code,
    ap.allocation_driver,
    ed.driver_units AS encounter_driver_units,
    ap.total_driver_units,
    ap.source_gl_amount / ap.total_driver_units AS allocation_rate,
    ed.driver_units * (ap.source_gl_amount / ap.total_driver_units) AS allocated_amount,
    'ALLOCATED' AS allocation_status,
    NULL AS review_note
FROM allocatable_pool AS ap
INNER JOIN costing.encounter_driver AS ed
    ON ed.load_run_id = ap.load_run_id
   AND ed.reporting_month = ap.reporting_month
   AND ed.cost_pool_code = ap.cost_pool_code
   AND ed.allocation_driver = ap.allocation_driver
   AND ed.driver_status = 'VALID';
GO


--DECLARE @load_run_id bigint;

--SELECT @load_run_id = MAX(load_run_id)
--FROM dq.load_run
--WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
--  AND load_status = 'COMPLETED';

--SELECT
--    COUNT(*) AS allocation_rows,
--    SUM(allocated_amount) AS allocated_amount
--FROM costing.indirect_cost_allocation
--WHERE load_run_id = @load_run_id;

--SELECT
--    SUM(source_gl_amount) AS allocatable_indirect_pool_amount
--FROM costing.cost_pool AS cp
--WHERE cp.load_run_id = @load_run_id
--  AND cp.pool_status = 'READY'
--  AND cp.costing_treatment = 'Indirect'
--  AND EXISTS
--  (
--      SELECT 1
--      FROM costing.indirect_cost_allocation AS ia
--      WHERE ia.load_run_id = cp.load_run_id
--        AND ia.cost_pool_id = cp.cost_pool_id
--  );

--SELECT
--    cost_pool_code,
--    SUM(allocated_amount) AS allocated_amount
--FROM costing.indirect_cost_allocation
--WHERE load_run_id = @load_run_id
--GROUP BY cost_pool_code
--ORDER BY cost_pool_code;





/* ============================================================
   Block 5: Build pre-overhead driver rows
   ============================================================ */

DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

DELETE FROM costing.encounter_driver
WHERE load_run_id = @load_run_id
  AND cost_pool_code = 'OVERHEAD'
  AND allocation_driver = 'pre_overhead_cost';

;WITH direct_cost AS
(
    SELECT
        load_run_id,
        service_month AS reporting_month,
        encounter_id,
        SUM(assigned_amount) AS direct_cost_amount
    FROM costing.direct_cost_assignment
    WHERE load_run_id = @load_run_id
      AND assignment_status = 'ASSIGNED'
    GROUP BY
        load_run_id,
        service_month,
        encounter_id
),
indirect_cost AS
(
    SELECT
        load_run_id,
        reporting_month,
        encounter_id,
        SUM(allocated_amount) AS indirect_cost_amount
    FROM costing.indirect_cost_allocation
    WHERE load_run_id = @load_run_id
      AND allocation_status = 'ALLOCATED'
    GROUP BY
        load_run_id,
        reporting_month,
        encounter_id
),
pre_overhead AS
(
    SELECT
        pe.load_run_id,
        pe.episode_month AS reporting_month,
        pe.encounter_id,
        COALESCE(dc.direct_cost_amount, 0) AS direct_cost_amount,
        COALESCE(ic.indirect_cost_amount, 0) AS indirect_cost_amount,
        COALESCE(dc.direct_cost_amount, 0)
        + COALESCE(ic.indirect_cost_amount, 0) AS pre_overhead_cost
    FROM stg.patient_encounter AS pe
    LEFT JOIN direct_cost AS dc
        ON dc.load_run_id = pe.load_run_id
       AND dc.reporting_month = pe.episode_month
       AND dc.encounter_id = pe.encounter_id
    LEFT JOIN indirect_cost AS ic
        ON ic.load_run_id = pe.load_run_id
       AND ic.reporting_month = pe.episode_month
       AND ic.encounter_id = pe.encounter_id
    WHERE pe.load_run_id = @load_run_id
)
INSERT INTO costing.encounter_driver
(
    load_run_id,
    reporting_month,
    encounter_id,
    cost_pool_code,
    allocation_driver,
    driver_units,
    driver_status,
    review_note
)
SELECT
    load_run_id,
    reporting_month,
    encounter_id,
    'OVERHEAD' AS cost_pool_code,
    'pre_overhead_cost' AS allocation_driver,
    pre_overhead_cost AS driver_units,
    CASE
        WHEN pre_overhead_cost > 0 THEN 'VALID'
        ELSE 'EXCLUDED'
    END AS driver_status,
    CASE
        WHEN pre_overhead_cost = 0 THEN N'No direct or indirect patient-care cost before overhead allocation.'
        ELSE NULL
    END AS review_note
FROM pre_overhead;
GO





--DECLARE @load_run_id bigint;

--SELECT @load_run_id = MAX(load_run_id)
--FROM dq.load_run
--WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
--  AND load_status = 'COMPLETED';

--SELECT
--    cost_pool_code,
--    allocation_driver,
--    driver_status,
--    COUNT(*) AS driver_rows,
--    SUM(driver_units) AS total_driver_units
--FROM costing.encounter_driver
--WHERE load_run_id = @load_run_id
--  AND cost_pool_code = 'OVERHEAD'
--GROUP BY
--    cost_pool_code,
--    allocation_driver,
--    driver_status
--ORDER BY driver_status;



/* ============================================================
   Block 6: Allocate overhead costs
   ============================================================ */

DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

DELETE ia
FROM costing.indirect_cost_allocation AS ia
INNER JOIN costing.cost_pool AS cp
    ON cp.cost_pool_id = ia.cost_pool_id
WHERE ia.load_run_id = @load_run_id
  AND cp.costing_treatment = 'Overhead';

;WITH driver_total AS
(
    SELECT
        load_run_id,
        reporting_month,
        cost_pool_code,
        allocation_driver,
        SUM(driver_units) AS total_driver_units
    FROM costing.encounter_driver
    WHERE load_run_id = @load_run_id
      AND driver_status = 'VALID'
      AND cost_pool_code = 'OVERHEAD'
      AND allocation_driver = 'pre_overhead_cost'
    GROUP BY
        load_run_id,
        reporting_month,
        cost_pool_code,
        allocation_driver
),
overhead_pool AS
(
    SELECT
        cp.cost_pool_id,
        cp.load_run_id,
        cp.reporting_month,
        cp.cost_pool_code,
        cp.allocation_driver,
        cp.source_gl_amount,
        dt.total_driver_units
    FROM costing.cost_pool AS cp
    INNER JOIN driver_total AS dt
        ON dt.load_run_id = cp.load_run_id
       AND dt.reporting_month = cp.reporting_month
       AND dt.cost_pool_code = cp.cost_pool_code
       AND dt.allocation_driver = cp.allocation_driver
    WHERE cp.load_run_id = @load_run_id
      AND cp.pool_status = 'READY'
      AND cp.costing_treatment = 'Overhead'
      AND dt.total_driver_units > 0
)
INSERT INTO costing.indirect_cost_allocation
(
    load_run_id,
    cost_pool_id,
    encounter_driver_id,
    reporting_month,
    encounter_id,
    cost_pool_code,
    allocation_driver,
    encounter_driver_units,
    total_driver_units,
    allocation_rate,
    allocated_amount,
    allocation_status,
    review_note
)
SELECT
    op.load_run_id,
    op.cost_pool_id,
    ed.encounter_driver_id,
    op.reporting_month,
    ed.encounter_id,
    op.cost_pool_code,
    op.allocation_driver,
    ed.driver_units AS encounter_driver_units,
    op.total_driver_units,
    op.source_gl_amount / op.total_driver_units AS allocation_rate,
    ed.driver_units * (op.source_gl_amount / op.total_driver_units) AS allocated_amount,
    'ALLOCATED' AS allocation_status,
    NULL AS review_note
FROM overhead_pool AS op
INNER JOIN costing.encounter_driver AS ed
    ON ed.load_run_id = op.load_run_id
   AND ed.reporting_month = op.reporting_month
   AND ed.cost_pool_code = op.cost_pool_code
   AND ed.allocation_driver = op.allocation_driver
   AND ed.driver_status = 'VALID';
GO



--DECLARE @load_run_id bigint;

--SELECT @load_run_id = MAX(load_run_id)
--FROM dq.load_run
--WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
--  AND load_status = 'COMPLETED';

--SELECT
--    COUNT(*) AS overhead_allocation_rows,
--    SUM(allocated_amount) AS overhead_allocated_amount
--FROM costing.indirect_cost_allocation AS ia
--INNER JOIN costing.cost_pool AS cp
--    ON cp.cost_pool_id = ia.cost_pool_id
--WHERE ia.load_run_id = @load_run_id
--  AND cp.costing_treatment = 'Overhead';

--SELECT
--    SUM(source_gl_amount) AS overhead_pool_amount
--FROM costing.cost_pool
--WHERE load_run_id = @load_run_id
--  AND pool_status = 'READY'
--  AND costing_treatment = 'Overhead';



/* ============================================================
   Block 7: Create patient-level cost
   ============================================================ */

DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

DELETE FROM costing.patient_level_cost
WHERE load_run_id = @load_run_id;

;WITH direct_cost AS
(
    SELECT
        load_run_id,
        service_month AS reporting_month,
        encounter_id,
        SUM(assigned_amount) AS direct_cost_amount
    FROM costing.direct_cost_assignment
    WHERE load_run_id = @load_run_id
      AND assignment_status = 'ASSIGNED'
    GROUP BY
        load_run_id,
        service_month,
        encounter_id
),
allocated_cost AS
(
    SELECT
        ia.load_run_id,
        ia.reporting_month,
        ia.encounter_id,
        SUM
        (
            CASE
                WHEN cp.costing_treatment = 'Indirect' THEN ia.allocated_amount
                ELSE 0
            END
        ) AS indirect_cost_amount,
        SUM
        (
            CASE
                WHEN cp.costing_treatment = 'Overhead' THEN ia.allocated_amount
                ELSE 0
            END
        ) AS overhead_cost_amount
    FROM costing.indirect_cost_allocation AS ia
    INNER JOIN costing.cost_pool AS cp
        ON cp.cost_pool_id = ia.cost_pool_id
    WHERE ia.load_run_id = @load_run_id
      AND ia.allocation_status = 'ALLOCATED'
    GROUP BY
        ia.load_run_id,
        ia.reporting_month,
        ia.encounter_id
),
patient_cost AS
(
    SELECT
        pe.load_run_id,
        pe.episode_month AS reporting_month,
        pe.encounter_id,
        pe.facility,
        pe.service_line,
        pe.care_type,
        pe.activity_group_code,
        COALESCE(dc.direct_cost_amount, 0) AS direct_cost_amount,
        COALESCE(ac.indirect_cost_amount, 0) AS indirect_cost_amount,
        COALESCE(ac.overhead_cost_amount, 0) AS overhead_cost_amount
    FROM stg.patient_encounter AS pe
    LEFT JOIN direct_cost AS dc
        ON dc.load_run_id = pe.load_run_id
       AND dc.reporting_month = pe.episode_month
       AND dc.encounter_id = pe.encounter_id
    LEFT JOIN allocated_cost AS ac
        ON ac.load_run_id = pe.load_run_id
       AND ac.reporting_month = pe.episode_month
       AND ac.encounter_id = pe.encounter_id
    WHERE pe.load_run_id = @load_run_id
)
INSERT INTO costing.patient_level_cost
(
    load_run_id,
    reporting_month,
    encounter_id,
    facility,
    service_line,
    care_type,
    activity_group_code,
    direct_cost_amount,
    indirect_cost_amount,
    overhead_cost_amount,
    cost_status,
    high_cost_flag,
    review_note
)
SELECT
    load_run_id,
    reporting_month,
    encounter_id,
    facility,
    service_line,
    care_type,
    activity_group_code,
    direct_cost_amount,
    indirect_cost_amount,
    overhead_cost_amount,
    'FINAL' AS cost_status,
    'N' AS high_cost_flag,
    NULL AS review_note
FROM patient_cost;
GO



--DECLARE @load_run_id bigint;

--SELECT @load_run_id = MAX(load_run_id)
--FROM dq.load_run
--WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
--  AND load_status = 'COMPLETED';

--SELECT
--    COUNT(*) AS patient_level_cost_rows,
--    SUM(direct_cost_amount) AS direct_cost_amount,
--    SUM(indirect_cost_amount) AS indirect_cost_amount,
--    SUM(overhead_cost_amount) AS overhead_cost_amount,
--    SUM(total_patient_cost) AS total_patient_cost,
--    SUM(CASE WHEN high_cost_flag = 'Y' THEN 1 ELSE 0 END) AS high_cost_encounter_count
--FROM costing.patient_level_cost
--WHERE load_run_id = @load_run_id;



/* ============================================================
   Block 8: Flag high-cost encounters within comparable groups

   Design:
   High-cost = encounter total cost >= 95th percentile
   within the same care_type + activity_group_code cohort.

   Cohorts with fewer than 20 encounters are not flagged.
   ============================================================ */

DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

;WITH cohort AS
(
    SELECT
        patient_level_cost_id,
        care_type,
        activity_group_code,
        total_patient_cost,
        COUNT(*) OVER
        (
            PARTITION BY care_type, activity_group_code
        ) AS cohort_count,
        PERCENTILE_CONT(0.95) WITHIN GROUP
        (
            ORDER BY total_patient_cost
        )
        OVER
        (
            PARTITION BY care_type, activity_group_code
        ) AS p95_total_patient_cost
    FROM costing.patient_level_cost
    WHERE load_run_id = @load_run_id
)
UPDATE plc
SET
    high_cost_flag =
        CASE
            WHEN c.cohort_count >= 20
             AND c.total_patient_cost >= c.p95_total_patient_cost
                THEN 'Y'
            ELSE 'N'
        END,
    review_note =
        CASE
            WHEN c.cohort_count < 20
                THEN N'Cohort has fewer than 20 encounters; high-cost comparison not considered stable.'
            WHEN c.total_patient_cost >= c.p95_total_patient_cost
                THEN CONCAT
                (
                    N'High-cost flag: total patient cost is at or above the cohort 95th percentile. Cohort count=',
                    c.cohort_count,
                    N'; p95=',
                    CONVERT(nvarchar(50), CONVERT(decimal(19,2), c.p95_total_patient_cost))
                )
            ELSE NULL
        END
FROM costing.patient_level_cost AS plc
INNER JOIN cohort AS c
    ON c.patient_level_cost_id = plc.patient_level_cost_id
WHERE plc.load_run_id = @load_run_id;
GO


--DECLARE @load_run_id bigint;

--SELECT @load_run_id = MAX(load_run_id)
--FROM dq.load_run
--WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
--  AND load_status = 'COMPLETED';

--SELECT
--    high_cost_flag,
--    COUNT(*) AS encounter_count,
--    SUM(total_patient_cost) AS total_patient_cost
--FROM costing.patient_level_cost
--WHERE load_run_id = @load_run_id
--GROUP BY high_cost_flag
--ORDER BY high_cost_flag;

--SELECT TOP 20
--    encounter_id,
--    care_type,
--    activity_group_code,
--    total_patient_cost,
--    high_cost_flag,
--    review_note
--FROM costing.patient_level_cost
--WHERE load_run_id = @load_run_id
--  AND high_cost_flag = 'Y'
--ORDER BY total_patient_cost DESC;



/* ============================================================
   Block 9: Record unallocated and excluded costs
   ============================================================ */

DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

DELETE FROM costing.unallocated_cost
WHERE load_run_id = @load_run_id;


/* 1. Review cost pools: unmapped cost centre, unmapped account, or other review */
INSERT INTO costing.unallocated_cost
(
    load_run_id,
    reporting_month,
    facility,
    cost_centre_id,
    natural_account,
    cost_pool_id,
    cost_pool_code,
    cost_category,
    unallocated_reason,
    unallocated_amount,
    source_record_type,
    source_record_id,
    resolution_status,
    review_note
)
SELECT
    cp.load_run_id,
    cp.reporting_month,
    cp.facility,
    cp.cost_centre_id,
    cp.natural_account,
    cp.cost_pool_id,
    cp.cost_pool_code,
    cp.cost_category,
    CASE
        WHEN cp.review_note LIKE N'Cost centre is not mapped%' THEN 'UNMAPPED_COST_CENTRE'
        WHEN cp.review_note LIKE N'Natural account is not mapped%' THEN 'UNMAPPED_ACCOUNT'
        ELSE 'REVIEW'
    END AS unallocated_reason,
    cp.source_gl_amount,
    'COST_POOL',
    CONVERT(varchar(30), cp.cost_pool_id),
    'OPEN',
    cp.review_note
FROM costing.cost_pool AS cp
WHERE cp.load_run_id = @load_run_id
  AND cp.pool_status = 'REVIEW';


/* 2. Excluded cost pools */
INSERT INTO costing.unallocated_cost
(
    load_run_id,
    reporting_month,
    facility,
    cost_centre_id,
    natural_account,
    cost_pool_id,
    cost_pool_code,
    cost_category,
    unallocated_reason,
    unallocated_amount,
    source_record_type,
    source_record_id,
    resolution_status,
    review_note
)
SELECT
    cp.load_run_id,
    cp.reporting_month,
    cp.facility,
    cp.cost_centre_id,
    cp.natural_account,
    cp.cost_pool_id,
    cp.cost_pool_code,
    cp.cost_category,
    'EXCLUDED_ADJUSTMENT',
    cp.source_gl_amount,
    'COST_POOL',
    CONVERT(varchar(30), cp.cost_pool_id),
    'EXCLUDED',
    COALESCE(cp.review_note, N'Cost pool excluded from patient-level costing.')
FROM costing.cost_pool AS cp
WHERE cp.load_run_id = @load_run_id
  AND cp.pool_status = 'EXCLUDED';


/* 3. Zero-driver indirect pools */
;WITH driver_total AS
(
    SELECT
        load_run_id,
        reporting_month,
        cost_pool_code,
        allocation_driver,
        SUM(CASE WHEN driver_status = 'VALID' THEN driver_units ELSE 0 END) AS total_valid_driver_units
    FROM costing.encounter_driver
    WHERE load_run_id = @load_run_id
    GROUP BY
        load_run_id,
        reporting_month,
        cost_pool_code,
        allocation_driver
)
INSERT INTO costing.unallocated_cost
(
    load_run_id,
    reporting_month,
    facility,
    cost_centre_id,
    natural_account,
    cost_pool_id,
    cost_pool_code,
    cost_category,
    unallocated_reason,
    unallocated_amount,
    source_record_type,
    source_record_id,
    resolution_status,
    review_note
)
SELECT
    cp.load_run_id,
    cp.reporting_month,
    cp.facility,
    cp.cost_centre_id,
    cp.natural_account,
    cp.cost_pool_id,
    cp.cost_pool_code,
    cp.cost_category,
    'ZERO_DRIVER_POOL',
    cp.source_gl_amount,
    'COST_POOL',
    CONVERT(varchar(30), cp.cost_pool_id),
    'OPEN',
    N'Cost pool has GL amount but no valid eligible driver units.'
FROM costing.cost_pool AS cp
LEFT JOIN driver_total AS dt
    ON dt.load_run_id = cp.load_run_id
   AND dt.reporting_month = cp.reporting_month
   AND dt.cost_pool_code = cp.cost_pool_code
   AND dt.allocation_driver = cp.allocation_driver
WHERE cp.load_run_id = @load_run_id
  AND cp.pool_status = 'READY'
  AND cp.costing_treatment = 'Indirect'
  AND cp.source_gl_amount <> 0
  AND COALESCE(dt.total_valid_driver_units, 0) = 0;


/* 4. Direct costs that failed promotion */
INSERT INTO costing.unallocated_cost
(
    load_run_id,
    reporting_month,
    facility,
    cost_centre_id,
    natural_account,
    cost_pool_id,
    cost_pool_code,
    cost_category,
    unallocated_reason,
    unallocated_amount,
    source_record_type,
    source_record_id,
    resolution_status,
    review_note
)
SELECT
    l.load_run_id,
    TRY_CONVERT(date, l.service_month) AS reporting_month,
    NULL AS facility,
    CAST(l.cost_centre_id AS varchar(30)) AS cost_centre_id,
    CAST(l.natural_account AS varchar(20)) AS natural_account,
    NULL AS cost_pool_id,
    'DIRECT_COST',
    N'Direct Cost',
    'FAILED_DIRECT_ASSIGNMENT',
    TRY_CONVERT(decimal(19,6), l.amount) AS unallocated_amount,
    'DIRECT_COST',
    CAST(l.direct_cost_id AS varchar(30)) AS source_record_id,
    'OPEN',
    N'Direct cost could not be assigned to a valid staged encounter.'
FROM landing.direct_cost_detail AS l
LEFT JOIN stg.direct_cost_detail AS s
    ON s.landing_row_id = l.landing_row_id
WHERE l.load_run_id = @load_run_id
  AND s.landing_row_id IS NULL;
GO



--DECLARE @load_run_id bigint;

--SELECT @load_run_id = MAX(load_run_id)
--FROM dq.load_run
--WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
--  AND load_status = 'COMPLETED';

--SELECT
--    unallocated_reason,
--    COUNT(*) AS row_count,
--    SUM(unallocated_amount) AS unallocated_amount
--FROM costing.unallocated_cost
--WHERE load_run_id = @load_run_id
--GROUP BY unallocated_reason
--ORDER BY unallocated_reason;

--SELECT
--    SUM(unallocated_amount) AS total_unallocated_amount
--FROM costing.unallocated_cost
--WHERE load_run_id = @load_run_id;



/* ============================================================
   Block 10: Build ABF decision-support comparison

   Synthetic only:
   This is not an official NWAU or payment model.
   ============================================================ */

DECLARE @load_run_id bigint;
DECLARE @synthetic_base_price decimal(19,6) = 10750.000000;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

DELETE FROM costing.abf_comparison
WHERE load_run_id = @load_run_id;

;WITH abf_calc AS
(
    SELECT
        plc.load_run_id,
        plc.reporting_month,
        plc.encounter_id,
        plc.facility,
        plc.service_line,
        plc.care_type,
        plc.activity_group_code,
        plc.total_patient_cost,

        abf.synthetic_base_weight,

        CASE
            WHEN abf.activity_group_code IS NULL THEN NULL
            ELSE
                CONVERT(decimal(12,6),
                    1.000000
                    * CASE WHEN pe.indigenous_status = 'Y' THEN 1.040000 ELSE 1.000000 END
                    * CASE WHEN pe.remoteness_area = 'Remote' THEN 1.060000 ELSE 1.000000 END
                    * CASE WHEN pe.age_years < 18 AND abf.service_stream = 'Admitted acute' THEN 1.050000 ELSE 1.000000 END
                    * CASE WHEN pe.care_type = 'Same-day' AND pe.activity_group_code = 'AG04' THEN 0.920000 ELSE 1.000000 END
                )
        END AS synthetic_adjustment_factor,

        CASE
            WHEN abf.activity_group_code IS NULL THEN NULL
            ELSE
                CONVERT(decimal(19,6),
                    abf.synthetic_base_weight
                    *
                    (
                        1.000000
                        * CASE WHEN pe.indigenous_status = 'Y' THEN 1.040000 ELSE 1.000000 END
                        * CASE WHEN pe.remoteness_area = 'Remote' THEN 1.060000 ELSE 1.000000 END
                        * CASE WHEN pe.age_years < 18 AND abf.service_stream = 'Admitted acute' THEN 1.050000 ELSE 1.000000 END
                        * CASE WHEN pe.care_type = 'Same-day' AND pe.activity_group_code = 'AG04' THEN 0.920000 ELSE 1.000000 END
                    )
                    +
                    CASE
                        WHEN pe.length_of_stay > abf.high_length_of_stay_trim_days
                            THEN (pe.length_of_stay - abf.high_length_of_stay_trim_days) * abf.synthetic_outlier_nwau_per_day
                        ELSE 0
                    END
                )
        END AS synthetic_nwau,

        CASE
            WHEN abf.activity_group_code IS NULL
                THEN 'UNFUNDED_REVIEW'
            ELSE 'FUNDED'
        END AS funding_status,

        CASE
            WHEN abf.activity_group_code IS NULL
                THEN N'Activity group is unclassified or unsupported for synthetic ABF comparison.'
            ELSE N'Synthetic ABF estimate using base weight, demonstration adjustments and long-stay outlier logic.'
        END AS review_note
    FROM costing.patient_level_cost AS plc
    INNER JOIN stg.patient_encounter AS pe
        ON pe.load_run_id = plc.load_run_id
       AND pe.encounter_id = plc.encounter_id
    LEFT JOIN ref.abf_activity_group AS abf
        ON abf.activity_group_code = plc.activity_group_code
    WHERE plc.load_run_id = @load_run_id
)
INSERT INTO costing.abf_comparison
(
    load_run_id,
    reporting_month,
    encounter_id,
    facility,
    service_line,
    care_type,
    activity_group_code,
    total_patient_cost,
    synthetic_base_weight,
    synthetic_adjustment_factor,
    synthetic_nwau,
    synthetic_funding_amount,
    funding_status,
    review_note
)
SELECT
    load_run_id,
    reporting_month,
    encounter_id,
    facility,
    service_line,
    care_type,
    activity_group_code,
    total_patient_cost,
    synthetic_base_weight,
    synthetic_adjustment_factor,
    synthetic_nwau,
    synthetic_nwau * @synthetic_base_price AS synthetic_funding_amount,
    funding_status,
    review_note
FROM abf_calc;
GO


DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

SELECT
    funding_status,
    COUNT(*) AS encounter_count,
    SUM(total_patient_cost) AS total_patient_cost,
    SUM(synthetic_nwau) AS synthetic_nwau,
    SUM(synthetic_funding_amount) AS synthetic_funding_amount,
    SUM(cost_funding_variance) AS cost_funding_variance
FROM costing.abf_comparison
WHERE load_run_id = @load_run_id
GROUP BY funding_status
ORDER BY funding_status;




USE CostAnalysisABF;
GO

/* ============================================================
   Reconciliation block within 07_build_costing_outputs.sql

   Purpose:
   Reconcile GL expenditure to costing outputs.

   Equation:
   GL amount
   = direct assigned
   + indirect allocated
   + overhead allocated
   + unallocated
   + excluded
   + reconciliation difference
   ============================================================ */


/* ============================================================
   Block 1: Cost-pool and total reconciliation

   Design:
   - COST_POOL rows support Excel slicing by reporting month,
     facility, cost centre, cost pool and cost category.
   - TOTAL row proves whole-run GL reconciliation.
   ============================================================ */

DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

DELETE FROM recon.costing_reconciliation
WHERE load_run_id = @load_run_id;

;WITH direct_by_pool AS
(
    SELECT
        cp.cost_pool_id,
        SUM(dca.assigned_amount) AS direct_assigned_amount
    FROM costing.cost_pool AS cp
    INNER JOIN costing.direct_cost_assignment AS dca
        ON dca.load_run_id = cp.load_run_id
       AND dca.service_month = cp.reporting_month
       AND dca.cost_centre_id = cp.cost_centre_id
       AND dca.natural_account = cp.natural_account
       AND dca.assignment_status = 'ASSIGNED'
    WHERE cp.load_run_id = @load_run_id
    GROUP BY
        cp.cost_pool_id
),
allocation_by_pool AS
(
    SELECT
        cp.cost_pool_id,
        SUM
        (
            CASE
                WHEN cp.costing_treatment = 'Indirect'
                    THEN ia.allocated_amount
                ELSE 0
            END
        ) AS indirect_allocated_amount,
        SUM
        (
            CASE
                WHEN cp.costing_treatment = 'Overhead'
                    THEN ia.allocated_amount
                ELSE 0
            END
        ) AS overhead_allocated_amount
    FROM costing.cost_pool AS cp
    INNER JOIN costing.indirect_cost_allocation AS ia
        ON ia.cost_pool_id = cp.cost_pool_id
       AND ia.load_run_id = cp.load_run_id
       AND ia.allocation_status = 'ALLOCATED'
    WHERE cp.load_run_id = @load_run_id
    GROUP BY
        cp.cost_pool_id
),
unallocated_by_pool AS
(
    SELECT
        uc.cost_pool_id,
        SUM
        (
            CASE
                WHEN uc.resolution_status <> 'EXCLUDED'
                    THEN uc.unallocated_amount
                ELSE 0
            END
        ) AS unallocated_amount,
        SUM
        (
            CASE
                WHEN uc.resolution_status = 'EXCLUDED'
                    THEN uc.unallocated_amount
                ELSE 0
            END
        ) AS excluded_amount
    FROM costing.unallocated_cost AS uc
    WHERE uc.load_run_id = @load_run_id
      AND uc.cost_pool_id IS NOT NULL
    GROUP BY
        uc.cost_pool_id
)
INSERT INTO recon.costing_reconciliation
(
    load_run_id,
    reconciliation_level,
    reporting_month,
    facility,
    cost_centre_id,
    cost_pool_code,
    cost_category,
    gl_amount,
    direct_assigned_amount,
    indirect_allocated_amount,
    overhead_allocated_amount,
    unallocated_amount,
    excluded_amount,
    reconciliation_status,
    review_note
)
SELECT
    cp.load_run_id,
    'COST_POOL' AS reconciliation_level,
    cp.reporting_month,
    cp.facility,
    cp.cost_centre_id,
    cp.cost_pool_code,
    cp.cost_category,
    cp.source_gl_amount AS gl_amount,
    COALESCE(dbp.direct_assigned_amount, 0) AS direct_assigned_amount,
    COALESCE(abp.indirect_allocated_amount, 0) AS indirect_allocated_amount,
    COALESCE(abp.overhead_allocated_amount, 0) AS overhead_allocated_amount,
    COALESCE(ubp.unallocated_amount, 0) AS unallocated_amount,
    COALESCE(ubp.excluded_amount, 0) AS excluded_amount,
    CASE
        WHEN ABS
        (
            cp.source_gl_amount
            - COALESCE(dbp.direct_assigned_amount, 0)
            - COALESCE(abp.indirect_allocated_amount, 0)
            - COALESCE(abp.overhead_allocated_amount, 0)
            - COALESCE(ubp.unallocated_amount, 0)
            - COALESCE(ubp.excluded_amount, 0)
        ) <= 1.00
            THEN 'PASS'
        ELSE 'REVIEW'
    END AS reconciliation_status,
    CASE
        WHEN cp.pool_status = 'REVIEW'
            THEN cp.review_note
        WHEN ABS
        (
            cp.source_gl_amount
            - COALESCE(dbp.direct_assigned_amount, 0)
            - COALESCE(abp.indirect_allocated_amount, 0)
            - COALESCE(abp.overhead_allocated_amount, 0)
            - COALESCE(ubp.unallocated_amount, 0)
            - COALESCE(ubp.excluded_amount, 0)
        ) > 1.00
            THEN N'Cost pool does not reconcile at detailed level; review direct assignment, allocation or unallocated treatment.'
        ELSE NULL
    END AS review_note
FROM costing.cost_pool AS cp
LEFT JOIN direct_by_pool AS dbp
    ON dbp.cost_pool_id = cp.cost_pool_id
LEFT JOIN allocation_by_pool AS abp
    ON abp.cost_pool_id = cp.cost_pool_id
LEFT JOIN unallocated_by_pool AS ubp
    ON ubp.cost_pool_id = cp.cost_pool_id
WHERE cp.load_run_id = @load_run_id;
GO


/* ============================================================
   Block 2: Unallocated costs without a matched cost pool
   ============================================================ */

DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

INSERT INTO recon.costing_reconciliation
(
    load_run_id,
    reconciliation_level,
    reporting_month,
    facility,
    cost_centre_id,
    cost_pool_code,
    cost_category,
    gl_amount,
    direct_assigned_amount,
    indirect_allocated_amount,
    overhead_allocated_amount,
    unallocated_amount,
    excluded_amount,
    reconciliation_status,
    review_note
)
SELECT
    uc.load_run_id,
    'COST_POOL' AS reconciliation_level,
    uc.reporting_month,
    uc.facility,
    uc.cost_centre_id,
    uc.cost_pool_code,
    uc.cost_category,
    0 AS gl_amount,
    0 AS direct_assigned_amount,
    0 AS indirect_allocated_amount,
    0 AS overhead_allocated_amount,
    SUM
    (
        CASE
            WHEN uc.resolution_status <> 'EXCLUDED'
                THEN uc.unallocated_amount
            ELSE 0
        END
    ) AS unallocated_amount,
    SUM
    (
        CASE
            WHEN uc.resolution_status = 'EXCLUDED'
                THEN uc.unallocated_amount
            ELSE 0
        END
    ) AS excluded_amount,
    'REVIEW' AS reconciliation_status,
    N'Unallocated cost without a matched cost pool.'
FROM costing.unallocated_cost AS uc
WHERE uc.load_run_id = @load_run_id
  AND uc.cost_pool_id IS NULL
GROUP BY
    uc.load_run_id,
    uc.reporting_month,
    uc.facility,
    uc.cost_centre_id,
    uc.cost_pool_code,
    uc.cost_category;
GO


/* ============================================================
   Block 3: Total reconciliation summarised from COST_POOL rows
   ============================================================ */

DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

INSERT INTO recon.costing_reconciliation
(
    load_run_id,
    reconciliation_level,
    reporting_month,
    facility,
    cost_centre_id,
    cost_pool_code,
    cost_category,
    gl_amount,
    direct_assigned_amount,
    indirect_allocated_amount,
    overhead_allocated_amount,
    unallocated_amount,
    excluded_amount,
    reconciliation_status,
    review_note
)
SELECT
    load_run_id,
    'TOTAL' AS reconciliation_level,
    MIN(reporting_month) AS reporting_month,
    NULL AS facility,
    NULL AS cost_centre_id,
    NULL AS cost_pool_code,
    NULL AS cost_category,
    SUM(gl_amount) AS gl_amount,
    SUM(direct_assigned_amount) AS direct_assigned_amount,
    SUM(indirect_allocated_amount) AS indirect_allocated_amount,
    SUM(overhead_allocated_amount) AS overhead_allocated_amount,
    SUM(unallocated_amount) AS unallocated_amount,
    SUM(excluded_amount) AS excluded_amount,
    CASE
        WHEN ABS
        (
            SUM(gl_amount)
            - SUM(direct_assigned_amount)
            - SUM(indirect_allocated_amount)
            - SUM(overhead_allocated_amount)
            - SUM(unallocated_amount)
            - SUM(excluded_amount)
        ) <= 1.00
            THEN 'PASS'
        ELSE 'REVIEW'
    END AS reconciliation_status,
    N'Total reconciliation summarised from COST_POOL reconciliation rows.'
FROM recon.costing_reconciliation
WHERE load_run_id = @load_run_id
  AND reconciliation_level = 'COST_POOL'
GROUP BY
    load_run_id;
GO


/* ============================================================
   Block 4: Reconciliation check
   ============================================================ */

DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

SELECT
    reconciliation_level,
    COUNT(*) AS row_count,
    SUM(gl_amount) AS gl_amount,
    SUM(direct_assigned_amount) AS direct_assigned_amount,
    SUM(indirect_allocated_amount) AS indirect_allocated_amount,
    SUM(overhead_allocated_amount) AS overhead_allocated_amount,
    SUM(unallocated_amount) AS unallocated_amount,
    SUM(excluded_amount) AS excluded_amount,
    SUM(reconciliation_difference) AS reconciliation_difference
FROM recon.costing_reconciliation
WHERE load_run_id = @load_run_id
GROUP BY reconciliation_level
ORDER BY reconciliation_level;

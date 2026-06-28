USE CostAnalysisABF;
GO

/* ============================================================
   06_validate_staging_data.sql

   Purpose:
   Record practical data-quality checks after landing-to-staging
   promotion.

   This script captures:
   - rows that failed promotion
   - unknown mappings
   - costing risks that need review


    dq.validation_rule
        = What should be checked?

    dq.validation_result
        = What happened when we ran the check?

    dq.issue_register
        = Which exact rows failed?
   ============================================================ */


/* ============================================================
   Block 1: Seed validation rules
   ============================================================ */

MERGE dq.validation_rule AS tgt
USING
(
    VALUES
        (
            'RU_NOT_PROMOTED',
            'resource_usage',
            'TYPE_OR_VALUE',
            N'Resource usage row did not promote to staging',
            N'Landing resource usage row was not inserted into stg.resource_usage, usually due to invalid numeric driver values or unknown encounter.',
            'HIGH',
            'Y',
            'Y'
        ),
        (
            'DC_NOT_PROMOTED',
            'direct_cost_detail',
            'REFERENCE',
            N'Direct cost row did not promote to staging',
            N'Landing direct cost row was not inserted into stg.direct_cost_detail, usually due to an unknown encounter or invalid amount/quantity.',
            'HIGH',
            'Y',
            'Y'
        ),
        (
            'GL_UNKNOWN_COST_CENTRE',
            'general_ledger_transaction',
            'MAPPING',
            N'GL transaction has unknown cost centre',
            N'Typed GL transaction has a cost centre that is not active in ref.cost_centre for the reporting month.',
            'MEDIUM',
            'N',
            'Y'
        ),
        (
            'GL_UNMAPPED_ACCOUNT',
            'general_ledger_transaction',
            'MAPPING',
            N'GL transaction has unmapped natural account',
            N'Typed GL transaction has a natural account that is not active in ref.account_mapping.',
            'MEDIUM',
            'N',
            'Y'
        ),
        (
            'ZERO_DRIVER_POOL',
            'costing',
            'ALLOCATION',
            N'Cost pool has no eligible driver units',
            N'Cost pool cannot be allocated because total eligible driver units are zero.',
            'HIGH',
            'N',
            'Y'
        )
) AS src
(
    validation_rule_id,
    source_entity,
    rule_category,
    rule_name,
    rule_description,
    severity,
    blocking_flag,
    active_flag
)
ON tgt.validation_rule_id = src.validation_rule_id
WHEN MATCHED THEN
    UPDATE SET
        source_entity = src.source_entity,
        rule_category = src.rule_category,
        rule_name = src.rule_name,
        rule_description = src.rule_description,
        severity = src.severity,
        blocking_flag = src.blocking_flag,
        active_flag = src.active_flag
WHEN NOT MATCHED THEN
    INSERT
    (
        validation_rule_id,
        source_entity,
        rule_category,
        rule_name,
        rule_description,
        severity,
        blocking_flag,
        active_flag
    )
    VALUES
    (
        src.validation_rule_id,
        src.source_entity,
        src.rule_category,
        src.rule_name,
        src.rule_description,
        src.severity,
        src.blocking_flag,
        src.active_flag
    );
GO


--SELECT
--    *
--FROM dq.validation_rule
--ORDER BY validation_rule_id;


/* ============================================================
   Block 2: Resource usage rows not promoted

    Delete old issue rows for this load/run/rule
            ↓
    Delete old validation summary for this load/run/rule
            ↓
    Recalculate current result
            ↓
    Insert fresh summary and issue rows
   ============================================================ */

DECLARE @load_run_id bigint;
DECLARE @validation_result_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';


--Unique constraint: UNIQUE (load_run_id, validation_rule_id)
DELETE ir
FROM dq.issue_register AS ir
INNER JOIN dq.validation_result AS vr
    ON vr.validation_result_id = ir.validation_result_id
WHERE vr.load_run_id = @load_run_id
  AND vr.validation_rule_id = 'RU_NOT_PROMOTED';


DELETE FROM dq.validation_result
WHERE load_run_id = @load_run_id
  AND validation_rule_id = 'RU_NOT_PROMOTED';

INSERT INTO dq.validation_result
(
    load_run_id,
    validation_rule_id,
    evaluated_row_count,
    failed_row_count,
    affected_amount,
    validation_status,
    result_message
)
SELECT
    @load_run_id,
    'RU_NOT_PROMOTED',
    COUNT(*) AS evaluated_row_count,
    SUM(CASE WHEN s.landing_row_id IS NULL THEN 1 ELSE 0 END) AS failed_row_count,
    NULL AS affected_amount,
    CASE
        WHEN SUM(CASE WHEN s.landing_row_id IS NULL THEN 1 ELSE 0 END) = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_status,
    N'Landing resource usage rows not promoted to typed staging.'
FROM landing.resource_usage AS l
LEFT JOIN stg.resource_usage AS s
    ON s.landing_row_id = l.landing_row_id
WHERE l.load_run_id = @load_run_id;

SET @validation_result_id = SCOPE_IDENTITY();

INSERT INTO dq.issue_register
(
    validation_result_id,
    source_entity,
    landing_row_id,
    source_file_name,
    source_row_number,
    business_key,
    field_name,
    invalid_value,
    financial_impact,
    issue_status,
    recommended_owner,
    recommended_action
)
SELECT
    @validation_result_id,
    'resource_usage',
    l.landing_row_id,
    l.source_file_name,
    l.source_row_number,
    l.resource_usage_id,
    'resource_usage_driver_values',
    CONCAT
    (
        'encounter_id=', COALESCE(l.encounter_id, ''),
        '; bed_days=', COALESCE(l.bed_days, ''),
        '; theatre_minutes=', COALESCE(l.theatre_minutes, ''),
        '; imaging_weighted_units=', COALESCE(l.imaging_weighted_units, ''),
        '; pathology_weighted_units=', COALESCE(l.pathology_weighted_units, ''),
        '; pharmacy_units=', COALESCE(l.pharmacy_units, ''),
        '; medical_service_units=', COALESCE(l.medical_service_units, ''),
        '; allied_health_units=', COALESCE(l.allied_health_units, '')
    ),
    NULL,
    'OPEN',
    N'Health information / costing analyst',
    N'Review invalid resource-use driver value or encounter linkage before allocation.'
FROM landing.resource_usage AS l
LEFT JOIN stg.resource_usage AS s
    ON s.landing_row_id = l.landing_row_id
WHERE l.load_run_id = @load_run_id
  AND s.landing_row_id IS NULL;
GO

SELECT
    vr.validation_rule_id,
    vr.evaluated_row_count,
    vr.failed_row_count,
    vr.validation_status,
    vr.result_message
FROM dq.validation_result AS vr
WHERE vr.validation_rule_id = 'RU_NOT_PROMOTED';

SELECT
    source_entity,
    business_key,
    field_name,
    invalid_value,
    issue_status,
    recommended_owner
FROM dq.issue_register
WHERE validation_result_id =
(
    SELECT validation_result_id
    FROM dq.validation_result
    WHERE validation_rule_id = 'RU_NOT_PROMOTED'
      AND load_run_id = (SELECT MAX(load_run_id) FROM dq.load_run)
);


/* ============================================================
   Block 3: Direct cost rows not promoted
   ============================================================ */

DECLARE @load_run_id bigint;
DECLARE @validation_result_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

DELETE ir
FROM dq.issue_register AS ir
INNER JOIN dq.validation_result AS vr
    ON vr.validation_result_id = ir.validation_result_id
WHERE vr.load_run_id = @load_run_id
  AND vr.validation_rule_id = 'DC_NOT_PROMOTED';

DELETE FROM dq.validation_result
WHERE load_run_id = @load_run_id
  AND validation_rule_id = 'DC_NOT_PROMOTED';

INSERT INTO dq.validation_result
(
    load_run_id,
    validation_rule_id,
    evaluated_row_count,
    failed_row_count,
    affected_amount,
    validation_status,
    result_message
)
SELECT
    @load_run_id,
    'DC_NOT_PROMOTED',
    COUNT(*) AS evaluated_row_count,
    SUM(CASE WHEN s.landing_row_id IS NULL THEN 1 ELSE 0 END) AS failed_row_count,
    SUM
    (
        CASE
            WHEN s.landing_row_id IS NULL
                THEN TRY_CONVERT(decimal(19,6), l.amount)
            ELSE 0
        END
    ) AS affected_amount,
    CASE
        WHEN SUM(CASE WHEN s.landing_row_id IS NULL THEN 1 ELSE 0 END) = 0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS validation_status,
    N'Landing direct cost rows not promoted to typed staging.'
FROM landing.direct_cost_detail AS l
LEFT JOIN stg.direct_cost_detail AS s
    ON s.landing_row_id = l.landing_row_id
WHERE l.load_run_id = @load_run_id;

SET @validation_result_id = SCOPE_IDENTITY();

INSERT INTO dq.issue_register
(
    validation_result_id,
    source_entity,
    landing_row_id,
    source_file_name,
    source_row_number,
    business_key,
    field_name,
    invalid_value,
    financial_impact,
    issue_status,
    recommended_owner,
    recommended_action
)
SELECT
    @validation_result_id,
    'direct_cost_detail',
    l.landing_row_id,
    l.source_file_name,
    l.source_row_number,
    l.direct_cost_id,
    'encounter_id',
    CONCAT
    (
        'encounter_id=', COALESCE(l.encounter_id, ''),
        '; service_month=', COALESCE(l.service_month, ''),
        '; cost_centre_id=', COALESCE(l.cost_centre_id, ''),
        '; natural_account=', COALESCE(l.natural_account, ''),
        '; quantity=', COALESCE(l.quantity, ''),
        '; amount=', COALESCE(l.amount, '')
    ),
    TRY_CONVERT(decimal(19,6), l.amount),
    'OPEN',
    N'Costing analyst / finance',
    N'Review direct cost encounter linkage. If encounter cannot be resolved, retain as unallocated cost.'
FROM landing.direct_cost_detail AS l
LEFT JOIN stg.direct_cost_detail AS s
    ON s.landing_row_id = l.landing_row_id
WHERE l.load_run_id = @load_run_id
  AND s.landing_row_id IS NULL;
GO


--SELECT
--    vr.validation_rule_id,
--    vr.evaluated_row_count,
--    vr.failed_row_count,
--    vr.affected_amount,
--    vr.validation_status,
--    vr.result_message
--FROM dq.validation_result AS vr
--WHERE vr.validation_rule_id = 'DC_NOT_PROMOTED';

--SELECT
--    source_entity,
--    business_key,
--    field_name,
--    invalid_value,
--    financial_impact,
--    issue_status,
--    recommended_owner
--FROM dq.issue_register
--WHERE validation_result_id =
--(
--    SELECT validation_result_id
--    FROM dq.validation_result
--    WHERE validation_rule_id = 'DC_NOT_PROMOTED'
--      AND load_run_id = (SELECT MAX(load_run_id) FROM dq.load_run)
--);


/* ============================================================
   Block 4: GL transactions with unknown cost centre
   ============================================================ */

DECLARE @load_run_id bigint;
DECLARE @validation_result_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

DELETE ir
FROM dq.issue_register AS ir
INNER JOIN dq.validation_result AS vr
    ON vr.validation_result_id = ir.validation_result_id
WHERE vr.load_run_id = @load_run_id
  AND vr.validation_rule_id = 'GL_UNKNOWN_COST_CENTRE';

DELETE FROM dq.validation_result
WHERE load_run_id = @load_run_id
  AND validation_rule_id = 'GL_UNKNOWN_COST_CENTRE';

INSERT INTO dq.validation_result
(
    load_run_id,
    validation_rule_id,
    evaluated_row_count,
    failed_row_count,
    affected_amount,
    validation_status,
    result_message
)
SELECT
    @load_run_id,
    'GL_UNKNOWN_COST_CENTRE',
    COUNT(*) AS evaluated_row_count,
    SUM(CASE WHEN cc.cost_centre_id IS NULL THEN 1 ELSE 0 END) AS failed_row_count,
    SUM
    (
        CASE
            WHEN cc.cost_centre_id IS NULL THEN gl.signed_amount
            ELSE 0
        END
    ) AS affected_amount,
    CASE
        WHEN SUM(CASE WHEN cc.cost_centre_id IS NULL THEN 1 ELSE 0 END) = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END AS validation_status,
    N'Typed GL transactions with cost centres not active in governed reference data.'
FROM stg.general_ledger_transaction AS gl
LEFT JOIN ref.cost_centre AS cc
    ON cc.cost_centre_id = gl.cost_centre_id
   AND cc.active_flag = 'Y'
   AND gl.reporting_month >= cc.effective_from
   AND gl.reporting_month <= cc.effective_to
WHERE gl.load_run_id = @load_run_id;

SET @validation_result_id = SCOPE_IDENTITY();

INSERT INTO dq.issue_register
(
    validation_result_id,
    source_entity,
    landing_row_id,
    source_file_name,
    source_row_number,
    business_key,
    field_name,
    invalid_value,
    financial_impact,
    issue_status,
    recommended_owner,
    recommended_action
)
SELECT
    @validation_result_id,
    'general_ledger_transaction',
    gl.landing_row_id,
    l.source_file_name,
    l.source_row_number,
    gl.gl_transaction_id,
    'cost_centre_id',
    gl.cost_centre_id,
    gl.signed_amount,
    'OPEN',
    N'Finance / costing analyst',
    N'Review cost-centre mapping. Until resolved, retain amount as unallocated/review.'
FROM stg.general_ledger_transaction AS gl
INNER JOIN landing.general_ledger_transaction AS l
    ON l.landing_row_id = gl.landing_row_id
LEFT JOIN ref.cost_centre AS cc
    ON cc.cost_centre_id = gl.cost_centre_id
   AND cc.active_flag = 'Y'
   AND gl.reporting_month >= cc.effective_from
   AND gl.reporting_month <= cc.effective_to
WHERE gl.load_run_id = @load_run_id
  AND cc.cost_centre_id IS NULL;
GO



SELECT
    validation_rule_id,
    evaluated_row_count,
    failed_row_count,
    affected_amount,
    validation_status,
    result_message
FROM dq.validation_result
WHERE validation_rule_id = 'GL_UNKNOWN_COST_CENTRE';

SELECT
    source_entity,
    business_key,
    field_name,
    invalid_value,
    financial_impact,
    issue_status,
    recommended_owner
FROM dq.issue_register
WHERE validation_result_id =
(
    SELECT validation_result_id
    FROM dq.validation_result
    WHERE validation_rule_id = 'GL_UNKNOWN_COST_CENTRE'
      AND load_run_id = (SELECT MAX(load_run_id) FROM dq.load_run)
);



/* ============================================================
   Block 5: GL transactions with unmapped natural account
   ============================================================ */

DECLARE @load_run_id bigint;
DECLARE @validation_result_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

DELETE ir
FROM dq.issue_register AS ir
INNER JOIN dq.validation_result AS vr
    ON vr.validation_result_id = ir.validation_result_id
WHERE vr.load_run_id = @load_run_id
  AND vr.validation_rule_id = 'GL_UNMAPPED_ACCOUNT';

DELETE FROM dq.validation_result
WHERE load_run_id = @load_run_id
  AND validation_rule_id = 'GL_UNMAPPED_ACCOUNT';

INSERT INTO dq.validation_result
(
    load_run_id,
    validation_rule_id,
    evaluated_row_count,
    failed_row_count,
    affected_amount,
    validation_status,
    result_message
)
SELECT
    @load_run_id,
    'GL_UNMAPPED_ACCOUNT',
    COUNT(*) AS evaluated_row_count,
    SUM(CASE WHEN am.natural_account IS NULL THEN 1 ELSE 0 END) AS failed_row_count,
    SUM
    (
        CASE
            WHEN am.natural_account IS NULL THEN gl.signed_amount
            ELSE 0
        END
    ) AS affected_amount,
    CASE
        WHEN SUM(CASE WHEN am.natural_account IS NULL THEN 1 ELSE 0 END) = 0
            THEN 'PASS'
        ELSE 'REVIEW'
    END AS validation_status,
    N'Typed GL transactions with natural accounts not active in governed account mapping.'
FROM stg.general_ledger_transaction AS gl
LEFT JOIN ref.account_mapping AS am
    ON am.natural_account = gl.natural_account
   AND am.active_flag = 'Y'
WHERE gl.load_run_id = @load_run_id;

SET @validation_result_id = SCOPE_IDENTITY();

INSERT INTO dq.issue_register
(
    validation_result_id,
    source_entity,
    landing_row_id,
    source_file_name,
    source_row_number,
    business_key,
    field_name,
    invalid_value,
    financial_impact,
    issue_status,
    recommended_owner,
    recommended_action
)
SELECT
    @validation_result_id,
    'general_ledger_transaction',
    gl.landing_row_id,
    l.source_file_name,
    l.source_row_number,
    gl.gl_transaction_id,
    'natural_account',
    gl.natural_account,
    gl.signed_amount,
    'OPEN',
    N'Finance / costing analyst',
    N'Review account mapping. Until resolved, retain amount as unallocated/review.'
FROM stg.general_ledger_transaction AS gl
INNER JOIN landing.general_ledger_transaction AS l
    ON l.landing_row_id = gl.landing_row_id
LEFT JOIN ref.account_mapping AS am
    ON am.natural_account = gl.natural_account
   AND am.active_flag = 'Y'
WHERE gl.load_run_id = @load_run_id
  AND am.natural_account IS NULL;
GO


--SELECT
--    validation_rule_id,
--    evaluated_row_count,
--    failed_row_count,
--    affected_amount,
--    validation_status,
--    result_message
--FROM dq.validation_result
--WHERE validation_rule_id = 'GL_UNMAPPED_ACCOUNT';

--SELECT
--    source_entity,
--    business_key,
--    field_name,
--    invalid_value,
--    financial_impact,
--    issue_status,
--    recommended_owner
--FROM dq.issue_register
--WHERE validation_result_id =
--(
--    SELECT validation_result_id
--    FROM dq.validation_result
--    WHERE validation_rule_id = 'GL_UNMAPPED_ACCOUNT'
--      AND load_run_id = (SELECT MAX(load_run_id) FROM dq.load_run)
--);






--DECLARE @load_run_id bigint;

--SELECT @load_run_id = MAX(load_run_id)
--FROM dq.load_run
--WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
--  AND load_status = 'COMPLETED';

--SELECT
--    vr.validation_rule_id,
--    r.rule_name,
--    r.severity,
--    r.blocking_flag,
--    vr.evaluated_row_count,
--    vr.failed_row_count,
--    vr.affected_amount,
--    vr.validation_status
--FROM dq.validation_result AS vr
--INNER JOIN dq.validation_rule AS r
--    ON r.validation_rule_id = vr.validation_rule_id
--WHERE vr.load_run_id = @load_run_id
--ORDER BY vr.validation_rule_id;

--SELECT
--    source_entity,
--    field_name,
--    COUNT(*) AS issue_count,
--    SUM(COALESCE(financial_impact, 0)) AS financial_impact
--FROM dq.issue_register AS ir
--INNER JOIN dq.validation_result AS vr
--    ON vr.validation_result_id = ir.validation_result_id
--WHERE vr.load_run_id = @load_run_id
--GROUP BY
--    source_entity,
--    field_name
--ORDER BY
--    source_entity,
--    field_name;



/* ============================================================
   Block 6: Zero-driver cost pools
   ============================================================ */

DECLARE @load_run_id bigint;
DECLARE @validation_result_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

DELETE ir
FROM dq.issue_register AS ir
INNER JOIN dq.validation_result AS vr
    ON vr.validation_result_id = ir.validation_result_id
WHERE vr.load_run_id = @load_run_id
  AND vr.validation_rule_id = 'ZERO_DRIVER_POOL';

DELETE FROM dq.validation_result
WHERE load_run_id = @load_run_id
  AND validation_rule_id = 'ZERO_DRIVER_POOL';

WITH driver_total AS
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
),
zero_driver_pool AS
(
    SELECT
        cp.cost_pool_id,
        cp.load_run_id,
        cp.reporting_month,
        cp.facility,
        cp.cost_centre_id,
        cp.natural_account,
        cp.cost_pool_code,
        cp.cost_category,
        cp.allocation_driver,
        cp.source_gl_amount,
        COALESCE(dt.total_valid_driver_units, 0) AS total_valid_driver_units
    FROM costing.cost_pool AS cp
    LEFT JOIN driver_total AS dt
        ON dt.load_run_id = cp.load_run_id
       AND dt.reporting_month = cp.reporting_month
       AND dt.cost_pool_code = cp.cost_pool_code
       AND dt.allocation_driver = cp.allocation_driver
    WHERE cp.load_run_id = @load_run_id
      AND cp.pool_status = 'READY'
      AND cp.costing_treatment = 'Indirect'    -- costs that need allocation by a driver, pre_overhead_cost does not exist yet
      AND cp.source_gl_amount <> 0
      AND COALESCE(dt.total_valid_driver_units, 0) = 0
)
INSERT INTO dq.validation_result
(
    load_run_id,
    validation_rule_id,
    evaluated_row_count,
    failed_row_count,
    affected_amount,
    validation_status,
    result_message
)
SELECT
    @load_run_id,
    'ZERO_DRIVER_POOL',
    (
        SELECT COUNT(*)
        FROM costing.cost_pool
        WHERE load_run_id = @load_run_id
          AND pool_status = 'READY'
          AND costing_treatment = 'Indirect'  -- costs that need allocation by a driver, pre_overhead_cost does not exist yet 
    ) AS evaluated_row_count,
    COUNT(*) AS failed_row_count,
    COALESCE(SUM(source_gl_amount), 0) AS affected_amount,
    CASE
        WHEN COUNT(*) = 0 THEN 'PASS'
        ELSE 'REVIEW'
    END AS validation_status,
    N'Cost pools with GL amount but no valid eligible driver units.'
FROM zero_driver_pool;

SET @validation_result_id = SCOPE_IDENTITY();

WITH driver_total AS
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
),
zero_driver_pool AS
(
    SELECT
        cp.cost_pool_id,
        cp.load_run_id,
        cp.reporting_month,
        cp.facility,
        cp.cost_centre_id,
        cp.natural_account,
        cp.cost_pool_code,
        cp.cost_category,
        cp.allocation_driver,
        cp.source_gl_amount,
        COALESCE(dt.total_valid_driver_units, 0) AS total_valid_driver_units
    FROM costing.cost_pool AS cp
    LEFT JOIN driver_total AS dt
        ON dt.load_run_id = cp.load_run_id
       AND dt.reporting_month = cp.reporting_month
       AND dt.cost_pool_code = cp.cost_pool_code
       AND dt.allocation_driver = cp.allocation_driver
    WHERE cp.load_run_id = @load_run_id
      AND cp.pool_status = 'READY'
      AND cp.costing_treatment = 'Indirect' -- costs that need allocation by a driver, pre_overhead_cost does not exist yet
      AND cp.source_gl_amount <> 0
      AND COALESCE(dt.total_valid_driver_units, 0) = 0
)
INSERT INTO dq.issue_register
(
    validation_result_id,
    source_entity,
    landing_row_id,
    source_file_name,
    source_row_number,
    business_key,
    field_name,
    invalid_value,
    financial_impact,
    issue_status,
    recommended_owner,
    recommended_action
)
SELECT
    @validation_result_id,
    'costing.cost_pool',
    NULL,
    N'costing.cost_pool',
    NULL,
    CONVERT(nvarchar(200), cost_pool_id),
    'allocation_driver',
    CONCAT
    (
        'reporting_month=', CONVERT(varchar(10), reporting_month, 120),
        '; cost_pool_code=', cost_pool_code,
        '; allocation_driver=', allocation_driver,
        '; total_valid_driver_units=', CONVERT(varchar(50), total_valid_driver_units)
    ),
    source_gl_amount,
    'OPEN',
    N'Costing analyst',
    N'Retain this pool as unallocated/review unless an eligible driver population is approved.'
FROM zero_driver_pool;
GO




SELECT
    validation_rule_id,
    evaluated_row_count,
    failed_row_count,
    affected_amount,
    validation_status,
    result_message
FROM dq.validation_result
WHERE validation_rule_id = 'ZERO_DRIVER_POOL';

SELECT
    source_entity,
    business_key,
    field_name,
    invalid_value,
    financial_impact,
    issue_status,
    recommended_owner
FROM dq.issue_register
WHERE validation_result_id =
(
    SELECT validation_result_id
    FROM dq.validation_result
    WHERE validation_rule_id = 'ZERO_DRIVER_POOL'
      AND load_run_id = (SELECT MAX(load_run_id) FROM dq.load_run)
);
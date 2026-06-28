USE CostAnalysisABF;
GO

/* ============================================================
   05_promote_landing_to_staging.sql

   Purpose:
   Promote valid nullable-text landing rows into typed staging tables.

   Pattern:
   landing text values
       -> TRY_CONVERT / reference checks
       -> typed stg table

   Failed rows are not inserted into staging.
   They should be captured in dq.issue_register in the validation step.
   ============================================================ */


/* ============================================================
   Promote patient encounters
   ============================================================ */

DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

;WITH candidate AS
(
    SELECT
        l.landing_row_id,
        l.load_run_id,

        CAST(LTRIM(RTRIM(l.encounter_id)) AS varchar(20)) AS encounter_id,
        CAST(LTRIM(RTRIM(l.patient_id)) AS varchar(20)) AS patient_id,
        CAST(LTRIM(RTRIM(l.facility)) AS nvarchar(100)) AS facility,
        CAST(LTRIM(RTRIM(l.service_line)) AS nvarchar(100)) AS service_line,
        CAST(LTRIM(RTRIM(l.care_type)) AS varchar(30)) AS care_type,

        TRY_CONVERT(date, l.admission_date) AS admission_date,
        TRY_CONVERT(date, l.discharge_date) AS discharge_date,
        TRY_CONVERT(date, l.episode_month) AS episode_month,

        CAST(LTRIM(RTRIM(l.activity_group_code)) AS varchar(30)) AS activity_group_code,
        TRY_CONVERT(smallint, l.length_of_stay) AS length_of_stay,
        CAST(LTRIM(RTRIM(l.separation_status)) AS varchar(30)) AS separation_status,
        TRY_CONVERT(smallint, l.age_years) AS age_years,
        CAST(LTRIM(RTRIM(l.indigenous_status)) AS char(1)) AS indigenous_status,
        CAST(LTRIM(RTRIM(l.remoteness_area)) AS varchar(50)) AS remoteness_area,
        CAST(LTRIM(RTRIM(l.high_complexity_flag)) AS char(1)) AS high_complexity_flag,
        CAST(LTRIM(RTRIM(l.hospital_acquired_complication_flag)) AS char(1)) AS hospital_acquired_complication_flag
    FROM landing.patient_encounter AS l
    WHERE l.load_run_id = @load_run_id
)
INSERT INTO stg.patient_encounter
(
    landing_row_id,
    load_run_id,
    encounter_id,
    patient_id,
    facility,
    service_line,
    care_type,
    admission_date,
    discharge_date,
    episode_month,
    activity_group_code,
    length_of_stay,
    separation_status,
    age_years,
    indigenous_status,
    remoteness_area,
    high_complexity_flag,
    hospital_acquired_complication_flag
)
SELECT
    c.landing_row_id,
    c.load_run_id,
    c.encounter_id,
    c.patient_id,
    c.facility,
    c.service_line,
    c.care_type,
    c.admission_date,
    c.discharge_date,
    c.episode_month,
    c.activity_group_code,
    c.length_of_stay,
    c.separation_status,
    c.age_years,
    c.indigenous_status,
    c.remoteness_area,
    c.high_complexity_flag,
    c.hospital_acquired_complication_flag
FROM candidate AS c
INNER JOIN ref.service_line AS sl
    ON sl.service_line = c.service_line
INNER JOIN ref.care_type AS ct
    ON ct.care_type = c.care_type
INNER JOIN ref.activity_group AS ag
    ON ag.activity_group_code = c.activity_group_code
WHERE c.encounter_id IS NOT NULL
  AND c.patient_id IS NOT NULL
  AND c.facility IS NOT NULL
  AND c.service_line IS NOT NULL
  AND c.care_type IS NOT NULL
  AND c.admission_date IS NOT NULL
  AND c.discharge_date IS NOT NULL
  AND c.episode_month IS NOT NULL
  AND c.activity_group_code IS NOT NULL
  AND c.length_of_stay IS NOT NULL
  AND c.separation_status IS NOT NULL
  AND c.age_years IS NOT NULL
  AND c.indigenous_status IS NOT NULL
  AND c.remoteness_area IS NOT NULL
  AND c.high_complexity_flag IS NOT NULL
  AND c.hospital_acquired_complication_flag IS NOT NULL
  AND c.discharge_date >= c.admission_date
  AND NOT EXISTS
  (
      SELECT 1
      FROM stg.patient_encounter AS existing
      WHERE existing.landing_row_id = c.landing_row_id
  );
GO


--DECLARE @load_run_id bigint;

--SELECT @load_run_id = MAX(load_run_id)
--FROM dq.load_run
--WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
--  AND load_status = 'COMPLETED';

--SELECT
--    'landing.patient_encounter' AS table_name,
--    COUNT(*) AS row_count
--FROM landing.patient_encounter
--WHERE load_run_id = @load_run_id

--UNION ALL

--SELECT
--    'stg.patient_encounter',
--    COUNT(*)
--FROM stg.patient_encounter
--WHERE load_run_id = @load_run_id;


/* ============================================================
   Promote resource usage
   ============================================================ */

DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

;WITH candidate AS
(
    SELECT
        l.landing_row_id,
        l.load_run_id,

        CAST(LTRIM(RTRIM(l.resource_usage_id)) AS varchar(20)) AS resource_usage_id,
        CAST(LTRIM(RTRIM(l.encounter_id)) AS varchar(20)) AS encounter_id,
        TRY_CONVERT(date, l.service_month) AS service_month,

        TRY_CONVERT(int, l.bed_days) AS bed_days,
        TRY_CONVERT(int, l.theatre_minutes) AS theatre_minutes,
        TRY_CONVERT(int, l.imaging_weighted_units) AS imaging_weighted_units,
        TRY_CONVERT(int, l.pathology_weighted_units) AS pathology_weighted_units,
        TRY_CONVERT(int, l.pharmacy_units) AS pharmacy_units,
        TRY_CONVERT(int, l.medical_service_units) AS medical_service_units,
        TRY_CONVERT(int, l.allied_health_units) AS allied_health_units
    FROM landing.resource_usage AS l
    WHERE l.load_run_id = @load_run_id
)
INSERT INTO stg.resource_usage
(
    landing_row_id,
    load_run_id,
    resource_usage_id,
    encounter_id,
    service_month,
    bed_days,
    theatre_minutes,
    imaging_weighted_units,
    pathology_weighted_units,
    pharmacy_units,
    medical_service_units,
    allied_health_units
)
SELECT
    c.landing_row_id,
    c.load_run_id,
    c.resource_usage_id,
    c.encounter_id,
    c.service_month,
    c.bed_days,
    c.theatre_minutes,
    c.imaging_weighted_units,
    c.pathology_weighted_units,
    c.pharmacy_units,
    c.medical_service_units,
    c.allied_health_units
FROM candidate AS c
INNER JOIN stg.patient_encounter AS pe
    ON pe.load_run_id = c.load_run_id
   AND pe.encounter_id = c.encounter_id
WHERE c.resource_usage_id IS NOT NULL
  AND c.encounter_id IS NOT NULL
  AND c.service_month IS NOT NULL
  AND c.bed_days IS NOT NULL
  AND c.theatre_minutes IS NOT NULL
  AND c.imaging_weighted_units IS NOT NULL
  AND c.pathology_weighted_units IS NOT NULL
  AND c.pharmacy_units IS NOT NULL
  AND c.medical_service_units IS NOT NULL
  AND c.allied_health_units IS NOT NULL
  AND c.bed_days >= 0
  AND c.theatre_minutes >= 0
  AND c.imaging_weighted_units >= 0
  AND c.pathology_weighted_units >= 0
  AND c.pharmacy_units >= 0
  AND c.medical_service_units >= 0
  AND c.allied_health_units >= 0
  AND NOT EXISTS
  (
      SELECT 1
      FROM stg.resource_usage AS existing
      WHERE existing.landing_row_id = c.landing_row_id
  );
GO


--DECLARE @load_run_id bigint;

--SELECT @load_run_id = MAX(load_run_id)
--FROM dq.load_run
--WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
--  AND load_status = 'COMPLETED';

--SELECT
--    'landing.resource_usage' AS table_name,
--    COUNT(*) AS row_count
--FROM landing.resource_usage
--WHERE load_run_id = @load_run_id

--UNION ALL

--SELECT
--    'stg.resource_usage',
--    COUNT(*)
--FROM stg.resource_usage
--WHERE load_run_id = @load_run_id;


/* ============================================================
   Promote direct cost detail
   ============================================================ */

DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

;WITH candidate AS
(
    SELECT
        l.landing_row_id,
        l.load_run_id,

        CAST(LTRIM(RTRIM(l.direct_cost_id)) AS varchar(20)) AS direct_cost_id,
        CAST(LTRIM(RTRIM(l.encounter_id)) AS varchar(20)) AS encounter_id,
        TRY_CONVERT(date, l.service_month) AS service_month,
        CAST(LTRIM(RTRIM(l.cost_centre_id)) AS varchar(30)) AS cost_centre_id,
        CAST(LTRIM(RTRIM(l.natural_account)) AS varchar(20)) AS natural_account,
        CAST(LTRIM(RTRIM(l.direct_cost_type)) AS nvarchar(100)) AS direct_cost_type,
        TRY_CONVERT(int, l.quantity) AS quantity,
        TRY_CONVERT(decimal(19,6), l.amount) AS amount
    FROM landing.direct_cost_detail AS l
    WHERE l.load_run_id = @load_run_id
)
INSERT INTO stg.direct_cost_detail
(
    landing_row_id,
    load_run_id,
    direct_cost_id,
    encounter_id,
    service_month,
    cost_centre_id,
    natural_account,
    direct_cost_type,
    quantity,
    amount
)
SELECT
    c.landing_row_id,
    c.load_run_id,
    c.direct_cost_id,
    c.encounter_id,
    c.service_month,
    c.cost_centre_id,
    c.natural_account,
    c.direct_cost_type,
    c.quantity,
    c.amount
FROM candidate AS c
INNER JOIN stg.patient_encounter AS pe
    ON pe.load_run_id = c.load_run_id
   AND pe.encounter_id = c.encounter_id
WHERE c.direct_cost_id IS NOT NULL
  AND c.encounter_id IS NOT NULL
  AND c.service_month IS NOT NULL
  AND c.cost_centre_id IS NOT NULL
  AND c.natural_account IS NOT NULL
  AND c.direct_cost_type IS NOT NULL
  AND c.quantity IS NOT NULL
  AND c.amount IS NOT NULL
  AND c.quantity >= 0
  AND NOT EXISTS
  (
      SELECT 1
      FROM stg.direct_cost_detail AS existing
      WHERE existing.landing_row_id = c.landing_row_id
  );
GO


--DECLARE @load_run_id bigint;

--SELECT @load_run_id = MAX(load_run_id)
--FROM dq.load_run
--WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
--  AND load_status = 'COMPLETED';

--SELECT
--    'landing.direct_cost_detail' AS table_name,
--    COUNT(*) AS row_count
--FROM landing.direct_cost_detail
--WHERE load_run_id = @load_run_id

--UNION ALL

--SELECT
--    'stg.direct_cost_detail',
--    COUNT(*)
--FROM stg.direct_cost_detail
--WHERE load_run_id = @load_run_id;


/* ============================================================
   Promote general ledger transactions
   ============================================================ */

DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

;WITH candidate AS
(
    SELECT
        l.landing_row_id,
        l.load_run_id,

        CAST(LTRIM(RTRIM(l.gl_transaction_id)) AS varchar(20)) AS gl_transaction_id,
        TRY_CONVERT(date, l.reporting_month) AS reporting_month,
        CAST(LTRIM(RTRIM(l.entity)) AS nvarchar(100)) AS entity,
        CAST(LTRIM(RTRIM(l.facility)) AS nvarchar(100)) AS facility,
        CAST(LTRIM(RTRIM(l.cost_centre_id)) AS varchar(30)) AS cost_centre_id,
        CAST(LTRIM(RTRIM(l.natural_account)) AS varchar(20)) AS natural_account,
        CAST(LTRIM(RTRIM(l.account_description)) AS nvarchar(200)) AS account_description,
        TRY_CONVERT(decimal(19,6), l.signed_amount) AS signed_amount,
        CAST(LTRIM(RTRIM(l.adjustment_type)) AS varchar(30)) AS adjustment_type,
        CAST(LTRIM(RTRIM(l.source_reference)) AS nvarchar(200)) AS source_reference
    FROM landing.general_ledger_transaction AS l
    WHERE l.load_run_id = @load_run_id
)
INSERT INTO stg.general_ledger_transaction
(
    landing_row_id,
    load_run_id,
    gl_transaction_id,
    reporting_month,
    entity,
    facility,
    cost_centre_id,
    natural_account,
    account_description,
    signed_amount,
    adjustment_type,
    source_reference
)
SELECT
    c.landing_row_id,
    c.load_run_id,
    c.gl_transaction_id,
    c.reporting_month,
    c.entity,
    c.facility,
    c.cost_centre_id,
    c.natural_account,
    c.account_description,
    c.signed_amount,
    c.adjustment_type,
    c.source_reference
FROM candidate AS c
WHERE c.gl_transaction_id IS NOT NULL
  AND c.reporting_month IS NOT NULL
  AND c.entity IS NOT NULL
  AND c.facility IS NOT NULL
  AND c.cost_centre_id IS NOT NULL
  AND c.natural_account IS NOT NULL
  AND c.account_description IS NOT NULL
  AND c.signed_amount IS NOT NULL
  AND c.adjustment_type IS NOT NULL
  AND c.source_reference IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM stg.general_ledger_transaction AS existing
      WHERE existing.landing_row_id = c.landing_row_id
  );
GO




--DECLARE @load_run_id bigint;

--SELECT @load_run_id = MAX(load_run_id)
--FROM dq.load_run
--WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
--  AND load_status = 'COMPLETED';

--SELECT
--    'landing.general_ledger_transaction' AS table_name,
--    COUNT(*) AS row_count
--FROM landing.general_ledger_transaction
--WHERE load_run_id = @load_run_id

--UNION ALL

--SELECT
--    'stg.general_ledger_transaction',
--    COUNT(*)
--FROM stg.general_ledger_transaction
--WHERE load_run_id = @load_run_id;


DECLARE @load_run_id bigint;

SELECT @load_run_id = MAX(load_run_id)
FROM dq.load_run
WHERE load_name = 'LOAD_RAW_CSV_TO_LANDING'
  AND load_status = 'COMPLETED';

SELECT
    'patient_encounter' AS source_entity,
    (SELECT COUNT(*) FROM landing.patient_encounter WHERE load_run_id = @load_run_id) AS landing_count,
    (SELECT COUNT(*) FROM stg.patient_encounter WHERE load_run_id = @load_run_id) AS staged_count,
    (SELECT COUNT(*) FROM landing.patient_encounter WHERE load_run_id = @load_run_id)
    - (SELECT COUNT(*) FROM stg.patient_encounter WHERE load_run_id = @load_run_id) AS not_staged_count

UNION ALL

SELECT
    'resource_usage',
    (SELECT COUNT(*) FROM landing.resource_usage WHERE load_run_id = @load_run_id),
    (SELECT COUNT(*) FROM stg.resource_usage WHERE load_run_id = @load_run_id),
    (SELECT COUNT(*) FROM landing.resource_usage WHERE load_run_id = @load_run_id)
    - (SELECT COUNT(*) FROM stg.resource_usage WHERE load_run_id = @load_run_id)

UNION ALL

SELECT
    'direct_cost_detail',
    (SELECT COUNT(*) FROM landing.direct_cost_detail WHERE load_run_id = @load_run_id),
    (SELECT COUNT(*) FROM stg.direct_cost_detail WHERE load_run_id = @load_run_id),
    (SELECT COUNT(*) FROM landing.direct_cost_detail WHERE load_run_id = @load_run_id)
    - (SELECT COUNT(*) FROM stg.direct_cost_detail WHERE load_run_id = @load_run_id)

UNION ALL

SELECT
    'general_ledger_transaction',
    (SELECT COUNT(*) FROM landing.general_ledger_transaction WHERE load_run_id = @load_run_id),
    (SELECT COUNT(*) FROM stg.general_ledger_transaction WHERE load_run_id = @load_run_id),
    (SELECT COUNT(*) FROM landing.general_ledger_transaction WHERE load_run_id = @load_run_id)
    - (SELECT COUNT(*) FROM stg.general_ledger_transaction WHERE load_run_id = @load_run_id);
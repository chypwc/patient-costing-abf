USE CostAnalysisABF;
GO

DECLARE @SourceRoot nvarchar(1000) = N'C:\SQLData\cost_analysis_abf\raw';
DECLARE @load_run_id bigint;

INSERT INTO dq.load_run
(
    load_name,
    financial_year,
    source_root_path,
    load_status
)
VALUES
(
    'LOAD_RAW_CSV_TO_LANDING',
    '2024-25',
    @SourceRoot,
    'STARTED'
);

SET @load_run_id = SCOPE_IDENTITY();

BEGIN TRY

    /* ============================================================
       1. Temporary raw-shape tables
       ============================================================ */

    CREATE TABLE #patient_encounter_file
    (
        encounter_id nvarchar(4000) NULL,
        patient_id nvarchar(4000) NULL,
        facility nvarchar(4000) NULL,
        service_line nvarchar(4000) NULL,
        care_type nvarchar(4000) NULL,
        admission_date nvarchar(4000) NULL,
        discharge_date nvarchar(4000) NULL,
        episode_month nvarchar(4000) NULL,
        activity_group_code nvarchar(4000) NULL,
        length_of_stay nvarchar(4000) NULL,
        separation_status nvarchar(4000) NULL,
        age_years nvarchar(4000) NULL,
        indigenous_status nvarchar(4000) NULL,
        remoteness_area nvarchar(4000) NULL,
        high_complexity_flag nvarchar(4000) NULL,
        hospital_acquired_complication_flag nvarchar(4000) NULL
    );

    CREATE TABLE #resource_usage_file
    (
        resource_usage_id nvarchar(4000) NULL,
        encounter_id nvarchar(4000) NULL,
        service_month nvarchar(4000) NULL,
        bed_days nvarchar(4000) NULL,
        theatre_minutes nvarchar(4000) NULL,
        imaging_weighted_units nvarchar(4000) NULL,
        pathology_weighted_units nvarchar(4000) NULL,
        pharmacy_units nvarchar(4000) NULL,
        medical_service_units nvarchar(4000) NULL,
        allied_health_units nvarchar(4000) NULL
    );

    CREATE TABLE #direct_cost_detail_file
    (
        direct_cost_id nvarchar(4000) NULL,
        encounter_id nvarchar(4000) NULL,
        service_month nvarchar(4000) NULL,
        cost_centre_id nvarchar(4000) NULL,
        natural_account nvarchar(4000) NULL,
        direct_cost_type nvarchar(4000) NULL,
        quantity nvarchar(4000) NULL,
        amount nvarchar(4000) NULL
    );

    CREATE TABLE #general_ledger_transaction_file
    (
        gl_transaction_id nvarchar(4000) NULL,
        reporting_month nvarchar(4000) NULL,
        entity nvarchar(4000) NULL,
        facility nvarchar(4000) NULL,
        cost_centre_id nvarchar(4000) NULL,
        natural_account nvarchar(4000) NULL,
        account_description nvarchar(4000) NULL,
        signed_amount nvarchar(4000) NULL,
        adjustment_type nvarchar(4000) NULL,
        source_reference nvarchar(4000) NULL
    );

    /* ============================================================
       2. Bulk load CSVs into temporary tables
       ============================================================ */

    DECLARE @sql nvarchar(max);

    SET @sql = N'
        BULK INSERT #patient_encounter_file
        FROM ''' + REPLACE(@SourceRoot + N'\patient_encounter.csv', '''', '''''') + N'''
        WITH
        (
            FORMAT = ''CSV'',
            FIRSTROW = 2,
            FIELDQUOTE = ''"'',
            CODEPAGE = ''65001'',
            TABLOCK
        );';
    EXEC sys.sp_executesql @sql;

    SET @sql = N'
        BULK INSERT #resource_usage_file
        FROM ''' + REPLACE(@SourceRoot + N'\resource_usage.csv', '''', '''''') + N'''
        WITH
        (
            FORMAT = ''CSV'',
            FIRSTROW = 2,
            FIELDQUOTE = ''"'',
            CODEPAGE = ''65001'',
            TABLOCK
        );';
    EXEC sys.sp_executesql @sql;

    SET @sql = N'
        BULK INSERT #direct_cost_detail_file
        FROM ''' + REPLACE(@SourceRoot + N'\direct_cost_detail.csv', '''', '''''') + N'''
        WITH
        (
            FORMAT = ''CSV'',
            FIRSTROW = 2,
            FIELDQUOTE = ''"'',
            CODEPAGE = ''65001'',
            TABLOCK
        );';
    EXEC sys.sp_executesql @sql;

    SET @sql = N'
        BULK INSERT #general_ledger_transaction_file
        FROM ''' + REPLACE(@SourceRoot + N'\general_ledger_transaction.csv', '''', '''''') + N'''
        WITH
        (
            FORMAT = ''CSV'',
            FIRSTROW = 2,
            FIELDQUOTE = ''"'',
            CODEPAGE = ''65001'',
            TABLOCK
        );';
    EXEC sys.sp_executesql @sql;

    /* ============================================================
       3. Insert into landing tables with lineage
       ============================================================ */

    INSERT INTO landing.patient_encounter
    (
        load_run_id,
        source_file_name,
        source_row_number,
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
        @load_run_id,
        N'patient_encounter.csv',
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 1,
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
    FROM #patient_encounter_file;

    INSERT INTO landing.resource_usage
    (
        load_run_id,
        source_file_name,
        source_row_number,
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
        @load_run_id,
        N'resource_usage.csv',
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 1,
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
    FROM #resource_usage_file;

    INSERT INTO landing.direct_cost_detail
    (
        load_run_id,
        source_file_name,
        source_row_number,
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
        @load_run_id,
        N'direct_cost_detail.csv',
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 1,
        direct_cost_id,
        encounter_id,
        service_month,
        cost_centre_id,
        natural_account,
        direct_cost_type,
        quantity,
        amount
    FROM #direct_cost_detail_file;

    INSERT INTO landing.general_ledger_transaction
    (
        load_run_id,
        source_file_name,
        source_row_number,
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
        @load_run_id,
        N'general_ledger_transaction.csv',
        ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) + 1,
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
    FROM #general_ledger_transaction_file;

    /* ============================================================
       4. Record source file controls
       ============================================================ */

    INSERT INTO dq.source_file_control
    (
        load_run_id,
        data_area,
        file_name,
        target_schema,
        target_table,
        expected_row_count,
        actual_row_count,
        control_status,
        checked_at_utc
    )
    VALUES
    (
        @load_run_id,
        'raw',
        N'patient_encounter.csv',
        N'landing',
        N'patient_encounter',
        6345,
        (SELECT COUNT(*) FROM landing.patient_encounter WHERE load_run_id = @load_run_id AND source_file_name = N'patient_encounter.csv'),
        CASE WHEN (SELECT COUNT(*) FROM landing.patient_encounter WHERE load_run_id = @load_run_id AND source_file_name = N'patient_encounter.csv') = 6345 THEN 'PASS' ELSE 'FAIL' END,
        SYSUTCDATETIME()
    ),
    (
        @load_run_id,
        'raw',
        N'resource_usage.csv',
        N'landing',
        N'resource_usage',
        6850,
        (SELECT COUNT(*) FROM landing.resource_usage WHERE load_run_id = @load_run_id AND source_file_name = N'resource_usage.csv'),
        CASE WHEN (SELECT COUNT(*) FROM landing.resource_usage WHERE load_run_id = @load_run_id AND source_file_name = N'resource_usage.csv') = 6850 THEN 'PASS' ELSE 'FAIL' END,
        SYSUTCDATETIME()
    ),
    (
        @load_run_id,
        'raw',
        N'direct_cost_detail.csv',
        N'landing',
        N'direct_cost_detail',
        841,
        (SELECT COUNT(*) FROM landing.direct_cost_detail WHERE load_run_id = @load_run_id AND source_file_name = N'direct_cost_detail.csv'),
        CASE WHEN (SELECT COUNT(*) FROM landing.direct_cost_detail WHERE load_run_id = @load_run_id AND source_file_name = N'direct_cost_detail.csv') = 841 THEN 'PASS' ELSE 'FAIL' END,
        SYSUTCDATETIME()
    ),
    (
        @load_run_id,
        'raw',
        N'general_ledger_transaction.csv',
        N'landing',
        N'general_ledger_transaction',
        257,
        (SELECT COUNT(*) FROM landing.general_ledger_transaction WHERE load_run_id = @load_run_id AND source_file_name = N'general_ledger_transaction.csv'),
        CASE WHEN (SELECT COUNT(*) FROM landing.general_ledger_transaction WHERE load_run_id = @load_run_id AND source_file_name = N'general_ledger_transaction.csv') = 257 THEN 'PASS' ELSE 'FAIL' END,
        SYSUTCDATETIME()
    );

    UPDATE dq.load_run
    SET
        completed_at_utc = SYSUTCDATETIME(),
        load_status = 'COMPLETED'
    WHERE load_run_id = @load_run_id;

    SELECT @load_run_id AS load_run_id;

END TRY
BEGIN CATCH

    UPDATE dq.load_run
    SET
        completed_at_utc = SYSUTCDATETIME(),
        load_status = 'FAILED',
        error_message = ERROR_MESSAGE()
    WHERE load_run_id = @load_run_id;

    THROW;

END CATCH;
GO



--SELECT *
--FROM dq.load_run
--ORDER BY load_run_id DESC;

--SELECT *
--FROM dq.source_file_control
--WHERE load_run_id = (SELECT MAX(load_run_id) FROM dq.load_run)
--ORDER BY file_name;

--SELECT 'landing.patient_encounter' AS table_name, COUNT(*) AS row_count
--FROM landing.patient_encounter
--WHERE load_run_id = (SELECT MAX(load_run_id) FROM dq.load_run)
--UNION ALL
--SELECT 'landing.resource_usage', COUNT(*)
--FROM landing.resource_usage
--WHERE load_run_id = (SELECT MAX(load_run_id) FROM dq.load_run)
--UNION ALL
--SELECT 'landing.direct_cost_detail', COUNT(*)
--FROM landing.direct_cost_detail
--WHERE load_run_id = (SELECT MAX(load_run_id) FROM dq.load_run)
--UNION ALL
--SELECT 'landing.general_ledger_transaction', COUNT(*)
--FROM landing.general_ledger_transaction
--WHERE load_run_id = (SELECT MAX(load_run_id) FROM dq.load_run);

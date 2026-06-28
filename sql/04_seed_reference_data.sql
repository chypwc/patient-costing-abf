USE CostAnalysisABF;
GO

DECLARE @ReferenceRoot nvarchar(1000) = N'C:\SQLData\cost_analysis_abf\reference';
DECLARE @sql nvarchar(max);

/* ============================================================
   04_seed_reference_data.sql

   Purpose:
   Seed governed synthetic reference/configuration tables.

   Pattern:
   CSV design fixture -> temp table -> reviewed MERGE into ref table.

   Production note:
   In production, reference values would be governed through
   approved configuration/master-data processes, not blindly
   accepted from monthly raw files.
   ============================================================ */


/* ============================================================
   Service lines and care types
   ============================================================ */

CREATE TABLE #service_line_file
(
    service_line nvarchar(4000) NULL,
    description  nvarchar(4000) NULL
);

SET @sql = N'
BULK INSERT #service_line_file
FROM ''' + REPLACE(@ReferenceRoot + N'\service_line.csv', '''', '''''') + N'''
WITH
(
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK
);';

EXEC sys.sp_executesql @sql;

MERGE ref.service_line AS tgt
USING
(
    SELECT
        CAST(service_line AS nvarchar(100)) AS service_line,
        CAST(description AS nvarchar(300)) AS description
    FROM #service_line_file
) AS src
ON tgt.service_line = src.service_line
WHEN MATCHED THEN
    UPDATE SET
        description = src.description
WHEN NOT MATCHED THEN
    INSERT
    (
        service_line,
        description
    )
    VALUES
    (
        src.service_line,
        src.description
    );
GO


DECLARE @ReferenceRoot nvarchar(1000) = N'C:\SQLData\cost_analysis_abf\reference';
DECLARE @sql nvarchar(max);

CREATE TABLE #care_type_file
(
    care_type   nvarchar(4000) NULL,
    description nvarchar(4000) NULL
);

SET @sql = N'
BULK INSERT #care_type_file
FROM ''' + REPLACE(@ReferenceRoot + N'\care_type.csv', '''', '''''') + N'''
WITH
(
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK
);';

EXEC sys.sp_executesql @sql;

MERGE ref.care_type AS tgt
USING
(
    SELECT
        CAST(care_type AS varchar(30)) AS care_type,
        CAST(description AS nvarchar(300)) AS description
    FROM #care_type_file
) AS src
ON tgt.care_type = src.care_type
WHEN MATCHED THEN
    UPDATE SET
        description = src.description
WHEN NOT MATCHED THEN
    INSERT
    (
        care_type,
        description
    )
    VALUES
    (
        src.care_type,
        src.description
    );
GO




/* ============================================================
   Activity groups
   ============================================================ */

DECLARE @ReferenceRoot nvarchar(1000) = N'C:\SQLData\cost_analysis_abf\reference';
DECLARE @sql nvarchar(max);

CREATE TABLE #activity_group_file
(
    activity_group_code          nvarchar(4000) NULL,
    activity_group_name          nvarchar(4000) NULL,
    default_service_line         nvarchar(4000) NULL,
    default_care_type            nvarchar(4000) NULL,
    official_classification_flag nvarchar(4000) NULL
);

SET @sql = N'
BULK INSERT #activity_group_file
FROM ''' + REPLACE(@ReferenceRoot + N'\activity_group.csv', '''', '''''') + N'''
WITH
(
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK
);';

EXEC sys.sp_executesql @sql;

MERGE ref.activity_group AS tgt
USING
(
    SELECT
        CAST(activity_group_code AS varchar(30)) AS activity_group_code,
        CAST(activity_group_name AS nvarchar(100)) AS activity_group_name,
        CAST(NULLIF(default_service_line, '') AS nvarchar(100)) AS default_service_line,
        CAST(NULLIF(default_care_type, '') AS varchar(30)) AS default_care_type,
        CAST(official_classification_flag AS char(1)) AS official_classification_flag
    FROM #activity_group_file
) AS src
ON tgt.activity_group_code = src.activity_group_code
WHEN MATCHED THEN
    UPDATE SET
        activity_group_name = src.activity_group_name,
        default_service_line = src.default_service_line,
        default_care_type = src.default_care_type,
        official_classification_flag = src.official_classification_flag
WHEN NOT MATCHED THEN
    INSERT
    (
        activity_group_code,
        activity_group_name,
        default_service_line,
        default_care_type,
        official_classification_flag
    )
    VALUES
    (
        src.activity_group_code,
        src.activity_group_name,
        src.default_service_line,
        src.default_care_type,
        src.official_classification_flag
    );
GO


/* ============================================================
   Cost centres
   ============================================================ */

DECLARE @ReferenceRoot nvarchar(1000) = N'C:\SQLData\cost_analysis_abf\reference';
DECLARE @sql nvarchar(max);

CREATE TABLE #cost_centre_file
(
    cost_centre_id   nvarchar(4000) NULL,
    cost_centre_name nvarchar(4000) NULL,
    service_line     nvarchar(4000) NULL,
    cost_pool_code   nvarchar(4000) NULL,
    active_flag      nvarchar(4000) NULL,
    effective_from   nvarchar(4000) NULL,
    effective_to     nvarchar(4000) NULL
);

SET @sql = N'
BULK INSERT #cost_centre_file
FROM ''' + REPLACE(@ReferenceRoot + N'\cost_centre.csv', '''', '''''') + N'''
WITH
(
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK
);';

EXEC sys.sp_executesql @sql;

MERGE ref.cost_centre AS tgt
USING
(
    SELECT
        CAST(cost_centre_id AS varchar(30)) AS cost_centre_id,
        CAST(cost_centre_name AS nvarchar(100)) AS cost_centre_name,
        CAST(service_line AS nvarchar(100)) AS service_line,
        CAST(cost_pool_code AS varchar(30)) AS cost_pool_code,
        CAST(active_flag AS char(1)) AS active_flag,
        CONVERT(date, effective_from) AS effective_from,
        CONVERT(date, effective_to) AS effective_to
    FROM #cost_centre_file
) AS src
ON tgt.cost_centre_id = src.cost_centre_id
AND tgt.effective_from = src.effective_from
WHEN MATCHED THEN
    UPDATE SET
        cost_centre_name = src.cost_centre_name,
        service_line = src.service_line,
        cost_pool_code = src.cost_pool_code,
        active_flag = src.active_flag,
        effective_to = src.effective_to
WHEN NOT MATCHED THEN
    INSERT
    (
        cost_centre_id,
        cost_centre_name,
        service_line,
        cost_pool_code,
        active_flag,
        effective_from,
        effective_to
    )
    VALUES
    (
        src.cost_centre_id,
        src.cost_centre_name,
        src.service_line,
        src.cost_pool_code,
        src.active_flag,
        src.effective_from,
        src.effective_to
    );
GO



/* ============================================================
   Account mapping
   ============================================================ */

DECLARE @ReferenceRoot nvarchar(1000) = N'C:\SQLData\cost_analysis_abf\reference';
DECLARE @sql nvarchar(max);

CREATE TABLE #account_mapping_file
(
    natural_account     nvarchar(4000) NULL,
    account_description nvarchar(4000) NULL,
    cost_category       nvarchar(4000) NULL,
    costing_treatment   nvarchar(4000) NULL,
    default_driver      nvarchar(4000) NULL,
    active_flag         nvarchar(4000) NULL
);

SET @sql = N'
BULK INSERT #account_mapping_file
FROM ''' + REPLACE(@ReferenceRoot + N'\account_mapping.csv', '''', '''''') + N'''
WITH
(
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK
);';

EXEC sys.sp_executesql @sql;

MERGE ref.account_mapping AS tgt
USING
(
    SELECT
        CAST(natural_account AS varchar(20)) AS natural_account,
        CAST(account_description AS nvarchar(100)) AS account_description,
        CAST(cost_category AS nvarchar(100)) AS cost_category,
        CAST(costing_treatment AS varchar(20)) AS costing_treatment,
        CAST(default_driver AS varchar(50)) AS default_driver,
        CAST(active_flag AS char(1)) AS active_flag
    FROM #account_mapping_file
) AS src
ON tgt.natural_account = src.natural_account
WHEN MATCHED THEN
    UPDATE SET
        account_description = src.account_description,
        cost_category = src.cost_category,
        costing_treatment = src.costing_treatment,
        default_driver = src.default_driver,
        active_flag = src.active_flag
WHEN NOT MATCHED THEN
    INSERT
    (
        natural_account,
        account_description,
        cost_category,
        costing_treatment,
        default_driver,
        active_flag
    )
    VALUES
    (
        src.natural_account,
        src.account_description,
        src.cost_category,
        src.costing_treatment,
        src.default_driver,
        src.active_flag
    );
GO



/* ============================================================
   Allocation rules
   ============================================================ */

DECLARE @ReferenceRoot nvarchar(1000) = N'C:\SQLData\cost_analysis_abf\reference';
DECLARE @sql nvarchar(max);

CREATE TABLE #allocation_rule_file
(
    allocation_rule_id nvarchar(4000) NULL,
    cost_pool_code     nvarchar(4000) NULL,
    cost_category      nvarchar(4000) NULL,
    allocation_driver  nvarchar(4000) NULL,
    eligible_scope     nvarchar(4000) NULL,
    business_rationale nvarchar(4000) NULL,
    effective_from     nvarchar(4000) NULL,
    effective_to       nvarchar(4000) NULL,
    active_flag        nvarchar(4000) NULL
);

SET @sql = N'
BULK INSERT #allocation_rule_file
FROM ''' + REPLACE(@ReferenceRoot + N'\allocation_rule.csv', '''', '''''') + N'''
WITH
(
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK
);';

EXEC sys.sp_executesql @sql;

MERGE ref.allocation_rule AS tgt
USING
(
    SELECT
        CAST(allocation_rule_id AS varchar(30)) AS allocation_rule_id,
        CAST(cost_pool_code AS varchar(30)) AS cost_pool_code,
        CAST(cost_category AS nvarchar(100)) AS cost_category,
        CAST(allocation_driver AS varchar(50)) AS allocation_driver,
        CAST(eligible_scope AS nvarchar(200)) AS eligible_scope,
        CAST(business_rationale AS nvarchar(500)) AS business_rationale,
        CONVERT(date, effective_from) AS effective_from,
        CONVERT(date, effective_to) AS effective_to,
        CAST(active_flag AS char(1)) AS active_flag
    FROM #allocation_rule_file
) AS src
ON tgt.allocation_rule_id = src.allocation_rule_id
AND tgt.effective_from = src.effective_from
WHEN MATCHED THEN
    UPDATE SET
        cost_pool_code = src.cost_pool_code,
        cost_category = src.cost_category,
        allocation_driver = src.allocation_driver,
        eligible_scope = src.eligible_scope,
        business_rationale = src.business_rationale,
        effective_to = src.effective_to,
        active_flag = src.active_flag
WHEN NOT MATCHED THEN
    INSERT
    (
        allocation_rule_id,
        cost_pool_code,
        cost_category,
        allocation_driver,
        eligible_scope,
        business_rationale,
        effective_from,
        effective_to,
        active_flag
    )
    VALUES
    (
        src.allocation_rule_id,
        src.cost_pool_code,
        src.cost_category,
        src.allocation_driver,
        src.eligible_scope,
        src.business_rationale,
        src.effective_from,
        src.effective_to,
        src.active_flag
    );
GO



/* ============================================================
   Reporting periods
   ============================================================ */

DECLARE @ReferenceRoot nvarchar(1000) = N'C:\SQLData\cost_analysis_abf\reference';
DECLARE @sql nvarchar(max);

CREATE TABLE #reporting_period_file
(
    reporting_month nvarchar(4000) NULL,
    period_start    nvarchar(4000) NULL,
    period_end      nvarchar(4000) NULL,
    financial_year  nvarchar(4000) NULL,
    period_number   nvarchar(4000) NULL
);

SET @sql = N'
BULK INSERT #reporting_period_file
FROM ''' + REPLACE(@ReferenceRoot + N'\reporting_period.csv', '''', '''''') + N'''
WITH
(
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK
);';

EXEC sys.sp_executesql @sql;

MERGE ref.reporting_period AS tgt
USING
(
    SELECT
        CONVERT(date, reporting_month) AS reporting_month,
        CONVERT(date, period_start) AS period_start,
        CONVERT(date, period_end) AS period_end,
        CAST(financial_year AS varchar(10)) AS financial_year,
        CONVERT(tinyint, period_number) AS period_number
    FROM #reporting_period_file
) AS src
ON tgt.reporting_month = src.reporting_month
WHEN MATCHED THEN
    UPDATE SET
        period_start = src.period_start,
        period_end = src.period_end,
        financial_year = src.financial_year,
        period_number = src.period_number
WHEN NOT MATCHED THEN
    INSERT
    (
        reporting_month,
        period_start,
        period_end,
        financial_year,
        period_number
    )
    VALUES
    (
        src.reporting_month,
        src.period_start,
        src.period_end,
        src.financial_year,
        src.period_number
    );
GO


/* ============================================================
   ABF activity groups
   ============================================================ */

DECLARE @ReferenceRoot nvarchar(1000) = N'C:\SQLData\cost_analysis_abf\reference';
DECLARE @sql nvarchar(max);

CREATE TABLE #abf_activity_group_file
(
    activity_group_code            nvarchar(4000) NULL,
    activity_group_name            nvarchar(4000) NULL,
    service_stream                 nvarchar(4000) NULL,
    synthetic_base_weight          nvarchar(4000) NULL,
    high_length_of_stay_trim_days  nvarchar(4000) NULL,
    synthetic_outlier_nwau_per_day nvarchar(4000) NULL,
    official_price_weight_flag     nvarchar(4000) NULL
);

SET @sql = N'
BULK INSERT #abf_activity_group_file
FROM ''' + REPLACE(@ReferenceRoot + N'\abf_activity_group.csv', '''', '''''') + N'''
WITH
(
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK
);';

EXEC sys.sp_executesql @sql;

MERGE ref.abf_activity_group AS tgt
USING
(
    SELECT
        CAST(activity_group_code AS varchar(30)) AS activity_group_code,
        CAST(activity_group_name AS nvarchar(100)) AS activity_group_name,
        CAST(service_stream AS varchar(50)) AS service_stream,
        CONVERT(decimal(12,6), synthetic_base_weight) AS synthetic_base_weight,
        CONVERT(smallint, high_length_of_stay_trim_days) AS high_length_of_stay_trim_days,
        CONVERT(decimal(12,6), synthetic_outlier_nwau_per_day) AS synthetic_outlier_nwau_per_day,
        CAST(official_price_weight_flag AS char(1)) AS official_price_weight_flag
    FROM #abf_activity_group_file
) AS src
ON tgt.activity_group_code = src.activity_group_code
WHEN MATCHED THEN
    UPDATE SET
        activity_group_name = src.activity_group_name,
        service_stream = src.service_stream,
        synthetic_base_weight = src.synthetic_base_weight,
        high_length_of_stay_trim_days = src.high_length_of_stay_trim_days,
        synthetic_outlier_nwau_per_day = src.synthetic_outlier_nwau_per_day,
        official_price_weight_flag = src.official_price_weight_flag
WHEN NOT MATCHED THEN
    INSERT
    (
        activity_group_code,
        activity_group_name,
        service_stream,
        synthetic_base_weight,
        high_length_of_stay_trim_days,
        synthetic_outlier_nwau_per_day,
        official_price_weight_flag
    )
    VALUES
    (
        src.activity_group_code,
        src.activity_group_name,
        src.service_stream,
        src.synthetic_base_weight,
        src.high_length_of_stay_trim_days,
        src.synthetic_outlier_nwau_per_day,
        src.official_price_weight_flag
    );
GO



/* ============================================================
   ABF adjustment rules
   ============================================================ */

DECLARE @ReferenceRoot nvarchar(1000) = N'C:\SQLData\cost_analysis_abf\reference';
DECLARE @sql nvarchar(max);

CREATE TABLE #abf_adjustment_rule_file
(
    adjustment_code          nvarchar(4000) NULL,
    description              nvarchar(4000) NULL,
    factor                   nvarchar(4000) NULL,
    application              nvarchar(4000) NULL,
    official_adjustment_flag nvarchar(4000) NULL
);

SET @sql = N'
BULK INSERT #abf_adjustment_rule_file
FROM ''' + REPLACE(@ReferenceRoot + N'\abf_adjustment_rule.csv', '''', '''''') + N'''
WITH
(
    FORMAT = ''CSV'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    TABLOCK
);';

EXEC sys.sp_executesql @sql;

MERGE ref.abf_adjustment_rule AS tgt
USING
(
    SELECT
        CAST(adjustment_code AS varchar(30)) AS adjustment_code,
        CAST(description AS nvarchar(200)) AS description,
        CAST(factor AS varchar(30)) AS factor,
        CAST(application AS varchar(30)) AS application,
        CAST(official_adjustment_flag AS char(1)) AS official_adjustment_flag
    FROM #abf_adjustment_rule_file
) AS src
ON tgt.adjustment_code = src.adjustment_code
WHEN MATCHED THEN
    UPDATE SET
        description = src.description,
        factor = src.factor,
        application = src.application,
        official_adjustment_flag = src.official_adjustment_flag
WHEN NOT MATCHED THEN
    INSERT
    (
        adjustment_code,
        description,
        factor,
        application,
        official_adjustment_flag
    )
    VALUES
    (
        src.adjustment_code,
        src.description,
        src.factor,
        src.application,
        src.official_adjustment_flag
    );
GO


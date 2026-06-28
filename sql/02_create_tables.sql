USE CostAnalysisABF;
GO

/* ============================================================
   1. Load audit
   ============================================================ */

IF OBJECT_ID(N'dq.load_run', N'U') IS NULL
BEGIN
    CREATE TABLE dq.load_run
    (
        load_run_id       bigint IDENTITY(1,1) NOT NULL,
        load_name         varchar(100)          NOT NULL,
        financial_year    varchar(10)           NOT NULL,
        source_root_path  nvarchar(1000)        NOT NULL,
        started_at_utc    datetime2(0)          NOT NULL
            CONSTRAINT DF_dq_load_run_started
            DEFAULT SYSUTCDATETIME(),
        completed_at_utc  datetime2(0)          NULL,
        load_status       varchar(20)           NOT NULL
            CONSTRAINT DF_dq_load_run_status
            DEFAULT 'STARTED',
        error_message     nvarchar(2000)        NULL,

        CONSTRAINT PK_dq_load_run
            PRIMARY KEY (load_run_id)
    );

    PRINT 'Created dq.load_run.';
END
ELSE
    PRINT 'dq.load_run already exists.';
GO

/* ============================================================
   2. Nullable-text landing tables
   ============================================================ */

IF OBJECT_ID(N'landing.patient_encounter', N'U') IS NULL
BEGIN
    CREATE TABLE landing.patient_encounter
    (
        landing_row_id                      bigint IDENTITY(1,1) NOT NULL,
        load_run_id                         bigint               NOT NULL,
        source_file_name                    nvarchar(260)        NOT NULL,
        source_row_number                   bigint               NOT NULL,
        loaded_at_utc                       datetime2(0)         NOT NULL
            CONSTRAINT DF_landing_patient_encounter_loaded
            DEFAULT SYSUTCDATETIME(),

        encounter_id                        nvarchar(4000) NULL,
        patient_id                          nvarchar(4000) NULL,
        facility                            nvarchar(4000) NULL,
        service_line                        nvarchar(4000) NULL,
        care_type                           nvarchar(4000) NULL,
        admission_date                      nvarchar(4000) NULL,
        discharge_date                      nvarchar(4000) NULL,
        episode_month                       nvarchar(4000) NULL,
        activity_group_code                 nvarchar(4000) NULL,
        length_of_stay                      nvarchar(4000) NULL,
        separation_status                   nvarchar(4000) NULL,
        age_years                           nvarchar(4000) NULL,
        indigenous_status                   nvarchar(4000) NULL,
        remoteness_area                     nvarchar(4000) NULL,
        high_complexity_flag                nvarchar(4000) NULL,
        hospital_acquired_complication_flag nvarchar(4000) NULL,

        CONSTRAINT PK_landing_patient_encounter
            PRIMARY KEY (landing_row_id),

        CONSTRAINT FK_landing_patient_encounter_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id),

        CONSTRAINT UQ_landing_patient_encounter_source_row
            UNIQUE (load_run_id, source_file_name, source_row_number)
    );

    PRINT 'Created landing.patient_encounter.';
END
ELSE
    PRINT 'landing.patient_encounter already exists.';
GO

IF OBJECT_ID(N'landing.resource_usage', N'U') IS NULL
BEGIN
    CREATE TABLE landing.resource_usage
    (
        landing_row_id            bigint IDENTITY(1,1) NOT NULL,
        load_run_id               bigint               NOT NULL,
        source_file_name          nvarchar(260)        NOT NULL,
        source_row_number         bigint               NOT NULL,
        loaded_at_utc             datetime2(0)         NOT NULL
            CONSTRAINT DF_landing_resource_usage_loaded
            DEFAULT SYSUTCDATETIME(),

        resource_usage_id         nvarchar(4000) NULL,
        encounter_id              nvarchar(4000) NULL,
        service_month             nvarchar(4000) NULL,
        bed_days                  nvarchar(4000) NULL,
        theatre_minutes           nvarchar(4000) NULL,
        imaging_weighted_units    nvarchar(4000) NULL,
        pathology_weighted_units  nvarchar(4000) NULL,
        pharmacy_units            nvarchar(4000) NULL,
        medical_service_units     nvarchar(4000) NULL,
        allied_health_units       nvarchar(4000) NULL,

        CONSTRAINT PK_landing_resource_usage
            PRIMARY KEY (landing_row_id),

        CONSTRAINT FK_landing_resource_usage_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id),

        CONSTRAINT UQ_landing_resource_usage_source_row
            UNIQUE (load_run_id, source_file_name, source_row_number)
    );

    PRINT 'Created landing.resource_usage.';
END
ELSE
    PRINT 'landing.resource_usage already exists.';
GO

IF OBJECT_ID(N'landing.direct_cost_detail', N'U') IS NULL
BEGIN
    CREATE TABLE landing.direct_cost_detail
    (
        landing_row_id     bigint IDENTITY(1,1) NOT NULL,
        load_run_id        bigint               NOT NULL,
        source_file_name   nvarchar(260)        NOT NULL,
        source_row_number  bigint               NOT NULL,
        loaded_at_utc      datetime2(0)         NOT NULL
            CONSTRAINT DF_landing_direct_cost_loaded
            DEFAULT SYSUTCDATETIME(),

        direct_cost_id     nvarchar(4000) NULL,
        encounter_id       nvarchar(4000) NULL,
        service_month      nvarchar(4000) NULL,
        cost_centre_id     nvarchar(4000) NULL,
        natural_account    nvarchar(4000) NULL,
        direct_cost_type   nvarchar(4000) NULL,
        quantity           nvarchar(4000) NULL,
        amount             nvarchar(4000) NULL,

        CONSTRAINT PK_landing_direct_cost_detail
            PRIMARY KEY (landing_row_id),

        CONSTRAINT FK_landing_direct_cost_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id),

        CONSTRAINT UQ_landing_direct_cost_source_row
            UNIQUE (load_run_id, source_file_name, source_row_number)
    );

    PRINT 'Created landing.direct_cost_detail.';
END
ELSE
    PRINT 'landing.direct_cost_detail already exists.';
GO

IF OBJECT_ID(N'landing.general_ledger_transaction', N'U') IS NULL
BEGIN
    CREATE TABLE landing.general_ledger_transaction
    (
        landing_row_id      bigint IDENTITY(1,1) NOT NULL,
        load_run_id         bigint               NOT NULL,
        source_file_name    nvarchar(260)        NOT NULL,
        source_row_number   bigint               NOT NULL,
        loaded_at_utc       datetime2(0)         NOT NULL
            CONSTRAINT DF_landing_gl_loaded
            DEFAULT SYSUTCDATETIME(),

        gl_transaction_id   nvarchar(4000) NULL,
        reporting_month     nvarchar(4000) NULL,
        entity              nvarchar(4000) NULL,
        facility            nvarchar(4000) NULL,
        cost_centre_id      nvarchar(4000) NULL,
        natural_account     nvarchar(4000) NULL,
        account_description nvarchar(4000) NULL,
        signed_amount       nvarchar(4000) NULL,
        adjustment_type     nvarchar(4000) NULL,
        source_reference    nvarchar(4000) NULL,

        CONSTRAINT PK_landing_gl_transaction
            PRIMARY KEY (landing_row_id),

        CONSTRAINT FK_landing_gl_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id),

        CONSTRAINT UQ_landing_gl_source_row
            UNIQUE (load_run_id, source_file_name, source_row_number)
    );

    PRINT 'Created landing.general_ledger_transaction.';
END
ELSE
    PRINT 'landing.general_ledger_transaction already exists.';
GO

/* ============================================================
   3. Validated typed transaction tables
   ============================================================ */

IF OBJECT_ID(N'stg.patient_encounter', N'U') IS NULL
BEGIN
    CREATE TABLE stg.patient_encounter
    (
        landing_row_id                      bigint        NOT NULL,
        load_run_id                         bigint        NOT NULL,
        promoted_at_utc                     datetime2(0)  NOT NULL
            CONSTRAINT DF_stg_patient_encounter_promoted
            DEFAULT SYSUTCDATETIME(),

        encounter_id                        varchar(20)   NOT NULL,
        patient_id                          varchar(20)   NOT NULL,
        facility                            nvarchar(100) NOT NULL,
        service_line                        nvarchar(100) NOT NULL,
        care_type                           varchar(30)   NOT NULL,
        admission_date                      date          NOT NULL,
        discharge_date                      date          NOT NULL,
        episode_month                       date          NOT NULL,
        activity_group_code                 varchar(30)   NOT NULL,
        length_of_stay                      smallint      NOT NULL,
        separation_status                   varchar(30)   NOT NULL,
        age_years                           smallint      NOT NULL,
        indigenous_status                   char(1)       NOT NULL,
        remoteness_area                     varchar(50)   NOT NULL,
        high_complexity_flag                char(1)       NOT NULL,
        hospital_acquired_complication_flag char(1)       NOT NULL,

        CONSTRAINT PK_stg_patient_encounter
            PRIMARY KEY (landing_row_id),

        CONSTRAINT FK_stg_patient_encounter_landing
            FOREIGN KEY (landing_row_id)
            REFERENCES landing.patient_encounter(landing_row_id),

        CONSTRAINT FK_stg_patient_encounter_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id),

        CONSTRAINT UQ_stg_patient_encounter_load_encounter
            UNIQUE (load_run_id, encounter_id)
    );

    PRINT 'Created stg.patient_encounter.';
END
ELSE
    PRINT 'stg.patient_encounter already exists.';
GO

IF OBJECT_ID(N'stg.resource_usage', N'U') IS NULL
BEGIN
    CREATE TABLE stg.resource_usage
    (
        landing_row_id            bigint       NOT NULL,
        load_run_id               bigint       NOT NULL,
        promoted_at_utc           datetime2(0) NOT NULL
            CONSTRAINT DF_stg_resource_usage_promoted
            DEFAULT SYSUTCDATETIME(),

        resource_usage_id         varchar(20)  NOT NULL,
        encounter_id              varchar(20)  NOT NULL,
        service_month             date         NOT NULL,
        bed_days                  int          NOT NULL,
        theatre_minutes           int          NOT NULL,
        imaging_weighted_units    int          NOT NULL,
        pathology_weighted_units  int          NOT NULL,
        pharmacy_units            int          NOT NULL,
        medical_service_units     int          NOT NULL,
        allied_health_units       int          NOT NULL,

        CONSTRAINT PK_stg_resource_usage
            PRIMARY KEY (landing_row_id),

        CONSTRAINT FK_stg_resource_usage_landing
            FOREIGN KEY (landing_row_id)
            REFERENCES landing.resource_usage(landing_row_id),

        CONSTRAINT FK_stg_resource_usage_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id),

        CONSTRAINT FK_stg_resource_usage_encounter
            FOREIGN KEY (load_run_id, encounter_id)
            REFERENCES stg.patient_encounter(load_run_id, encounter_id),

        CONSTRAINT UQ_stg_resource_usage_load_resource
            UNIQUE (load_run_id, resource_usage_id)
    );

    PRINT 'Created stg.resource_usage.';
END
ELSE
    PRINT 'stg.resource_usage already exists.';
GO

IF OBJECT_ID(N'stg.direct_cost_detail', N'U') IS NULL
BEGIN
    CREATE TABLE stg.direct_cost_detail
    (
        landing_row_id    bigint        NOT NULL,
        load_run_id       bigint        NOT NULL,
        promoted_at_utc   datetime2(0)  NOT NULL
            CONSTRAINT DF_stg_direct_cost_promoted
            DEFAULT SYSUTCDATETIME(),

        direct_cost_id    varchar(20)    NOT NULL,
        encounter_id      varchar(20)    NOT NULL,
        service_month     date           NOT NULL,
        cost_centre_id    varchar(30)    NOT NULL,
        natural_account   varchar(20)    NOT NULL,
        direct_cost_type  nvarchar(100)  NOT NULL,
        quantity          int            NOT NULL,
        amount            decimal(19, 6) NOT NULL,

        CONSTRAINT PK_stg_direct_cost_detail
            PRIMARY KEY (landing_row_id),

        CONSTRAINT FK_stg_direct_cost_landing
            FOREIGN KEY (landing_row_id)
            REFERENCES landing.direct_cost_detail(landing_row_id),

        CONSTRAINT FK_stg_direct_cost_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id),

        CONSTRAINT FK_stg_direct_cost_encounter
            FOREIGN KEY (load_run_id, encounter_id)
            REFERENCES stg.patient_encounter(load_run_id, encounter_id),

        CONSTRAINT UQ_stg_direct_cost_load_direct_cost
            UNIQUE (load_run_id, direct_cost_id)
    );

    PRINT 'Created stg.direct_cost_detail.';
END
ELSE
    PRINT 'stg.direct_cost_detail already exists.';
GO

IF OBJECT_ID(N'stg.general_ledger_transaction', N'U') IS NULL
BEGIN
    CREATE TABLE stg.general_ledger_transaction
    (
        landing_row_id       bigint         NOT NULL,
        load_run_id          bigint         NOT NULL,
        promoted_at_utc      datetime2(0)   NOT NULL
            CONSTRAINT DF_stg_gl_promoted
            DEFAULT SYSUTCDATETIME(),

        gl_transaction_id    varchar(20)     NOT NULL,
        reporting_month      date            NOT NULL,
        entity               nvarchar(100)   NOT NULL,
        facility             nvarchar(100)   NOT NULL,
        cost_centre_id       varchar(30)     NOT NULL,
        natural_account      varchar(20)     NOT NULL,
        account_description  nvarchar(200)   NOT NULL,
        signed_amount        decimal(19, 6)  NOT NULL,
        adjustment_type      varchar(30)     NOT NULL,
        source_reference     nvarchar(200)   NOT NULL,

        CONSTRAINT PK_stg_gl_transaction
            PRIMARY KEY (landing_row_id),

        CONSTRAINT FK_stg_gl_landing
            FOREIGN KEY (landing_row_id)
            REFERENCES landing.general_ledger_transaction(landing_row_id),

        CONSTRAINT FK_stg_gl_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id),

        CONSTRAINT UQ_stg_gl_load_transaction
            UNIQUE (load_run_id, gl_transaction_id)
    );

    PRINT 'Created stg.general_ledger_transaction.';
END
ELSE
    PRINT 'stg.general_ledger_transaction already exists.';
GO

/* ============================================================
   4. Governed reference tables
   ============================================================ */

IF OBJECT_ID(N'ref.service_line', N'U') IS NULL
BEGIN
    CREATE TABLE ref.service_line
    (
        service_line  nvarchar(100) NOT NULL,
        description   nvarchar(300) NOT NULL,

        CONSTRAINT PK_ref_service_line
            PRIMARY KEY (service_line)
    );

    PRINT 'Created ref.service_line.';
END
ELSE
    PRINT 'ref.service_line already exists.';
GO

IF OBJECT_ID(N'ref.care_type', N'U') IS NULL
BEGIN
    CREATE TABLE ref.care_type
    (
        care_type    varchar(30)   NOT NULL,
        description  nvarchar(300) NOT NULL,

        CONSTRAINT PK_ref_care_type
            PRIMARY KEY (care_type)
    );

    PRINT 'Created ref.care_type.';
END
ELSE
    PRINT 'ref.care_type already exists.';
GO

IF OBJECT_ID(N'ref.activity_group', N'U') IS NULL
BEGIN
    CREATE TABLE ref.activity_group
    (
        activity_group_code           varchar(30)   NOT NULL,
        activity_group_name           nvarchar(100) NOT NULL,
        default_service_line          nvarchar(100) NULL,
        default_care_type             varchar(30)   NULL,
        official_classification_flag  char(1)       NOT NULL,

        CONSTRAINT PK_ref_activity_group
            PRIMARY KEY (activity_group_code),

        CONSTRAINT FK_ref_activity_group_service_line
            FOREIGN KEY (default_service_line)
            REFERENCES ref.service_line(service_line),

        CONSTRAINT FK_ref_activity_group_care_type
            FOREIGN KEY (default_care_type)
            REFERENCES ref.care_type(care_type)
    );

    PRINT 'Created ref.activity_group.';
END
ELSE
    PRINT 'ref.activity_group already exists.';
GO

IF OBJECT_ID(N'ref.cost_centre', N'U') IS NULL
BEGIN
    CREATE TABLE ref.cost_centre
    (
        cost_centre_id    varchar(30)   NOT NULL,
        cost_centre_name  nvarchar(100) NOT NULL,
        service_line      nvarchar(100) NOT NULL,
        cost_pool_code    varchar(30)   NOT NULL,
        active_flag       char(1)       NOT NULL,
        effective_from    date          NOT NULL,
        effective_to      date          NOT NULL,

        CONSTRAINT PK_ref_cost_centre
            PRIMARY KEY (cost_centre_id, effective_from)
    );

    PRINT 'Created ref.cost_centre.';
END
ELSE
    PRINT 'ref.cost_centre already exists.';
GO

IF OBJECT_ID(N'ref.account_mapping', N'U') IS NULL
BEGIN
    CREATE TABLE ref.account_mapping
    (
        natural_account      varchar(20)   NOT NULL,
        account_description  nvarchar(100) NOT NULL,
        cost_category        nvarchar(100) NOT NULL,
        costing_treatment    varchar(20)   NOT NULL,
        default_driver       varchar(50)   NOT NULL,
        active_flag          char(1)       NOT NULL,

        CONSTRAINT PK_ref_account_mapping
            PRIMARY KEY (natural_account)
    );

    PRINT 'Created ref.account_mapping.';
END
ELSE
    PRINT 'ref.account_mapping already exists.';
GO

IF OBJECT_ID(N'ref.allocation_rule', N'U') IS NULL
BEGIN
    CREATE TABLE ref.allocation_rule
    (
        allocation_rule_id  varchar(30)   NOT NULL,
        cost_pool_code      varchar(30)   NOT NULL,
        cost_category       nvarchar(100) NOT NULL,
        allocation_driver   varchar(50)   NOT NULL,
        eligible_scope      nvarchar(200) NOT NULL,
        business_rationale  nvarchar(500) NOT NULL,
        effective_from      date          NOT NULL,
        effective_to        date          NOT NULL,
        active_flag         char(1)       NOT NULL,

        CONSTRAINT PK_ref_allocation_rule
            PRIMARY KEY (allocation_rule_id, effective_from)
    );

    PRINT 'Created ref.allocation_rule.';
END
ELSE
    PRINT 'ref.allocation_rule already exists.';
GO

IF OBJECT_ID(N'ref.reporting_period', N'U') IS NULL
BEGIN
    CREATE TABLE ref.reporting_period
    (
        reporting_month  date        NOT NULL,
        period_start     date        NOT NULL,
        period_end       date        NOT NULL,
        financial_year   varchar(10) NOT NULL,
        period_number    tinyint     NOT NULL,

        CONSTRAINT PK_ref_reporting_period
            PRIMARY KEY (reporting_month)
    );

    PRINT 'Created ref.reporting_period.';
END
ELSE
    PRINT 'ref.reporting_period already exists.';
GO

IF OBJECT_ID(N'ref.abf_activity_group', N'U') IS NULL
BEGIN
    CREATE TABLE ref.abf_activity_group
    (
        activity_group_code             varchar(30)    NOT NULL,
        activity_group_name             nvarchar(100)  NOT NULL,
        service_stream                  varchar(50)    NOT NULL,
        synthetic_base_weight           decimal(12, 6) NOT NULL,
        high_length_of_stay_trim_days   smallint       NOT NULL,
        synthetic_outlier_nwau_per_day  decimal(12, 6) NOT NULL,
        official_price_weight_flag      char(1)        NOT NULL,

        CONSTRAINT PK_ref_abf_activity_group
            PRIMARY KEY (activity_group_code)
    );

    PRINT 'Created ref.abf_activity_group.';
END
ELSE
    PRINT 'ref.abf_activity_group already exists.';
GO

IF OBJECT_ID(N'ref.abf_adjustment_rule', N'U') IS NULL
BEGIN
    CREATE TABLE ref.abf_adjustment_rule
    (
        adjustment_code           varchar(30)   NOT NULL,
        description               nvarchar(200) NOT NULL,
        factor                    varchar(30)   NOT NULL,
        application               varchar(30)   NOT NULL,
        official_adjustment_flag  char(1)       NOT NULL,

        CONSTRAINT PK_ref_abf_adjustment_rule
            PRIMARY KEY (adjustment_code)
    );

    PRINT 'Created ref.abf_adjustment_rule.';
END
ELSE
    PRINT 'ref.abf_adjustment_rule already exists.';
GO

/* ============================================================
   5. Source controls
   ============================================================ */

IF OBJECT_ID(N'dq.source_file_control', N'U') IS NULL
BEGIN
    CREATE TABLE dq.source_file_control
    (
        source_file_control_id  bigint IDENTITY(1,1) NOT NULL,
        load_run_id             bigint               NOT NULL,
        data_area               varchar(30)          NOT NULL,
        file_name               nvarchar(260)        NOT NULL,
        target_schema           sysname              NOT NULL,
        target_table            sysname              NOT NULL,
        expected_row_count      bigint               NOT NULL,
        actual_row_count        bigint               NULL,
        control_status          varchar(20)          NOT NULL
            CONSTRAINT DF_dq_source_file_control_status
            DEFAULT 'PENDING',
        checked_at_utc          datetime2(0)          NULL,
        error_message           nvarchar(2000)        NULL,

        CONSTRAINT PK_dq_source_file_control
            PRIMARY KEY (source_file_control_id),

        CONSTRAINT FK_dq_source_file_control_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id),

        CONSTRAINT UQ_dq_source_file_control
            UNIQUE (load_run_id, data_area, file_name)
    );

    PRINT 'Created dq.source_file_control.';
END
ELSE
    PRINT 'dq.source_file_control already exists.';
GO

IF OBJECT_ID(N'recon.gl_control_total', N'U') IS NULL
BEGIN
    CREATE TABLE recon.gl_control_total
    (
        gl_control_total_id  bigint IDENTITY(1,1) NOT NULL,
        load_run_id          bigint               NOT NULL,
        control_level        varchar(30)          NOT NULL,
        reporting_month      date                 NOT NULL,
        cost_centre_id       varchar(30)          NULL,
        expected_amount      decimal(19,6)        NOT NULL,
        actual_amount        decimal(19,6)        NULL,
        control_status       varchar(20)          NOT NULL
            CONSTRAINT DF_recon_gl_control_status
            DEFAULT 'PENDING',
        checked_at_utc       datetime2(0)          NULL,
        error_message        nvarchar(2000)        NULL,

        CONSTRAINT PK_recon_gl_control_total
            PRIMARY KEY (gl_control_total_id),

        CONSTRAINT FK_recon_gl_control_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id)
    );

    PRINT 'Created recon.gl_control_total.';
END
ELSE
    PRINT 'recon.gl_control_total already exists.';
GO



/* ============================================================
   6. Validation
   
    dq.validation_rule: what should be check
            ↓
    dq.validation_result: summary for the load
            ↓
    dq.issue_register: exact failed rows
   ============================================================ */


IF OBJECT_ID('dq.validation_rule', 'U') IS NULL
BEGIN
    CREATE TABLE dq.validation_rule
    (
        validation_rule_id  varchar(50)    NOT NULL,
        source_entity       varchar(100)   NOT NULL,
        rule_category       varchar(50)    NOT NULL,
        rule_name           nvarchar(200)  NOT NULL,
        rule_description    nvarchar(1000) NOT NULL,
        severity            varchar(20)    NOT NULL,
        blocking_flag       char(1)        NOT NULL,
        active_flag         char(1)        NOT NULL,

        CONSTRAINT PK_dq_validation_rule
            PRIMARY KEY (validation_rule_id)
    );

    PRINT 'Created dq.validation_rule.';
END;
GO

IF OBJECT_ID(N'dq.validation_result', N'U') IS NULL
BEGIN
    CREATE TABLE dq.validation_result
    (
        validation_result_id  bigint IDENTITY(1,1) NOT NULL,
        load_run_id           bigint               NOT NULL,
        validation_rule_id    varchar(50)          NOT NULL,
        evaluated_row_count   bigint               NOT NULL,
        failed_row_count      bigint               NOT NULL,
        affected_amount       decimal(19,6)        NULL,
        validation_status     varchar(20)          NOT NULL,
        evaluated_at_utc      datetime2(0)         NOT NULL
            CONSTRAINT DF_dq_validation_result_evaluated
            DEFAULT SYSUTCDATETIME(),
        result_message        nvarchar(2000)       NULL,

        CONSTRAINT PK_dq_validation_result
            PRIMARY KEY (validation_result_id),

        CONSTRAINT FK_dq_validation_result_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id),

        CONSTRAINT FK_dq_validation_result_rule
            FOREIGN KEY (validation_rule_id)
            REFERENCES dq.validation_rule(validation_rule_id),

        CONSTRAINT UQ_dq_validation_result
            UNIQUE (load_run_id, validation_rule_id)
    );

    PRINT 'Created dq.validation_result.';
END
ELSE
    PRINT 'dq.validation_result already exists.';
GO


IF OBJECT_ID('dq.issue_register', 'U') IS NULL
BEGIN
    CREATE TABLE dq.issue_register
    (
        issue_id              bigint IDENTITY(1,1) NOT NULL,
        validation_result_id  bigint               NOT NULL,

        source_entity         varchar(100)         NOT NULL,
        landing_row_id        bigint               NULL,
        source_file_name      nvarchar(260)        NOT NULL,
        source_row_number     bigint               NULL,
        business_key          nvarchar(200)        NULL,
        field_name            sysname              NULL,
        invalid_value         nvarchar(4000)       NULL,

        financial_impact      decimal(19,6)        NULL,
        issue_status          varchar(20)          NOT NULL
            CONSTRAINT DF_dq_issue_status
            DEFAULT 'OPEN',
        recommended_owner     nvarchar(100)        NULL,
        recommended_action    nvarchar(1000)       NULL,
        resolution_note       nvarchar(2000)       NULL,

        created_at_utc        datetime2(0)         NOT NULL
            CONSTRAINT DF_dq_issue_created
            DEFAULT SYSUTCDATETIME(),
        resolved_at_utc       datetime2(0)         NULL,

        CONSTRAINT PK_dq_issue_register
            PRIMARY KEY (issue_id),

        CONSTRAINT FK_dq_issue_validation_result
            FOREIGN KEY (validation_result_id)
            REFERENCES dq.validation_result(validation_result_id)
    );

    PRINT 'Created dq.issue_register.';
END
ELSE
    PRINT 'dq.issue_register already exists.';
GO



/* ============================================================
   7. Reconciliation
   ============================================================ */

IF OBJECT_ID('recon.costing_reconciliation', 'U') IS NULL
BEGIN
    CREATE TABLE recon.costing_reconciliation
    (
        reconciliation_id       bigint IDENTITY(1,1) NOT NULL,
        load_run_id              bigint               NOT NULL,

        reconciliation_level    varchar(30)          NOT NULL,
        reporting_month         date                 NOT NULL,
        facility                nvarchar(100)        NULL,
        cost_centre_id          varchar(30)          NULL,
        cost_pool_code          varchar(30)          NULL,
        cost_category           nvarchar(100)        NULL,

        gl_amount               decimal(19,6)        NOT NULL,
        direct_assigned_amount  decimal(19,6)        NOT NULL,
        indirect_allocated_amount decimal(19,6)      NOT NULL,
        overhead_allocated_amount decimal(19,6)      NOT NULL,
        unallocated_amount      decimal(19,6)        NOT NULL,
        excluded_amount         decimal(19,6)        NOT NULL,

        reconciliation_difference AS
        (
            gl_amount
            - direct_assigned_amount
            - indirect_allocated_amount
            - overhead_allocated_amount
            - unallocated_amount
            - excluded_amount
        )
        PERSISTED,

        reconciliation_status   varchar(20)          NOT NULL,
        checked_at_utc          datetime2(0)         NOT NULL
            CONSTRAINT DF_recon_costing_checked
            DEFAULT SYSUTCDATETIME(),
        review_note             nvarchar(2000)       NULL,

        CONSTRAINT PK_recon_costing_reconciliation
            PRIMARY KEY (reconciliation_id),

        CONSTRAINT FK_recon_costing_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id)
    );

    PRINT 'Created recon.costing_reconciliation.';
END
ELSE
    PRINT 'recon.costing_reconciliation already exists.';
GO



/* ============================================================
   8. Costing Tables

    costing.cost_pool
            ↓
    costing.encounter_driver: For this cost pool, which encounters are eligible to receive the cost, 
                              and how much driver activity did each encounter have?
            ↓
    stg.patient_encounter


    costing.cost_pool: says how much money exists in each pool.
            +
    costing.encounter_driver: says which encounters receive the pool and what driver units they have.
            ↓
    costing.indirect_cost_allocation: calculates the allocated dollar amount per encounter.
            ↓
    costing.patient_level_cost: summarises direct + indirect + unallocated/excluded logic into final encounter-level cost.
   ============================================================ */

IF OBJECT_ID('costing.cost_pool', 'U') IS NULL
BEGIN
    CREATE TABLE costing.cost_pool
    (
        cost_pool_id             bigint IDENTITY(1,1) NOT NULL,
        load_run_id              bigint               NOT NULL,
        reporting_month          date                 NOT NULL,
        facility                 nvarchar(100)        NOT NULL,
        cost_centre_id           varchar(30)          NOT NULL,
        natural_account          varchar(20)          NOT NULL,
        cost_pool_code           varchar(30)          NOT NULL,
        cost_category            nvarchar(100)        NOT NULL,
        costing_treatment        varchar(20)          NOT NULL,
        allocation_driver        varchar(50)          NOT NULL,

        source_transaction_count bigint               NOT NULL,
        source_gl_amount         decimal(19,6)        NOT NULL,

        pool_status              varchar(20)          NOT NULL
            CONSTRAINT DF_cost_pool_status
            DEFAULT 'PENDING',

        created_at_utc           datetime2(0)         NOT NULL
            CONSTRAINT DF_cost_pool_created
            DEFAULT SYSUTCDATETIME(),

        review_note              nvarchar(2000)       NULL,

        CONSTRAINT PK_cost_pool
            PRIMARY KEY (cost_pool_id),

        CONSTRAINT FK_cost_pool_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id),

        CONSTRAINT UQ_cost_pool_grain
            UNIQUE
            (
                load_run_id,
                reporting_month,
                facility,
                cost_centre_id,
                natural_account,
                cost_pool_code
            )
    );

    PRINT 'Created costing.cost_pool.';
END
ELSE
    PRINT 'costing.cost_pool already exists.';
GO


IF OBJECT_ID('costing.encounter_driver', 'U') IS NULL
BEGIN
    CREATE TABLE costing.encounter_driver
    (
        encounter_driver_id bigint IDENTITY(1,1) NOT NULL,
        load_run_id         bigint        NOT NULL,
        reporting_month     date          NOT NULL,
        encounter_id        varchar(20)   NOT NULL,
        cost_pool_code      varchar(30)   NOT NULL,
        allocation_driver   varchar(50)   NOT NULL,
        driver_units        decimal(19,6) NOT NULL,
        driver_status       varchar(20)   NOT NULL,
        created_at_utc datetime2(0) NOT NULL
            CONSTRAINT DF_costing_encounter_driver_created
            DEFAULT SYSUTCDATETIME(),
        review_note         nvarchar(4000) NULL,

        CONSTRAINT PK_costing_encounter_driver
            PRIMARY KEY CLUSTERED (encounter_driver_id),

        CONSTRAINT FK_encounter_driver_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id),

        CONSTRAINT FK_encounter_driver_patient_encounter
            FOREIGN KEY (load_run_id, encounter_id)
            REFERENCES stg.patient_encounter(load_run_id, encounter_id),

        CONSTRAINT CK_encounter_driver_driver_units_nonnegative
            CHECK (driver_units >= 0),

        CONSTRAINT CK_encounter_driver_status
            CHECK (driver_status IN ('VALID', 'EXCLUDED', 'REVIEW'))
    );
END;
GO



IF OBJECT_ID('costing.direct_cost_assignment', 'U') IS NULL
BEGIN
    CREATE TABLE costing.direct_cost_assignment
    (
        direct_cost_assignment_id bigint IDENTITY(1,1) NOT NULL,
        load_run_id               bigint        NOT NULL,
        direct_cost_id             varchar(20)   NOT NULL,
        encounter_id               varchar(20)   NOT NULL,
        service_month              date          NOT NULL,
        cost_centre_id             varchar(30)   NOT NULL,
        natural_account            varchar(20)   NOT NULL,
        direct_cost_type           nvarchar(200) NOT NULL,
        quantity                   int           NOT NULL,
        assigned_amount            decimal(19,6) NOT NULL,
        assignment_status          varchar(20)   NOT NULL,
        created_at_utc datetime2(0) NOT NULL
            CONSTRAINT DF_costing_direct_cost_assignment_created
            DEFAULT SYSUTCDATETIME(),
        review_note                nvarchar(4000) NULL,

        CONSTRAINT PK_costing_direct_cost_assignment
            PRIMARY KEY CLUSTERED (direct_cost_assignment_id),

        CONSTRAINT FK_direct_cost_assignment_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id),

        CONSTRAINT FK_direct_cost_assignment_direct_cost
            FOREIGN KEY (load_run_id, direct_cost_id)
            REFERENCES stg.direct_cost_detail(load_run_id, direct_cost_id),

        CONSTRAINT FK_direct_cost_assignment_patient_encounter
            FOREIGN KEY (load_run_id, encounter_id)
            REFERENCES stg.patient_encounter(load_run_id, encounter_id),

        CONSTRAINT CK_direct_cost_assignment_quantity_nonnegative
            CHECK (quantity >= 0),

        CONSTRAINT CK_direct_cost_assignment_status
            CHECK (assignment_status IN ('ASSIGNED', 'REVIEW'))
    );
END;
GO


--EXEC sp_help 'costing.encounter_driver';
--EXEC sp_help 'costing.direct_cost_assignment';

/*
    Valid direct cost
        → costing.direct_cost_assignment
        → costing.patient_level_cost

    Failed direct cost
        → costing.unallocated_cost
        → reconciliation remains visible
    
*/



IF OBJECT_ID('costing.indirect_cost_allocation', 'U') IS NULL
BEGIN
    CREATE TABLE costing.indirect_cost_allocation
    (
        indirect_cost_allocation_id bigint IDENTITY(1,1) NOT NULL,
        load_run_id                 bigint        NOT NULL,
        cost_pool_id                bigint        NOT NULL,
        encounter_driver_id         bigint        NOT NULL,
        reporting_month             date          NOT NULL,
        encounter_id                varchar(20)   NOT NULL,
        cost_pool_code              varchar(30)   NOT NULL,
        allocation_driver           varchar(50)   NOT NULL,
        encounter_driver_units      decimal(19,6) NOT NULL,
        total_driver_units          decimal(19,6) NOT NULL,
        allocation_rate             decimal(19,6) NOT NULL,
        allocated_amount            decimal(19,6) NOT NULL,
        allocation_status           varchar(20)   NOT NULL,
        created_at_utc              datetime2(0)  NOT NULL
            CONSTRAINT DF_costing_indirect_cost_allocation_created
            DEFAULT SYSUTCDATETIME(),
        review_note                 nvarchar(4000) NULL,

        CONSTRAINT PK_costing_indirect_cost_allocation
            PRIMARY KEY CLUSTERED (indirect_cost_allocation_id),

        CONSTRAINT FK_indirect_cost_allocation_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id),

        CONSTRAINT FK_indirect_cost_allocation_cost_pool
            FOREIGN KEY (cost_pool_id)
            REFERENCES costing.cost_pool(cost_pool_id),

        CONSTRAINT FK_indirect_cost_allocation_encounter_driver
            FOREIGN KEY (encounter_driver_id)
            REFERENCES costing.encounter_driver(encounter_driver_id),

        CONSTRAINT FK_indirect_cost_allocation_patient_encounter
            FOREIGN KEY (load_run_id, encounter_id)
            REFERENCES stg.patient_encounter(load_run_id, encounter_id),

        CONSTRAINT CK_indirect_cost_allocation_driver_units_nonnegative
            CHECK (encounter_driver_units >= 0 AND total_driver_units > 0),

        CONSTRAINT CK_indirect_cost_allocation_status
            CHECK (allocation_status IN ('ALLOCATED', 'REVIEW'))
    );
END;
GO



/*
costing.direct_cost_assignment
        +
costing.indirect_cost_allocation
        ↓
costing.patient_level_cost
*/

IF OBJECT_ID('costing.patient_level_cost', 'U') IS NULL
BEGIN
    CREATE TABLE costing.patient_level_cost
    (
        patient_level_cost_id      bigint IDENTITY(1,1) NOT NULL,
        load_run_id                bigint        NOT NULL,
        reporting_month            date          NOT NULL,
        encounter_id               varchar(20)   NOT NULL,

        facility                   nvarchar(100) NOT NULL,
        service_line               nvarchar(100) NOT NULL,
        care_type                  varchar(30)   NOT NULL,
        activity_group_code        varchar(30)   NOT NULL,

        direct_cost_amount         decimal(19,6) NOT NULL,
        indirect_cost_amount       decimal(19,6) NOT NULL,
        overhead_cost_amount       decimal(19,6) NOT NULL,
        total_patient_cost         AS
        (
            direct_cost_amount
            + indirect_cost_amount
            + overhead_cost_amount
        )
        PERSISTED,

        cost_status                varchar(20)   NOT NULL,
        high_cost_flag             char(1)       NOT NULL,
        created_at_utc             datetime2(0)  NOT NULL
            CONSTRAINT DF_costing_patient_level_cost_created
            DEFAULT SYSUTCDATETIME(),
        review_note                nvarchar(4000) NULL,

        CONSTRAINT PK_costing_patient_level_cost
            PRIMARY KEY CLUSTERED (patient_level_cost_id),

        CONSTRAINT FK_patient_level_cost_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id),

        CONSTRAINT FK_patient_level_cost_patient_encounter
            FOREIGN KEY (load_run_id, encounter_id)
            REFERENCES stg.patient_encounter(load_run_id, encounter_id),

        CONSTRAINT UQ_patient_level_cost_grain
            UNIQUE (load_run_id, reporting_month, encounter_id),

        CONSTRAINT CK_patient_level_cost_status
            CHECK (cost_status IN ('FINAL', 'REVIEW')),

        CONSTRAINT CK_patient_level_cost_high_cost_flag
            CHECK (high_cost_flag IN ('Y', 'N'))
    );
END;
GO

/*
GL amount
= direct assigned
+ indirect allocated
+ overhead allocated
+ unallocated
+ excluded
+ reconciliation difference
*/
IF OBJECT_ID('costing.unallocated_cost', 'U') IS NULL
BEGIN
    CREATE TABLE costing.unallocated_cost
    (
        unallocated_cost_id      bigint IDENTITY(1,1) NOT NULL,
        load_run_id              bigint        NOT NULL,
        reporting_month          date          NOT NULL,
        facility                 nvarchar(100) NULL,
        cost_centre_id           varchar(30)   NULL,
        natural_account          varchar(20)   NULL,
        cost_pool_id             bigint        NULL,
        cost_pool_code           varchar(30)   NULL,
        cost_category            nvarchar(100) NULL,

        unallocated_reason       varchar(50)   NOT NULL,
        unallocated_amount       decimal(19,6) NOT NULL,
        source_record_type       varchar(50)   NOT NULL,
        source_record_id         varchar(30)   NULL,

        resolution_status        varchar(20)   NOT NULL,
        created_at_utc           datetime2(0)  NOT NULL
            CONSTRAINT DF_costing_unallocated_cost_created
            DEFAULT SYSUTCDATETIME(),
        review_note              nvarchar(4000) NULL,

        CONSTRAINT PK_costing_unallocated_cost
            PRIMARY KEY CLUSTERED (unallocated_cost_id),

        CONSTRAINT FK_unallocated_cost_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id),

        CONSTRAINT FK_unallocated_cost_cost_pool
            FOREIGN KEY (cost_pool_id)
            REFERENCES costing.cost_pool(cost_pool_id),

        CONSTRAINT CK_unallocated_cost_reason
            CHECK
            (
                unallocated_reason IN
                (
                    'UNMAPPED_COST_CENTRE',
                    'UNMAPPED_ACCOUNT',
                    'ZERO_DRIVER_POOL',
                    'FAILED_DIRECT_ASSIGNMENT',
                    'EXCLUDED_ADJUSTMENT',
                    'REVIEW'
                )
            ),

        CONSTRAINT CK_unallocated_cost_source_type
            CHECK
            (
                source_record_type IN
                (
                    'GL_TRANSACTION',
                    'COST_POOL',
                    'DIRECT_COST',
                    'ALLOCATION'
                )
            ),

        CONSTRAINT CK_unallocated_cost_resolution_status
            CHECK (resolution_status IN ('OPEN', 'REVIEWED', 'EXCLUDED', 'RESOLVED'))
    );
END;
GO


/*
costing.patient_level_cost
        +
ref.abf_activity_group
        ↓
costing.abf_comparison
        ↓
reporting.vw_fact_abf_comparison
        ↓
Excel ABF Cost vs Funding sheet
*/

IF OBJECT_ID('costing.abf_comparison', 'U') IS NULL
BEGIN
    CREATE TABLE costing.abf_comparison
    (
        abf_comparison_id         bigint IDENTITY(1,1) NOT NULL,
        load_run_id               bigint        NOT NULL,
        reporting_month           date          NOT NULL,
        encounter_id              varchar(20)   NOT NULL,

        facility                  nvarchar(100) NOT NULL,
        service_line              nvarchar(100) NOT NULL,
        care_type                 varchar(30)   NOT NULL,
        activity_group_code       varchar(30)   NOT NULL,

        total_patient_cost        decimal(19,6) NOT NULL,
        synthetic_base_weight     decimal(12,6) NULL,
        synthetic_adjustment_factor decimal(12,6) NULL,
        synthetic_nwau            decimal(19,6) NULL,
        synthetic_funding_amount  decimal(19,6) NULL,

        cost_funding_variance AS
        (
            total_patient_cost - synthetic_funding_amount
        )
        PERSISTED,

        funding_status            varchar(30)   NOT NULL,
        created_at_utc            datetime2(0)  NOT NULL
            CONSTRAINT DF_costing_abf_comparison_created
            DEFAULT SYSUTCDATETIME(),
        review_note               nvarchar(4000) NULL,

        CONSTRAINT PK_costing_abf_comparison
            PRIMARY KEY CLUSTERED (abf_comparison_id),

        CONSTRAINT FK_abf_comparison_load_run
            FOREIGN KEY (load_run_id)
            REFERENCES dq.load_run(load_run_id),

        CONSTRAINT FK_abf_comparison_patient_level_cost
            FOREIGN KEY (load_run_id, reporting_month, encounter_id)
            REFERENCES costing.patient_level_cost(load_run_id, reporting_month, encounter_id),

        CONSTRAINT UQ_abf_comparison_grain
            UNIQUE (load_run_id, reporting_month, encounter_id),

        CONSTRAINT CK_abf_comparison_status
            CHECK (funding_status IN ('FUNDED', 'UNFUNDED_REVIEW', 'REVIEW'))
    );
END;
GO
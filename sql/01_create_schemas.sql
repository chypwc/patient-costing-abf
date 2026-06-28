USE CostAnalysisABF;
GO

-- Exact CSV landing values stored as text before validation
IF SCHEMA_ID(N'landing') IS NULL
    EXEC(N'CREATE SCHEMA landing AUTHORIZATION dbo;');

-- Validated and typed transactional data
IF SCHEMA_ID(N'stg') IS NULL
    EXEC(N'CREATE SCHEMA stg AUTHORIZATION dbo;');

-- Validated and typed mappings and business rules
IF SCHEMA_ID(N'ref') IS NULL
    EXEC(N'CREATE SCHEMA ref AUTHORIZATION dbo;');

-- Load audit, source controls, validation rules and data-quality issues
IF SCHEMA_ID(N'dq') IS NULL
    EXEC(N'CREATE SCHEMA dq AUTHORIZATION dbo;');

-- Cost pools, drivers, allocations and patient-level cost
IF SCHEMA_ID(N'costing') IS NULL
    EXEC(N'CREATE SCHEMA costing AUTHORIZATION dbo;');

-- Source financial controls and GL-to-costing reconciliation.
-- TOTAL rows prove whole-run control; COST_POOL rows support Excel slicing
-- by reporting month, facility, cost centre, cost pool and cost category.
IF SCHEMA_ID(N'recon') IS NULL
    EXEC(N'CREATE SCHEMA recon AUTHORIZATION dbo;');

-- Excel-ready reporting views
IF SCHEMA_ID(N'reporting') IS NULL
    EXEC(N'CREATE SCHEMA reporting AUTHORIZATION dbo;');
GO

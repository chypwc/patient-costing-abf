USE master;
GO

IF DB_ID(N'CostAnalysisABF') IS NULL
BEGIN
    CREATE DATABASE CostAnalysisABF;
    PRINT 'Created CostAnalysisABF.';
END
ELSE
    PRINT 'CostAnalysisABF already exists.';
GO
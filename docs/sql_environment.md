# SQL Server Environment

## Confirmed Environment

- Server name: `Eigen`
- SQL Server: Microsoft SQL Server 2025
- Version: `17.0.1115.1`
- Edition: Enterprise Developer Edition (64-bit)
- Host operating system: Windows 10 Home, build 26200
- Database: `CostAnalysisABF`

The SQL Server service can read the configured batch-load folder. The
`xp_fileexist` preflight returned:

```text
File Exists = 1
File is a Directory = 0
Parent Directory Exists = 1
```

## Confirmed Schemas

- `landing`
- `stg`
- `ref`
- `dq`
- `costing`
- `recon`
- `reporting`

## Compatibility Assumptions

- SQL Server 2025 supports the planned `BULK INSERT` CSV options.
- SSMS is used to execute and review the SQL scripts; no feature in the current
  design depends on a specific SSMS version.
- The SQL Server service account must retain read access to the batch-load
  folder.
- File paths used by `BULK INSERT` refer to the machine hosting SQL Server.

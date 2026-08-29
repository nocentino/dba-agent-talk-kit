#!/usr/bin/env bash
# Bonus demo seed: stale statistics + fragmented index + a failing SQL Agent job.
# Targets sqlserver3 (the "maintenance neglect" fleet member).
set -euo pipefail
source ../../.env 2>/dev/null || true
# Compose file lives in compose/; point docker compose at it + the root .env.
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"
export COMPOSE_ENV_FILES="$_ROOT/.env"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"

echo "1/3 Creating ReportingDB with a churn table..."
docker compose exec sqlserver3 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
IF DB_ID('ReportingDB') IS NULL CREATE DATABASE [ReportingDB];"
docker compose exec sqlserver3 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d ReportingDB -Q "
-- dba_monitor needs a per-database user here too (VIEW ANY DATABASE at the
-- server level only covers sys.databases metadata, not an actual CONNECT).
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'dba_monitor')
  CREATE USER dba_monitor FOR LOGIN dba_monitor;
GRANT VIEW DATABASE STATE TO dba_monitor;
GRANT VIEW DEFINITION     TO dba_monitor;
GRANT SELECT ON SCHEMA::dbo TO dba_monitor;
IF OBJECT_ID('dbo.DailyMetrics') IS NULL
BEGIN
  CREATE TABLE dbo.DailyMetrics (
    ID INT IDENTITY PRIMARY KEY,
    MetricDate DATE,
    MetricValue DECIMAL(10,2),
    Region VARCHAR(20)
  );
  CREATE INDEX IX_DailyMetrics_Region ON dbo.DailyMetrics(Region);
  INSERT INTO dbo.DailyMetrics (MetricDate, MetricValue, Region)
  SELECT TOP (20000) CAST(GETDATE() AS DATE), (ABS(CHECKSUM(NEWID())) % 1000),
    CASE ABS(CHECKSUM(NEWID())) % 4 WHEN 0 THEN 'East' WHEN 1 THEN 'West' WHEN 2 THEN 'North' ELSE 'South' END
  FROM sys.all_objects a CROSS JOIN sys.all_objects b;
END;"

echo "2/3 Fragmenting the index and going stale on statistics (no UPDATE STATISTICS after)..."
docker compose exec sqlserver3 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d ReportingDB -Q "
SET NOCOUNT ON;
-- Random deletes + re-inserts fragment the index and skew row-modification counters
-- without ever triggering a stats refresh in this same batch.
DELETE TOP (8000) FROM dbo.DailyMetrics WHERE ID % 3 = 0;
INSERT INTO dbo.DailyMetrics (MetricDate, MetricValue, Region)
SELECT TOP (8000) CAST(GETDATE() AS DATE), (ABS(CHECKSUM(NEWID())) % 1000),
  CASE ABS(CHECKSUM(NEWID())) % 4 WHEN 0 THEN 'East' WHEN 1 THEN 'West' WHEN 2 THEN 'North' ELSE 'South' END
FROM sys.all_objects a CROSS JOIN sys.all_objects b;"

echo "3/3 Creating a SQL Agent job that fails (references a table that doesn't exist)..."
docker compose exec sqlserver3 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
USE msdb;
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'Nightly_Report_Refresh')
BEGIN
  EXEC dbo.sp_add_job @job_name = N'Nightly_Report_Refresh', @enabled = 1;
  EXEC dbo.sp_add_jobstep @job_name = N'Nightly_Report_Refresh',
    @step_name = N'Refresh summary table',
    @subsystem = N'TSQL',
    @command = N'USE ReportingDB; SELECT * INTO dbo.Summary_Staging FROM dbo.RegionSummary_DOES_NOT_EXIST;',
    @database_name = N'ReportingDB';
  EXEC dbo.sp_add_jobserver @job_name = N'Nightly_Report_Refresh', @server_name = N'(local)';
END;
-- Run it now so a real failure lands in job history.
EXEC msdb.dbo.sp_start_job @job_name = N'Nightly_Report_Refresh';"

echo "Maintenance-neglect scenario seeded on sqlserver3 (job history takes a few seconds to land)."

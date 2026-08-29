#!/usr/bin/env bash
# Removes everything seed-maintenance-neglect.sh created on sqlserver3.
set -euo pipefail
source ../../.env 2>/dev/null || true
# Compose file lives in compose/; point docker compose at it + the root .env.
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"
export COMPOSE_ENV_FILES="$_ROOT/.env"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"

docker compose exec sqlserver3 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
USE msdb;
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'Nightly_Report_Refresh')
  EXEC dbo.sp_delete_job @job_name = N'Nightly_Report_Refresh';
USE master;
ALTER DATABASE [ReportingDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE IF EXISTS [ReportingDB];"

echo "Maintenance-neglect demo reset: ReportingDB and the job removed."

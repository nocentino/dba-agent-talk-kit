#!/usr/bin/env bash
# Reverts everything seed-security-issues.sh created.
set -euo pipefail
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_ROOT/.env" 2>/dev/null || true
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"
export COMPOSE_ENV_FILES="$_ROOT/.env"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"

docker compose exec sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d ProductsDB -Q "
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'temp_migration_login')
  DROP USER temp_migration_login;"
docker compose exec sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'svc_reporting')
  DROP LOGIN svc_reporting;
EXEC sp_configure 'clr enabled', 0; RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 0; RECONFIGURE;
EXEC sp_configure 'show advanced options', 0; RECONFIGURE;"

echo "Security demo reset: config restored, rogue login and orphaned user removed."

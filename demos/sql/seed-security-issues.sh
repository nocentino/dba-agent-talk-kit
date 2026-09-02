#!/usr/bin/env bash
# Demo 5 seed: config drift + rogue sysadmin + orphaned user + failed-login spray.
set -euo pipefail
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_ROOT/.env" 2>/dev/null || true
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"
export COMPOSE_ENV_FILES="$_ROOT/.env"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"

echo "1/4 Config drift: enabling clr enabled + Ad Hoc Distributed Queries..."
docker compose exec sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
EXEC sp_configure 'show advanced options', 1; RECONFIGURE;
EXEC sp_configure 'clr enabled', 1; RECONFIGURE;
EXEC sp_configure 'Ad Hoc Distributed Queries', 1; RECONFIGURE;"

echo "2/4 Privileged access: adding a rogue sysadmin login (svc_reporting)..."
docker compose exec sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'svc_reporting')
  CREATE LOGIN svc_reporting WITH PASSWORD = N'R3porting!2026', CHECK_POLICY = OFF;
ALTER SERVER ROLE sysadmin ADD MEMBER svc_reporting;"

echo "3/4 Orphaned user: creating a ProductsDB user, then dropping its login..."
docker compose exec sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'temp_migration_login')
  CREATE LOGIN temp_migration_login WITH PASSWORD = N'Migrate!2026', CHECK_POLICY = OFF;"
docker compose exec sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d ProductsDB -Q "
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'temp_migration_login')
  CREATE USER temp_migration_login FOR LOGIN temp_migration_login;"
docker compose exec sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
DROP LOGIN temp_migration_login;"

echo "4/4 Failed logins: generating a spray pattern in the error log..."
for i in 1 2 3 4 5; do
  docker compose exec sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U sa -P "WrongPassword${i}!" -C -Q "SELECT 1" >/dev/null 2>&1 || true
done
for i in 1 2 3; do
  docker compose exec sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U admin_probe -P "TryMe${i}!" -C -Q "SELECT 1" >/dev/null 2>&1 || true
done

echo ""
echo "✓ Security findings seeded."
echo "  - SEC-001: Config drift (CLR enabled + Ad Hoc Distributed Queries)"
echo "  - SEC-002: Privileged access (svc_reporting added to sysadmin)"
echo "  - SEC-003: Orphaned user (temp_migration_login without server login)"
echo "  - SEC-004: Failed login spray (10+ failed attempts from known pattern)"
echo "  Run query: security_audit() or similar on SqlServer1"

#!/usr/bin/env bash
# Bonus demo seed: a real deadlock (captured in system_health XE) + tempdb
# pressure. Targets sqlserver4 (the "deadlocks & tempdb" fleet member).
set -euo pipefail
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_ROOT/.env" 2>/dev/null || true
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"
export COMPOSE_ENV_FILES="$_ROOT/.env"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"

echo "Seeding deadlock + tempdb scenario..."
echo "[1/2] Setting up two tables for a classic opposite-order-update deadlock..."
docker compose exec sqlserver4 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
IF DB_ID('DeadlockDemoDB') IS NULL CREATE DATABASE [DeadlockDemoDB];"
docker compose exec sqlserver4 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d DeadlockDemoDB -Q "
IF OBJECT_ID('dbo.TableA') IS NULL
BEGIN
  CREATE TABLE dbo.TableA (ID INT PRIMARY KEY, Val INT);
  CREATE TABLE dbo.TableB (ID INT PRIMARY KEY, Val INT);
  INSERT INTO dbo.TableA VALUES (1, 100);
  INSERT INTO dbo.TableB VALUES (1, 200);
END;"

echo "[2/2] Firing two sessions in opposite lock order (one will be the deadlock victim)..."
docker compose exec -d sqlserver4 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d DeadlockDemoDB -Q "
BEGIN TRANSACTION;
UPDATE dbo.TableA SET Val = Val + 1 WHERE ID = 1;
WAITFOR DELAY '00:00:03';
UPDATE dbo.TableB SET Val = Val + 1 WHERE ID = 1;
COMMIT;"

docker compose exec sqlserver4 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d DeadlockDemoDB -Q "
BEGIN TRANSACTION;
UPDATE dbo.TableB SET Val = Val + 1 WHERE ID = 1;
WAITFOR DELAY '00:00:03';
UPDATE dbo.TableA SET Val = Val + 1 WHERE ID = 1;
COMMIT;" || true

echo ""
echo "✓ Deadlock + tempdb load seeded."
echo "  - Deadlock trigger: Two sessions updating TableA/TableB in opposite order"
echo "  - Tempdb pressure: Large sorted temp table created (#bigsort, 30s hold)"
echo "  - Check system_health XE for deadlock graph"
echo "  Run query: get_deadlock_history() on SqlServer4"
docker compose exec -d sqlserver4 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
SET NOCOUNT ON;
SELECT a.name AS name_a, b.name AS name_b INTO #bigsort FROM sys.all_objects a CROSS JOIN sys.all_objects b
ORDER BY NEWID();
WAITFOR DELAY '00:00:30';
DROP TABLE #bigsort;"

echo "Deadlock + tempdb scenario seeded on sqlserver4 (deadlock lands in system_health XE in a few seconds)."

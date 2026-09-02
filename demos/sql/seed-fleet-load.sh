#!/usr/bin/env bash
set -euo pipefail
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_ROOT/.env" 2>/dev/null || true
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"
export COMPOSE_ENV_FILES="$_ROOT/.env"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"

echo "Seeding fleet-wide load scenario..."
echo "[1/2] Starting IO + CPU pressure on SqlServer1..."
# SqlServer1: IO + CPU pressure
docker compose exec -d sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d ProductsDB -Q "
SET NOCOUNT ON;
DECLARE @i INT = 0;
WHILE @i < 500
BEGIN
  DBCC DROPCLEANBUFFERS;
  SELECT COUNT_BIG(*) FROM dbo.OrderDetails od
    JOIN dbo.Orders o ON o.OrderID = od.OrderID
    JOIN dbo.Products p ON p.ProductID = od.ProductID
  OPTION (MAXDOP 4);
  SET @i += 1;
END;" > /dev/null 2>&1
echo "      ✓ SqlServer1 load started (background)"

echo "[2/2] Starting slow-client ASYNC_NETWORK_IO on SqlServer2..."
# SqlServer2: ASYNC_NETWORK_IO via a slow-drinking client
docker compose exec sqlserver2 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
SELECT a.* FROM sys.all_objects a CROSS JOIN sys.all_objects b;" \
  | while read -r line; do sleep 0.01; done &
echo "      ✓ SqlServer2 slow client started (background)"

echo ""
echo "✓ Fleet load seeded and running in background."
echo "  - SqlServer1: IO + CPU pressure (joins + DROPCLEANBUFFERS loops)"
echo "  - SqlServer2: Simulating slow client (ASYNC_NETWORK_IO)"
echo "  Recommendation: Wait 2-3 minutes for wait stats to accumulate."
echo "  Run query: get_wait_stats() or get_top_queries() on SqlServer1/2"
echo "✓ Fleet load seeded and running in background."
echo "  - SqlServer1: IO + CPU pressure (joins + DROPCLEANBUFFERS loops)"
echo "  - SqlServer2: Simulating slow client (ASYNC_NETWORK_IO)"
echo "  Recommendation: Wait 2-3 minutes for wait stats to accumulate."
echo "  Run query: get_wait_stats() or get_top_queries() on SqlServer1/2"

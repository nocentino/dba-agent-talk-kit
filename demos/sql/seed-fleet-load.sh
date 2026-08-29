#!/usr/bin/env bash
set -euo pipefail
source ../../.env 2>/dev/null || true
# Compose file lives in compose/; point docker compose at it + the root .env.
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"
export COMPOSE_ENV_FILES="$_ROOT/.env"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"

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
END;"

# SqlServer2: ASYNC_NETWORK_IO via a slow-drinking client
docker compose exec sqlserver2 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
SELECT a.* FROM sys.all_objects a CROSS JOIN sys.all_objects b;" \
  | while read -r line; do sleep 0.01; done &
echo "Fleet load running. Give it 2-3 minutes to accumulate wait history."

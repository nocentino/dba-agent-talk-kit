#!/usr/bin/env bash
set -euo pipefail
source ../../.env 2>/dev/null || true
# Compose file lives in compose/; point docker compose at it + the root .env.
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"
export COMPOSE_ENV_FILES="$_ROOT/.env"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"

# Head blocker: open txn + WAITFOR (X lock held on Electronics rows)
docker compose exec -d sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d ProductsDB -Q "
BEGIN TRANSACTION;
UPDATE dbo.Products SET UnitPrice = UnitPrice * 1.01 WHERE Category = 'Electronics';
WAITFOR DELAY '00:08:00';
ROLLBACK;"

sleep 2

# Victim: SELECT queued behind the X lock
docker compose exec -d sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d ProductsDB -Q "
SELECT ProductID, ProductName, UnitPrice
FROM dbo.Products WHERE Category = 'Electronics';"

# Optional third victim via DAB REST
curl -s "http://localhost:5001/api/Products?\$filter=Category eq 'Electronics'" \
  --max-time 300 > /dev/null &
echo "Blocking scenario seeded. WAITFOR expires in 8 minutes."

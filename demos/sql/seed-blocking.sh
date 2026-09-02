#!/usr/bin/env bash
set -euo pipefail
# Compose file lives in compose/; point docker compose at it + the root .env.
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_ROOT/.env" 2>/dev/null || true
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"
export COMPOSE_ENV_FILES="$_ROOT/.env"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"

# Create blocker SQL script in temp location
cat > /tmp/blocker.sql << 'EOSQL'
BEGIN TRANSACTION;
UPDATE dbo.Products SET UnitPrice = UnitPrice * 1.01 WHERE Category = 'Electronics';
WAITFOR DELAY '00:08:00';
ROLLBACK;
EOSQL

# Create victim SELECT script
cat > /tmp/victim.sql << 'EOSQL'
SELECT ProductID, ProductName, UnitPrice
FROM dbo.Products WHERE Category = 'Electronics' ORDER BY ProductID;
EOSQL

# Head blocker: open txn + WAITFOR (X lock held on Electronics rows)
echo "[1/3] Starting blocker session (8-min WAITFOR)..."
docker compose cp /tmp/blocker.sql sqlserver1:/tmp/blocker.sql
docker compose exec -d sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d ProductsDB -i /tmp/blocker.sql
echo "      ✓ Blocker session started."

sleep 2

# Victim: SELECT queued behind the X lock
echo "[2/3] Starting first victim (sa SELECT)..."
docker compose cp /tmp/victim.sql sqlserver1:/tmp/victim.sql
docker compose exec -d sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d ProductsDB -i /tmp/victim.sql
echo "      ✓ First victim blocked."

sleep 1

# Optional third victim via DAB REST
echo "[3/3] Starting DAB REST scan (optional third victim)..."
curl -s "http://localhost:5001/api/Products?\$filter=Category eq 'Electronics'" \
  --max-time 300 > /dev/null &
echo "      ✓ DAB scan initiated."

echo ""
echo "✓ Blocking scenario seeded. Chain: blocker (8 min) → victim 1 → victim 2."
echo "  Run query: get_blocking_chains('SqlServer1')"

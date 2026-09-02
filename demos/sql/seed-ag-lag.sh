#!/usr/bin/env bash
set -euo pipefail
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_ROOT/.env" 2>/dev/null || true
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"
export COMPOSE_ENV_FILES="$_ROOT/.env"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"

# 1. Wait for ProductsDB to be seeded to the secondary
echo "[1/3] Waiting for ProductsDB to be seeded to secondary (SqlServer2)..."
max_retries=30
retry=0
while [ $retry -lt $max_retries ]; do
  if docker compose exec -T sqlserver2 /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U sa -P "$SA_PASSWORD" -C -b -Q "SELECT name FROM sys.databases WHERE name = 'ProductsDB'" 2>/dev/null | grep -iq "ProductsDB"; then
    echo "      ✓ Database seeded to secondary."
    break
  fi
  retry=$((retry + 1))
  if [ $retry -lt $max_retries ]; then
    sleep 1
  fi
done

if [ $retry -eq $max_retries ]; then
  echo "❌ Timeout waiting for ProductsDB to seed to secondary"
  exit 1
fi

# 2. Suspend data movement on the secondary
echo "[2/3] Suspending data movement on secondary (SqlServer2)..."
docker compose exec sqlserver2 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
ALTER DATABASE [ProductsDB] SET HADR SUSPEND;"
echo "      ✓ Secondary SUSPENDED."

# 3. Generate aggressive log churn on the primary so the send queue grows
echo "[3/3] Generating high-volume log churn on primary (SqlServer1)..."
docker compose exec -d sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d ProductsDB -Q "
SET NOCOUNT ON;
DECLARE @i INT = 0;
WHILE @i < 10000
BEGIN
  UPDATE dbo.Products SET UnitPrice = UnitPrice + 0.01, UnitsInStock = UnitsInStock + 1;
  UPDATE dbo.OrderDetails SET Quantity = Quantity + 1;
  SET @i += 1;
END;"
echo "      ✓ Log generation started (high volume update loop)."

echo ""
echo "✓ AG lag seeded. Send queue growing on primary due to suspended secondary."
echo "  Run query: get_ag_health() on primary"

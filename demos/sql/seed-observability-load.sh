#!/usr/bin/env bash
# Demo 6 seed: a few representative queries so get_top_queries and
# get_missing_indexes have real plan-cache data to report on. Fast (~10s),
# unlike seed-fleet-load.sh which is built to run for minutes.
set -euo pipefail
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_ROOT/.env" 2>/dev/null || true
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"
export COMPOSE_ENV_FILES="$_ROOT/.env"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"

echo "Loading ~20k filler rows with skewed category distribution..."
docker compose exec sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d ProductsDB -Q "
SET NOCOUNT ON;
-- Bulk up Products so a Category scan is costly enough for the optimizer to
-- actually recommend an index. Skew the distribution so 'Electronics' is a
-- small, selective slice (~3%) of a 20k-row table -- a 25/25/25/25 split
-- is common enough that a scan is legitimately as cheap as a seek, and the
-- optimizer correctly won't recommend an index for it.
IF NOT EXISTS (SELECT 1 FROM dbo.Products WHERE ProductName = 'LoadTestFiller-1')
BEGIN
  INSERT INTO dbo.Products (ProductName, Category, UnitPrice, UnitsInStock, Discontinued)
  SELECT TOP (20000)
    'LoadTestFiller-' + CAST(ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS VARCHAR(10)),
    CASE WHEN ABS(CHECKSUM(NEWID())) % 100 < 3 THEN 'Electronics'
         WHEN ABS(CHECKSUM(NEWID())) % 3 = 0 THEN 'Furniture'
         WHEN ABS(CHECKSUM(NEWID())) % 3 = 1 THEN 'Office Supplies'
         ELSE 'Appliances' END,
    (ABS(CHECKSUM(NEWID())) % 500) + 1.00,
    ABS(CHECKSUM(NEWID())) % 200,
    0
  FROM sys.all_objects a CROSS JOIN sys.all_objects b;
END;

DECLARE @i INT = 0;
WHILE @i < 30
BEGIN
  -- Category has no index: forces a scan on every call, the classic missing-index case.
  SELECT COUNT(*), MAX(UnitPrice) FROM dbo.Products WHERE Category = 'Electronics' AND Discontinued = 0;
  SELECT p.ProductName, od.Quantity FROM dbo.OrderDetails od
    JOIN dbo.Products p ON p.ProductID = od.ProductID
    JOIN dbo.Orders o ON o.OrderID = od.OrderID
  WHERE p.UnitsInStock < 50 AND p.UnitPrice > 20;
  SET @i += 1;
END;" > /dev/null 2>&1

echo "✓ Data load complete."
echo ""
echo "✓ Observability load seeded."
echo "  - ~20k filler rows added (Electronics ~3% of population)"
echo "  - Category scan activity completed (no index = full table scan)"
echo "  - Plan cache populated with missing-index candidates"
echo "  Run query: get_missing_indexes() or get_top_queries() on SqlServer1"

#!/usr/bin/env bash
set -euo pipefail
source ../../.env 2>/dev/null || true
# Compose file lives in compose/; point docker compose at it + the root .env.
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"
export COMPOSE_ENV_FILES="$_ROOT/.env"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"

# 1. Suspend data movement on the secondary
docker compose exec sqlserver2 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
ALTER DATABASE [ProductsDB] SET HADR SUSPEND;"

# 2. Generate log on the primary so the send queue grows
docker compose exec -d sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d ProductsDB -Q "
SET NOCOUNT ON;
DECLARE @i INT = 0;
WHILE @i < 2000
BEGIN
  UPDATE dbo.Products SET UnitsInStock = UnitsInStock WHERE ProductID % 5 = @i % 5;
  SET @i += 1;
END;"
echo "AG lag seeded: secondary SUSPENDED, log generating on primary."

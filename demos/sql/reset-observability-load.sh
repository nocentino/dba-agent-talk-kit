#!/usr/bin/env bash
# Removes the synthetic filler rows seed-observability-load.sh inserted.
set -euo pipefail
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_ROOT/.env" 2>/dev/null || true
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"
export COMPOSE_ENV_FILES="$_ROOT/.env"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"

docker compose exec sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d ProductsDB -Q "
DELETE FROM dbo.Products WHERE ProductName LIKE 'LoadTestFiller-%';"

echo "Observability demo reset: filler rows removed."

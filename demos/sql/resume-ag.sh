#!/usr/bin/env bash
set -euo pipefail
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_ROOT/.env" 2>/dev/null || true
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"
export COMPOSE_ENV_FILES="$_ROOT/.env"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"

echo "Resuming data movement on secondary (SqlServer2)..."
docker compose exec sqlserver2 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
ALTER DATABASE [ProductsDB] SET HADR RESUME;"
echo "✓ Data movement resumed. Secondary catching up..."

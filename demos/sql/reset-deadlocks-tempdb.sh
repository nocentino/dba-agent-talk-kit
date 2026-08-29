#!/usr/bin/env bash
# Removes DeadlockDemoDB. Deadlock history in system_health XE is a ring
# buffer and needs no cleanup; tempdb usage is transient and self-clears.
set -euo pipefail
source ../../.env 2>/dev/null || true
# Compose file lives in compose/; point docker compose at it + the root .env.
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"
export COMPOSE_ENV_FILES="$_ROOT/.env"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"

docker compose exec sqlserver4 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
ALTER DATABASE [DeadlockDemoDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
DROP DATABASE IF EXISTS [DeadlockDemoDB];"

echo "Deadlock demo reset: DeadlockDemoDB removed."

#!/usr/bin/env bash
set -euo pipefail
source ../../.env 2>/dev/null || true
# Compose file lives in compose/; point docker compose at it + the root .env.
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"
export COMPOSE_ENV_FILES="$_ROOT/.env"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"
docker compose exec sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
DECLARE @spid INT = (SELECT TOP 1 session_id FROM sys.dm_exec_requests
                     WHERE command = 'WAITFOR' AND session_id <> @@SPID);
IF @spid IS NOT NULL EXEC('KILL ' + @spid);"
echo "Blocker killed (if present)."

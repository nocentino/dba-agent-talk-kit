#!/usr/bin/env bash
set -euo pipefail
# Compose file lives in compose/; point docker compose at it + the root .env.
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$_ROOT/.env" 2>/dev/null || true
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"
export COMPOSE_ENV_FILES="$_ROOT/.env"
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"
docker compose exec sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "DECLARE @spid INT = (SELECT TOP 1 session_id FROM sys.dm_exec_requests WHERE command = 'WAITFOR' AND session_id > 50 AND session_id <> @@SPID); IF @spid IS NOT NULL BEGIN DECLARE @cmd NVARCHAR(50); SET @cmd = N'KILL ' + CONVERT(VARCHAR(10), @spid); EXEC sp_executesql @cmd; END;"
echo "Blocker killed (if present)."

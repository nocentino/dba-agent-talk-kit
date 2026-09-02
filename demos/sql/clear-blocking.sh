#!/usr/bin/env bash
set -euo pipefail

# Clear blocking sessions on SqlServer1 by killing any WAITFOR blocker
# Usage: ./clear-blocking.sh (run from demos/sql directory)

_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export COMPOSE_FILE="$_ROOT/compose/docker-compose.yml"

# Try to source .env
if [[ -f "$_ROOT/.env" ]]; then
  source "$_ROOT/.env"
fi

SA_PASSWORD="${SA_PASSWORD:?Error: SA_PASSWORD not set. Set it in .env or export SA_PASSWORD}"

echo "[Clearing] Blocking sessions on SqlServer1..."
echo "Finding WAITFOR blocker..."

# Find the WAITFOR blocker and kill it
docker compose exec sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
SET NOCOUNT ON;
DECLARE @sql NVARCHAR(MAX) = '';
DECLARE @spid INT = NULL;

-- Find WAITFOR blocker (skip system SPIDs 0-50)
SELECT TOP 1 @spid = session_id 
FROM sys.dm_exec_requests
WHERE command = 'WAITFOR' AND session_id > 50;

IF @spid IS NOT NULL
BEGIN
  SET @sql = 'KILL ' + CAST(@spid AS VARCHAR(10));
  PRINT 'Killing blocker (SPID ' + CAST(@spid AS VARCHAR(10)) + ')...';
  EXEC sp_executesql @sql;
  PRINT 'Blocker killed.';
END
ELSE
BEGIN
  PRINT 'No WAITFOR blocker found.';
END
" 2>&1

#!/usr/bin/env bash
set -euo pipefail
# Compose file now lives in compose/; point the CLI at it and the root .env.
export COMPOSE_FILE="${COMPOSE_FILE:-compose/docker-compose.yml}"
export COMPOSE_ENV_FILES="${COMPOSE_ENV_FILES:-.env}"
source .env 2>/dev/null || true
SA_PASSWORD="${SA_PASSWORD:?Set SA_PASSWORD or source .env}"
docker compose exec -T sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
SELECT ag.name                       AS ag_name,
       ar.replica_server_name        AS replica,
       ars.role_desc                 AS role,
       drs.synchronization_state_desc AS sync_state,
       drs.synchronization_health_desc AS sync_health,
       drs.log_send_queue_size        AS send_queue_kb,
       drs.redo_queue_size            AS redo_queue_kb
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar  ON ar.group_id = ag.group_id
JOIN sys.dm_hadr_availability_replica_states ars
     ON ars.replica_id = ar.replica_id
LEFT JOIN sys.dm_hadr_database_replica_states drs
     ON drs.replica_id = ar.replica_id
ORDER BY ars.role_desc DESC;"

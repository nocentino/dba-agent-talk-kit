# AG Setup + Fleet Profile

I keep `compose/docker-compose.yml` as one consolidated file. HADR is already enabled
on `sqlserver1`/`sqlserver2` by default, and the fleet instances
(`sqlserver3`/`sqlserver4`) sit behind a Compose profile so they don't start
unless you ask for them.

---

## Quick Start: One Command to Start Everything

```bash
./compose/startup.sh
```

This single command:
1. Starts the core stack (sqlserver1, sqlserver2, dab-mcp, sql-mcp-server)
2. Starts the fleet profile (sqlserver3, sqlserver4)
3. Waits for all SQL Server instances to be ready
4. Initializes the Always On AG (AG_Products)
5. Verifies the AG is healthy

No environment setup or multiple commands needed: run from the repo root and walk away.

---

## Manual Setup (if you prefer step-by-step control)

### Point the CLI at the compose file (run once per shell, from the repo root)
The compose file lives in `compose/` but `.env` stays at the repo root, so tell
the Docker Compose CLI where both are. Do this once and every `docker compose`
command below stays short:
```bash
export COMPOSE_FILE=compose/docker-compose.yml
export COMPOSE_ENV_FILES=.env
```
Prefer a one-off instead of exporting? Add the flags inline:
`docker compose -f compose/docker-compose.yml --env-file .env up -d`.

### Core stack (sqlserver1, sqlserver2, dab-mcp, sql-mcp-server)
```bash
docker compose up -d
```

### Always On AG (`AG_Products`)
HADR is already on from the core `up -d` above; no separate overlay needed.
```bash
./compose/init-ag.sh      # certs, endpoints, AG create/join, seed
./compose/verify-ag.sh    # expect SYNCHRONIZED / HEALTHY
```

### What init-ag.sh does
1. Creates a database master key + certificate on each instance.
2. Exchanges certificate public keys (via `docker compose cp`) so the mirroring
   endpoints authenticate mutually, no AD needed.
3. Creates the HADR endpoint (port 5022) on both instances.
4. On primary: full + log backup of ProductsDB, CREATE AVAILABILITY GROUP
   AG_Products WITH (CLUSTER_TYPE = NONE), replicas sqlserver1/sqlserver2,
   SYNCHRONOUS_COMMIT, SEEDING_MODE = AUTOMATIC.
5. On secondary: ALTER AVAILABILITY GROUP AG_Products JOIN WITH
   (CLUSTER_TYPE = NONE); GRANT CREATE ANY DATABASE for automatic seeding.

## Demo notes
- Break:  demos/sql/seed-ag-lag.sh   (SUSPEND on secondary + log churn on primary)
- Fix:    demos/sql/resume-ag.sh
- `get_ag_health` in the MCP server reads sys.dm_hadr_availability_replica_states
  and sys.dm_hadr_database_replica_states - all fully populated with
  CLUSTER_TYPE = NONE.
- Failover (if you want an encore): on secondary,
  `ALTER AVAILABILITY GROUP AG_Products FAILOVER;` works only when SYNCHRONIZED.

## Fleet profile (bonus demos)

Adds two more standalone SQL Server instances so fleet-wide demos have four
genuinely different members instead of two: `sqlserver3` (a neglected instance:
stale stats, fragmentation, a failing SQL Agent job) and `sqlserver4` (a
busy instance: deadlocks, tempdb pressure). Neither joins `AG_Products`.

### Bring-up
```bash
docker compose --profile fleet up -d
```
`sql-init-sqlserver3` / `sql-init-sqlserver4` create the `dba_monitor` login on
each automatically; no separate init script to run manually.

### Register both in `.env` `INSTANCES`
Add to the JSON array (see `.env` for the existing `SqlServer1`/`SqlServer2` entries):
```json
{
  "name":     "SqlServer3",
  "host":     "sqlserver3",
  "port":     1433,
  "user":     "dba_monitor",
  "password": "MonitorP@ss123!"
},
{
  "name":     "SqlServer4",
  "host":     "sqlserver4",
  "port":     1433,
  "user":     "dba_monitor",
  "password": "MonitorP@ss123!"
}
```
Restart `sql-mcp-server` after editing `.env` so it picks up the new instances:
```bash
docker compose up -d --force-recreate sql-mcp-server
```

### Demo notes
- `sqlserver3`: `MSSQL_AGENT_ENABLED=true`, reserved for future demos requiring SQL Agent.
- `sqlserver4`: standalone, used for `demos/bonus-deadlocks-and-tempdb.md`.
  Seed with `demos/sql/seed-deadlocks-tempdb.sh`.
- Both instances also make `demos/bonus-fleet-wide-waits.md` a genuine
  four-member fan-out instead of two.
- Host ports: `sqlserver3` → 1436, `sqlserver4` → 1437 (1433/1434 already used
  by `sqlserver1`/`sqlserver2`, 1435 left open for a future member).

## Full Teardown: One Command to Remove Everything

```bash
./compose/teardown.sh
```

This single command:
1. Stops all running containers (core + fleet profiles)
2. Removes all volumes (data, logs, networks)
3. Cleans up everything, safe to re-run `./compose/startup.sh` afterward

Run from the repo root. No manual cleanup needed.

### Manual teardown (if you prefer to use compose directly)

If you exported the environment variables (see [Manual Setup](#manual-setup) above):
```bash
docker compose down --remove-orphans --volumes
```

With inline flags:
```bash
docker compose -f compose/docker-compose.yml --env-file .env --profile fleet down --remove-orphans --volumes
```

(`--remove-orphans` catches any stray containers; `--volumes` removes all data.)

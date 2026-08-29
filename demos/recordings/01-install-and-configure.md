# Recording — Demo 1: Install & Configure the MCP Server

Captured live on 2026-08-28 from a full teardown (`docker compose --profile
fleet down -v`, all volumes removed) through a clean bring-up of the core
stack. Use this as a fallback if the live install demo stalls on stage — every
command and its real output is below.

> **Environment note:** this kit is self-contained. The compose file lives at
> `compose/docker-compose.yml` and `.env` at the repo root, so point the CLI at
> both once per shell (from the repo root):
> ```bash
> export COMPOSE_FILE=compose/docker-compose.yml
> export COMPOSE_ENV_FILES=.env
> ```
> Then every `docker compose …` below is short. (Inline alternative:
> `docker compose -f compose/docker-compose.yml --env-file .env …`.) The MCP
> server image is built directly from the sql-mcp-server GitHub repo — no local
> checkout of that repo is required.

## 1. Full teardown (what we started from)
```bash
$ cd /Users/anocentino/Downloads/dba-agent-talk-kit
$ export COMPOSE_FILE=compose/docker-compose.yml COMPOSE_ENV_FILES=.env
$ docker compose --profile fleet down -v
```
```
 Container sql-mcp-init Stopped
 Container sql-mcp-init-sqlserver2 Removed
 Container sql-mcp-sqlserver2 Removed
 Container sql-mcp-sqlserver1 Removed
 Volume dba-agent-talk-kit_sql-data Removed
 Volume dba-agent-talk-kit_ag-certs Removed
 Volume dba-agent-talk-kit_ag-backups Removed
 Network dba-agent-talk-kit_sql-mcp-network Removed
```

## 2. Bring the core stack up
```bash
$ docker compose up -d
```
```
 Container sql-mcp-sqlserver2 Started
 Container sql-mcp-sqlserver1 Started
 Container sql-mcp-sqlserver1 Healthy
 Container sql-mcp-sqlserver2 Healthy
 Container sql-mcp-init-sqlserver2 Started
 Container sql-mcp-init Started
 Container sql-mcp-init-sqlserver2 Exited
 Container sql-mcp-init Exited
 Container sql-mcp-dab Started
 Container sql-mcp-dba Started
```

## 3. Verify the containers (narrate while health checks settle)
```bash
$ docker compose ps --format 'table {{.Name}}\t{{.Status}}'
```
```
NAME                 STATUS
sql-mcp-dab          Up 5 seconds (health: starting)
sql-mcp-dba          Up 5 seconds (health: starting)
sql-mcp-sqlserver1   Up 26 seconds (healthy)
sql-mcp-sqlserver2   Up 26 seconds (healthy)
```
```bash
$ curl -s localhost:3001/health    # sql-dba MCP server
```
```json
{"status":"ok","server":"sql-server-dba-mcp","version":"1.0.0","sessions":0,"timestamp":"2026-08-29T00:02:19.988Z"}
```
```bash
$ curl -s localhost:5001/health    # products-db (DAB)
```
DAB's aggregate status may read `Unhealthy` for the first few seconds purely
because the GraphQL endpoints exceed a 1000 ms warm-up threshold on a cold
start — the `MSSQL` data-source check and every REST endpoint report `Healthy`.
It settles on its own; REST (what `read_records` uses) is fine immediately.

## 4. Wire up VS Code `mcp.json`
```json
{
  "servers": {
    "sql-dba":     { "type": "http", "url": "http://localhost:3001/mcp" },
    "products-db": { "type": "http", "url": "http://localhost:5001/mcp" }
  }
}
```

## 5. The moment access appears — list_instances
```
list_instances()
```
```json
[
  { "name": "SqlServer1", "host": "sqlserver1", "port": 1433, "user": "dba_monitor" },
  { "name": "SqlServer2", "host": "sqlserver2", "port": 1433, "user": "dba_monitor" }
]
```
Two instances — exactly what `.env` `INSTANCES` declares. Nothing more, nothing
less. This is the trust boundary made visible.

## 6. get_server_info on each (the agent's first real answer)
```
get_server_info(instance_name: "SqlServer1")
```
```json
{
  "server_properties": [
    {
      "product_version": "17.0.4050.1",
      "product_level": "RTM",
      "edition": "Enterprise Developer Edition (64-bit)",
      "engine_edition": 3,
      "server_name": "sqlserver1",
      "collation": "SQL_Latin1_General_CP1_CI_AS",
      "is_hadr_enabled": 1,
      "is_clustered": 0
    }
  ],
  "key_configurations": [
    { "name": "cost threshold for parallelism", "current_value": "5" },
    { "name": "max degree of parallelism", "current_value": "0" },
    { "name": "max server memory (MB)", "current_value": "2147483647" },
    { "name": "optimize for ad hoc workloads", "current_value": "0" }
  ],
  "system_info": [
    {
      "cpu_count": 12,
      "physical_memory_mb": "15977",
      "sqlserver_start_time": "2026-08-29T00:01:58.613Z",
      "uptime_hours": 0,
      "sql_committed_mb": "458",
      "sql_target_mb": "14394"
    }
  ]
}
```
`get_server_info(instance_name: "SqlServer2")` returns the same build and the
same four default config values (`sqlserver2`, committed 429 MB). Those four
defaults — MAXDOP 0, cost threshold 5, uncapped max memory, ad-hoc workloads
off — are the container defaults the observability skill (Demo 6) will flag.
They are intentionally left unconfigured here so a later demo has real drift to
find.

## Result
Zero access → two healthy containers → one `mcp.json` block → `list_instances`
and `get_server_info` return real data. The agent could see nothing until the
JSON named the server. Reproduces exactly as written.

# Demo 1 — Install & Configure the MCP Server (Objective 1, ~5 min)

**Point being made:** an MCP server is not a plugin, an extension, or magic —
it's a plain HTTP endpoint any MCP-aware client can call. Until `mcp.json` names
it, Copilot has zero access to your SQL Server, no matter how good the model is.
This demo makes the trust boundary visible: nothing → two running containers →
one JSON block → tools appear in Copilot Chat. Everything after this demo is
built on what gets stood up here.

## Pre-demo state
- Terminal open, Docker Desktop running, nothing from this repo currently up
  (`docker compose down -v` if re-running this demo).
- VS Code open with **no** `sql-dba` / `products-db` entries in `mcp.json` yet
  (comment them out or use a throwaway profile if you rehearsed this before).
- Have `github.com/nocentino/sql-mcp-server` open in a browser tab as backup
  reference, but do the clone live if your connection is reliable.

## Setup — clone, configure, start
```bash
# 1. Clone and copy the env file
git clone https://github.com/nocentino/sql-mcp-server.git
cd sql-mcp-server
cp .env.example .env
# Open .env — point out SA_PASSWORD and the INSTANCES JSON array. Nothing else
# to change for a first run.

# 2. Start everything
./start.sh
# This builds the sql-mcp-server image, starts sqlserver1, sqlserver2, dab-mcp,
# and sql-mcp-server, and waits for health checks. Takes ~60-90s cold.
```

## Verify the containers (narrate while start.sh finishes)
```bash
docker compose ps
curl http://localhost:3001/health   # sql-dba MCP server
curl http://localhost:5001/health   # products-db (DAB)
```
Point at the `docker compose ps` output: four services, all healthy. Point at
each `/health` JSON response — this is a normal web server, not a special
AI-only thing.

## Wire up VS Code
Add both servers to `mcp.json` (Command Palette → **MCP: Open User Configuration**,
or edit `~/Library/Application Support/Code/User/mcp.json` directly):
```json
{
  "servers": {
    "sql-dba":     { "type": "http", "url": "http://localhost:3001/mcp" },
    "products-db": { "type": "http", "url": "http://localhost:5001/mcp" }
  }
}
```
Save the file. VS Code picks up the new servers automatically — no reload
usually required, but have **Developer: Reload Window** ready as a fallback.

## The prompt (paste into a fresh Copilot Chat, agent mode)
> List the SQL Server instances you can see, and tell me the version, uptime,
> and any configuration concerns for each one.

## Expected agent behavior (narrate as it happens)
1. Copilot's tool picker shows the new `sql-dba` and `products-db` tool groups —
   pause here and let the audience see the tool list expand. This is the moment
   access came into existence.
2. Calls `list_instances()` → returns `SqlServer1`, `SqlServer2`.
3. Calls `get_server_info(instance_name: ...)` for each — version, edition,
   CPU/RAM, uptime, and flags default config concerns (MAXDOP=0, uncapped
   memory, low cost threshold for parallelism — these are the container
   defaults, intentionally left unconfigured for later demos).
4. Synthesizes both into one answer, comparing the two instances.

## Talking points while it runs
- "That JSON block is the entire integration. No SDK, no plugin install, no
  vendor lock-in — any MCP-aware client points at the same URL."
- "Until I saved that file, the agent had no path to this database. Not a
  permissions wall inside the model — the tool didn't exist for it to call."
- "Two servers, two trust boundaries: `products-db` is DAB, scoped CRUD against
  one application database. `sql-dba` is the custom server — read-only DMV
  access across the whole estate. We'll lean on that distinction all hour."
- "The config concerns it just flagged — MAXDOP, memory, cost threshold — are
  the default container settings. We're not fixing them yet. Hold that thought."

## Reset
```bash
docker compose down        # stop, keep data — fast re-demo
docker compose down -v     # stop and wipe all data — full clean slate
```
If re-running this demo cold, also remove or comment out the `sql-dba` /
`products-db` entries from `mcp.json` beforehand so the "tools appear" moment
is genuine on stage.

## Failure modes / fallback
- **Health check never turns green** → SQL Server 2025 containers take longer
  to initialize on first run (image pull + `docker-entrypoint-initdb.d`
  scripts). Give it the full 60-90s before troubleshooting; `docker compose logs
  sqlserver1` shows startup progress.
- **Port already in use (1433/3001/5001)** → something else is bound to those
  ports. `docker ps` to find it; stop the conflicting container or change the
  host port mapping in `docker-compose.yml` for this one run.
- **Copilot doesn't show new tools after saving `mcp.json`** → run **Developer:
  Reload Window** from the Command Palette. Malformed JSON (trailing comma,
  missing brace) is the other common cause — validate the file first.
- **Agent answers without calling any tools** → it doesn't yet believe the tools
  are relevant; be explicit in the prompt ("using your SQL Server tools...") or
  re-check that the `mcp.json` save actually registered (tool picker count).
- Fallback recording: `demo1-install.mp4`.

# Demo 1 · Install & Configure the MCP Server

**An MCP server is just an HTTP endpoint. Until `mcp.json` names it, Copilot has zero access. It doesn't matter how good the model is.**

---

## The trust boundary, made visible

I want you to see this happen, not just take my word for it: nothing → two containers → one JSON block → tools appear in Copilot Chat.

- Not a plugin, not an extension, not magic
- No `mcp.json` entry = no path to your SQL Server
- Everything else this hour is built on what stands up here

---

## Setup: one command to start everything

```bash
./compose/startup.sh
```

This starts all containers (core stack + fleet profile), waits for SQL Server to be ready, initializes the Always On AG, and verifies everything is healthy.

**That's it.** No environment setup, no multiple commands. Run from the repo root and it handles the whole stack.

### Manual setup (if you prefer step-by-step control)

```bash
cp .env.example .env                          # SA_PASSWORD + INSTANCES
export COMPOSE_FILE=compose/docker-compose.yml
export COMPOSE_ENV_FILES=.env
docker compose up -d                          # Core stack
docker compose --profile fleet up -d          # Fleet profile (for bonus demos)
./compose/init-ag.sh                          # Initialize AG
./compose/verify-ag.sh                        # Verify health
```

---

## Verify the containers

```bash
docker compose ps
curl http://localhost:3001/health   # sql-dba MCP server
curl http://localhost:5001/health   # products-db (DAB)
```

Four services, all healthy. A normal web server, not an AI-only thing.

---

## Wire up VS Code

`mcp.json`: Command Palette → **MCP: Open User Configuration**:

```json
{
  "servers": {
    "sql-dba":     { "type": "http", "url": "http://localhost:3001/mcp" },
    "products-db": { "type": "http", "url": "http://localhost:5001/mcp" }
  }
}
```

Save. VS Code picks up the servers automatically.

---

## The prompt

> List the SQL Server instances you can see, and tell me the version, uptime,
> and any configuration concerns for each one.

---

## What you'll see

1. The tool picker expands: `sql-dba` + `products-db` appear. **Access just came into existence.**
2. [`list_instances`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) → `SqlServer1`, `SqlServer2`
3. [`get_server_info`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) per instance → version, CPU/RAM, uptime
4. Flags default config drift: MAXDOP 0, uncapped memory, low cost threshold
5. One synthesized answer comparing both instances

---

## Why it matters

- **That JSON block is the entire integration.** No SDK, no plugin, no lock-in.
- Until you save it, the tool doesn't exist for the agent to call
- **Two servers, two trust boundaries:** `products-db` = scoped CRUD; `sql-dba` = read-only DMVs across the estate
- The config concerns it flagged are container defaults; we fix nothing yet

---

**Next:** [Demo 2 · Tools Without Skills →](02-blocking-and-dab.md)

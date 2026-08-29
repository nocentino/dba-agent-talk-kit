# Build Your Own DBA Agent — 60-min Conference Session

Self-contained demo kit for a DBA agent built on
[sql-mcp-server](https://github.com/nocentino/sql-mcp-server). No deck — this
is a demo-driven session. `docker compose up -d` from this repo's root brings
up the whole environment; the MCP server image is built directly from the
sql-mcp-server GitHub repo (no local checkout of that repo needed). See
[demos/README.md](demos/README.md) for the full run-of-show; ASCII architecture
diagrams live in the demo files themselves (start at
[demos/00-intro-and-architecture.md](demos/00-intro-and-architecture.md)).

## Conference abstract

> We'll build a DBA agent from the ground up using Model Context Protocol (MCP).
> You'll see how MCP connects a language model to your existing tooling. We'll
> give that agent real, actionable skills across availability management, backup
> and recovery, security and auditing, and observability. We'll work through what
> skill files look like in practice and how to structure them, so the agent
> actually knows what it's doing.
>
> The focus throughout is on control and trust. Fast-moving AI tools are only
> useful if your operations and security teams believe in them. You'll leave with
> a practical architecture you can apply to your own SQL Server estate the next day.
>
> **You'll learn how to:**
> 1. Explain what AI agents and MCP are and how they apply to database operations
> 2. Build DBA agent skills for availability, recovery, security/auditing, and observability
> 3. Design trust and control guardrails that keep humans in the decision loop

## What's in this kit

| Path | What it is |
|---|---|
| compose/docker-compose.yml | The whole environment: sqlserver1/2, dab-mcp, sql-mcp-server (built from GitHub), plus a `fleet` profile for 2 bonus-demo instances |
| scripts/ | dba_monitor + ProductsDB init scripts for all 4 SQL Server instances |
| dab-config.json | DAB entity config (Products/Categories/Orders/OrderDetails) |
| demos/ | 8 core demo runbooks (00–07) + 4 bonus demos + seed/reset scripts (demos/sql/) + recordings & demo-day checklist — this is the session |
| skills/ | Copilot persona + 4 domain skill files (availability, backup-recovery, security-audit, observability) + wiring README |
| compose/ | The compose file + AG helper scripts (init-ag.sh, verify-ag.sh) — HADR itself is already on by default |
| deck/DBA-Agent-with-MCP.pptx | Optional reference only — not used in the live session |

> The 4 security tools (`get_security_config_drift`, `get_sysadmin_members`,
> `get_failed_logins`, `get_orphaned_users`) live in `sql-mcp-server/src/tools.ts`
> in the sql-mcp-server repo, committed and pushed to `origin/main`
> (commit `566b3a1`) — the git-context build here pulls them in automatically.

## Quick start
The compose file lives in `compose/` while `.env` stays at the repo root, so
point the Compose CLI at both once per shell (run from the repo root):
```bash
cp .env.example .env   # edit SA_PASSWORD at minimum
export COMPOSE_FILE=compose/docker-compose.yml
export COMPOSE_ENV_FILES=.env
docker compose up -d
./compose/init-ag.sh && ./compose/verify-ag.sh   # optional: AG_Products
docker compose --profile fleet up -d             # optional: bonus-demo instances
```
(No exports? Use `docker compose -f compose/docker-compose.yml --env-file .env …`
inline instead.) Then wire `mcp.json` per
[demos/01-install-and-configure.md](demos/01-install-and-configure.md) and start
at [demos/README.md](demos/README.md).

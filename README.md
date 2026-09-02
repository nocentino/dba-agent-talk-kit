# Build Your Own DBA Agent: 60-min Conference Session

Self-contained demo kit for a DBA agent built on
[sql-mcp-server](https://github.com/nocentino/sql-mcp-server). There's no deck; this
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

## What is MCP and why it matters for control

**Model Context Protocol (MCP)** is a standardized way to connect language models to tools, data sources,
and systems. Unlike APIs where a client makes direct calls, MCP is a *bidirectional contract* between
the LLM and your infrastructure. Here's what that means for database operations:

### How MCP gives you control

**1. Tool Discovery is Gated**
- Tools don't appear in the LLM's context until YOU define them in a configuration file (`mcp.json`).
- No automatic API introspection; you choose exactly what the LLM can call.
- Example: Your DBA MCP server has 20 diagnostic tools. You expose only 5 for a junior operator, all 20 for a senior DBA.

**2. Execution is Sandboxed**
- The MCP server runs in YOUR infrastructure, not in Anthropic's cloud.
- Tools are subprocess calls to your own scripts/binaries. You control the environment, permissions, and logging.
- Example: `get_database_info` is a Python script running on your monitoring workstation. It connects to your SQL Server via dba_monitor credentials (read-only). The LLM never sees the password.

**3. Tool Definitions Include Guard Rails**
- Each tool has a schema that specifies input validation, output format, and human-readable descriptions.
- You can mark a tool as "write-only after human approval" or "dry-run only before execution."
- Example: A `KILL_SESSION` tool includes a check: "requires a [session_id] field, validates it's not a system process, and returns the T-SQL KILL command for human review before execution."

**4. Skill Files Are Policy as Code**
- Beyond individual tools, you attach `.instructions.md` files (skill files) that encode domain-specific procedures, thresholds, and hard boundaries.
- Skills are loaded per-conversation. You can run the same prompt with and without a skill to show the difference in rigor and safety.
- Example: The "Availability" skill file has 60 lines of procedures, thresholds (send queue > 10,000 KB = WARNING), and hard boundaries ("never draft FORCE_FAILOVER_ALLOW_DATA_LOSS unless the user explicitly states the primary is lost").

**5. Permission Gates Stop Mutations**
- Read-only operations (SELECT, dmv queries, diagnostics) run automatically.
- State-changing operations (ALTER, backup, snapshot, DROP) pause and ask the human for approval before proceeding.
- The LLM cannot execute the mutation without you explicitly saying "yes" in the chat.
- Example: "Take a snapshot of database X" → pre-flight checks run silently → permission prompt appears → you approve → snapshot executes.

**6. Logging and Audit Trail**
- Every tool call is logged: what was called, with what parameters, when, and what the result was.
- Your SOC can audit exactly what the agent did and when. No "magic" black-box operations.

### Why this matters for operations

- **You stay in control**, not the LLM. The agent works *for* you, within boundaries you define.
- **You can iterate safely**, because tool exposure, skill rules, and gates are configuration: change them without code changes.
- **You can reason about risk**, because tool definitions and skills are human-readable policies, not buried in model weights.
- **You can test**, because you can run the same scenario with/without a skill, with/without different tool subsets, to validate behavior before production deployment.

---

## What's in this kit

| Path | What it is |
|---|---|
| compose/docker-compose.yml | The whole environment: sqlserver1/2, dab-mcp, sql-mcp-server (built from GitHub), plus a `fleet` profile for 2 bonus-demo instances |
| scripts/ | dba_monitor + ProductsDB init scripts for all 4 SQL Server instances |
| dab-config.json | DAB entity config (Products/Categories/Orders/OrderDetails) |
| demos/ | 8 core demo runbooks (00-07) + 4 bonus demos + seed/reset scripts (demos/sql/) |
| .github/instructions/ | Copilot persona + 6 domain skill files (availability, backup-recovery, deadlock-tempdb, observability, security-audit, snapshot-freeze-safety) |
| compose/ | The compose file + AG helper scripts (init-ag.sh, verify-ag.sh); HADR itself is already on by default |
| deck/DBA-Agent-with-MCP.pptx | Optional reference only, not used in the live session |

> The 4 security tools (`get_security_config_drift`, `get_sysadmin_members`,
> `get_failed_logins`, `get_orphaned_users`) live in `sql-mcp-server/src/tools.ts`
> in the sql-mcp-server repo, committed and pushed to `origin/main`
> (commit `566b3a1`). The git-context build here pulls them in automatically.

## Quick start

One command to start the entire stack (all SQL servers, MCP servers, and AG initialization):

```bash
./compose/startup.sh
```

Run from the repo root. This starts all containers, waits for SQL Server to be ready, initializes Always On AG (AG_Products), and verifies health. Takes 2-3 minutes. When it says **✅ Stack Ready!**, proceed to wire `mcp.json` per [demos/01-install-and-configure.md](demos/01-install-and-configure.md) and start at [demos/README.md](demos/README.md).

### Manual setup (if you prefer step-by-step control)

```bash
cp .env.example .env   # edit SA_PASSWORD at minimum
export COMPOSE_FILE=compose/docker-compose.yml
export COMPOSE_ENV_FILES=.env
docker compose up -d
./compose/init-ag.sh && ./compose/verify-ag.sh   # initialize AG_Products
docker compose --profile fleet up -d             # start bonus-demo instances (optional)
```

(No exports? Use `docker compose -f compose/docker-compose.yml --env-file .env …` inline instead.)

### Teardown

To stop and remove everything (containers, volumes, networks):

```bash
./compose/teardown.sh
```

Removes all running containers and persistent volumes. To restart, run `./compose/startup.sh` again.

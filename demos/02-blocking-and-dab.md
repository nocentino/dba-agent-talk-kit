# Demo 2 — Tools Without Skills: Blocking Investigation + DAB (Objective 1, ~6 min)

**Point being made:** the agent doesn't write a query for you to run — it goes and
gets the answer, chains tools, and hands you a diagnosis. And it *recommends* the
KILL; it cannot execute it. (Plant guardrail #1 here; pay it off in Demo 7 — Trust
& Guardrails.)

## Pre-demo state
- Containers up (`./start.sh`), both MCP servers registered in VS Code `mcp.json`.
- Copilot Chat open in **Agent mode**, `sql-dba` tools enabled.
- Two terminals ready (or use the seed script below which backgrounds everything).

## Setup — seed the blocker (run ~60s before the demo)
`demos/sql/seed-blocking.sh`:

```bash
#!/usr/bin/env bash
# Terminal A - the head blocker: open txn + WAITFOR
docker compose exec -d sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d ProductsDB -Q "
BEGIN TRANSACTION;
UPDATE dbo.Products SET UnitPrice = UnitPrice * 1.01 WHERE Category = 'Electronics';
WAITFOR DELAY '00:08:00';
ROLLBACK;"

sleep 2

# Terminal B - the victim: a SELECT that will queue behind the X lock
docker compose exec -d sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d ProductsDB -Q "
SELECT ProductID, ProductName, UnitPrice
FROM dbo.Products WHERE Category = 'Electronics';"

# Optional third victim via DAB REST (shows a blocked API call too):
curl -s "http://localhost:5001/api/Products?\$filter=Category eq 'Electronics'" \
  --max-time 300 > /dev/null &
```

## The prompt (paste into Copilot Chat)
> Are there any blocking sessions right now on SqlServer1? Who is blocking whom,
> how long has the block been in place, and what SQL is running on both sides?
> What should I do about it?

## Expected agent behavior (narrate as it happens)
1. Calls `get_blocking_chains(instance_name: "SqlServer1")`.
2. Identifies the head blocker (open transaction + `WAITFOR`), the LCK_M_S waiters,
   wait time, and both SQL texts.
3. Recommends `KILL <spid>` **as a script** — it cannot run it.

## Talking points while it runs
- "Notice it picked the tool from the description. I never told it which DMV."
- "The blocker SQL text comes from `most_recent_sql_handle` — credit to the
  First Responder Kit for that pattern."
- When the KILL recommendation appears: "This is the trust story in one screenshot.
  The agent has SELECT-only access — enforced in code, not in a prompt. It can
  diagnose; I decide. Hold that thought for Act 4."

## Reset
```bash
# Find and kill the WAITFOR session if it's still open
docker compose exec sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
DECLARE @spid INT = (SELECT TOP 1 session_id FROM sys.dm_exec_requests
                     WHERE command = 'WAITFOR' AND session_id <> @@SPID);
IF @spid IS NOT NULL EXEC('KILL ' + @spid);"
```

## Failure modes / fallback
- Blocker expired (8-min WAITFOR) → re-run seed script; it takes 3 seconds.
- Agent answers from a stale earlier tool result → new chat session per demo,
  always. Start each demo in a fresh chat.
- Copilot picks `get_active_sessions` first → fine; it will chain to
  `get_blocking_chains`. Don't rescue it too early — the chaining IS the demo.
- Total failure → recording `demo1-blocking.mp4` (see recordings.md).

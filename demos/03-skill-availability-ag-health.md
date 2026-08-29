# Demo 3 — Skill: Availability Management (AG Health) (Objective 2, ~5 min)

**Point being made:** first demo WITH a skill attached. The agent follows YOUR
runbook: checks primary first, walks the thresholds table, correlates redo lag with
VLF count, and refuses to bless a failover while the send queue is non-zero.

## Pre-demo state
- Core stack up (`docker compose up -d` — HADR is on by default) and
  `compose/init-ag.sh` completed (see compose/README.md). This creates a
  clusterless (CLUSTER_TYPE = NONE) AG `AG_Products` with SqlServer1 primary,
  SqlServer2 secondary, database `ProductsDB` seeded.
- Fresh Copilot chat. **Attach the skill explicitly**: Add Context → Instructions →
  `availability.instructions.md`. (Deterministic > automatic, on stage.)

## Setup — break it (run right before the demo)
`demos/sql/seed-ag-lag.sh`:

```bash
#!/usr/bin/env bash
# 1. Suspend data movement on the secondary
docker compose exec sqlserver2 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
ALTER DATABASE [ProductsDB] SET HADR SUSPEND;"

# 2. Generate log on the primary so the send queue grows
docker compose exec -d sqlserver /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d ProductsDB -Q "
SET NOCOUNT ON;
DECLARE @i INT = 0;
WHILE @i < 2000
BEGIN
  UPDATE dbo.Products SET UnitsInStock = UnitsInStock WHERE ProductID % 5 = @i % 5;
  SET @i += 1;
END;"
```

## The prompt
> Is my availability group healthy? If I had to fail over to the secondary right
> now, could I do it without losing data? Give me the full picture.

## Expected agent behavior (this is the skill talking)
1. `list_instances`, then `get_ag_health` on SqlServer1 (primary FIRST — the skill
   orders it), then SqlServer2.
2. Finds `ProductsDB` on the secondary in SUSPENDED / NOT SYNCHRONIZING with a
   growing send queue on the primary.
3. Classifies against the thresholds table → CRITICAL.
4. Checks `get_long_running_transactions` and `get_database_files` per the skill's
   decision rules (disk-full is a listed suspend cause in this estate).
5. Answers the failover question with **"No — not without data loss"**, quantified
   by the send queue, and drafts `ALTER DATABASE [ProductsDB] SET HADR RESUME`
   for a human to run.

## Talking points
- "Everything it just did came out of a markdown file. Primary-first ordering,
  the 10 MB send-queue threshold, the refusal to bless the failover — that's the
  SOP, not the model's mood."
- "Ask yourself what your best DBA would check. Now notice the agent checked the
  same things, in the same order, because we wrote them down."
- Show the skill file for 20 seconds. The thresholds table is the slide-worthy bit.

## Restore health (on stage if time — it's satisfying)
```bash
docker compose exec sqlserver2 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
ALTER DATABASE [ProductsDB] SET HADR RESUME;"
```
Then re-ask: "check it again" → sync catches up → HEALTHY. Before/after in one demo.

## Failure modes / fallback
- AG didn't seed (cert/endpoint issues) → run `compose/verify-ag.sh` BEFORE the
  talk, not during. If broken on the day, use fallback recording `demo3-ag.mp4`.
- Send queue drains too fast → re-run step 2 of the seed script; it's idempotent.
- Copilot ignores the attached skill → quote it: "follow the availability SOP" in
  the prompt. Attaching + naming it is belt and suspenders.

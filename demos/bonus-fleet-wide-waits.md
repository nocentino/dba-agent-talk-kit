# Bonus — Fleet-Wide Wait Stats (optional, not in the 60-min core, ~4 min)

**Point being made:** this scales past one server. One question, parallel fan-out,
one synthesized answer across the estate. This is the "get your arms around a
complex estate" moment.

## Pre-demo state
- Both instances registered in `.env` `INSTANCES` (SqlServer1, SqlServer2).
- Fresh Copilot chat.
- Optional: differentiated load so the two instances tell different stories.
- Optional (bigger version of this demo): bring up the fleet profile
  (`docker compose --profile fleet up -d`, see [compose/README.md](../compose/README.md#fleet-profile-bonus-demos))
  for a genuine four-instance fan-out — SqlServer3 (maintenance neglect) and
  SqlServer4 (deadlocks/tempdb) each have their own real, different problems
  from [bonus-maintenance-neglect.md](bonus-maintenance-neglect.md) and
  [bonus-deadlocks-and-tempdb.md](bonus-deadlocks-and-tempdb.md) if seeded first.

## Setup — differentiated load (start 2–3 min before)
`demos/sql/seed-fleet-load.sh`:

```bash
#!/usr/bin/env bash
# SqlServer1: IO + CPU pressure - repeated scans that exceed the buffer pool
docker compose exec -d sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -d ProductsDB -Q "
SET NOCOUNT ON;
DECLARE @i INT = 0;
WHILE @i < 500
BEGIN
  DBCC DROPCLEANBUFFERS;  -- force physical reads each pass
  SELECT COUNT_BIG(*) FROM dbo.OrderDetails od
    JOIN dbo.Orders o ON o.OrderID = od.OrderID
    JOIN dbo.Products p ON p.ProductID = od.ProductID
  OPTION (MAXDOP 4);
  SET @i += 1;
END;"

# SqlServer2: ASYNC_NETWORK_IO - a slow client dribbling a big result set
docker compose exec -d sqlserver2 /opt/mssql-tools18/bin/sqlcmd \
  -S localhost -U sa -P "$SA_PASSWORD" -C -Q "
SELECT a.* FROM sys.all_objects a CROSS JOIN sys.all_objects b;" \
  | while read -r line; do sleep 0.01; done &
```

## The prompt
> Check wait stats on all my SQL Server instances and tell me if there are any
> concerns. Compare the instances — are they suffering from the same problem or
> different ones?

## Expected agent behavior
1. `list_instances` → finds both.
2. Either parallel `get_wait_stats` per instance or `fan_out_query` — both are wins.
3. Diagnoses SqlServer1 as IO/CPU pressure (PAGEIOLATCH_SH + SOS_SCHEDULER_YIELD)
   and SqlServer2 as ASYNC_NETWORK_IO (slow client), and — key — says the second
   one is an **app-tier** problem, not a database problem.

**Real caveat observed in testing:** wait stats are cumulative since restart. If
you run this demo *after* other demos in the same rehearsal/session without
restarting, earlier activity (backups, AG, blocking) can dominate the top of
the list and bury the differentiated signal below the fold. Run this demo
first/standalone for a clean top-of-list result, or `DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR);`
on both instances immediately before seeding.

## Talking points
- "The benign-wait filter in `get_wait_stats` is First Responder Kit heritage —
  domain knowledge baked into the tool, so the agent isn't distracted by
  CXCONSUMER noise."
- "One instance down doesn't break this — `Promise.allSettled` under the hood.
  Fleet questions degrade gracefully."
- "ASYNC_NETWORK_IO: the agent just told you to go look at the app tier instead
  of tuning the database. That's the correct answer a lot of humans get wrong."

## Reset
```bash
# Prefer targeted kills over a restart when the AG overlay is also up:
# `docker compose restart sqlserver1 sqlserver2` was observed in testing to
# OOM-kill sqlserver2 (exit 137) when run alongside the AG + fleet overlays
# (4 SQL Server containers + dab + mcp-server all on one host). If that
# happens, `docker start sql-mcp-sqlserver2` brings it back; AG self-resynced
# to SYNCHRONIZED/HEALTHY within ~20s with no manual RESUME needed in testing,
# but check `./compose/verify-ag.sh` before moving on regardless.
docker compose restart sqlserver1 sqlserver2   # nukes the load loops (see caveat above)
# or targeted (safer): KILL the WHILE-loop sessions via sqlcmd
```
Note: restart also resets cumulative wait stats — do this AFTER the demo, not before,
or the seeded waits vanish.

## Failure modes / fallback
- Waits look flat because instances just restarted → seed load earlier; wait stats
  are cumulative-since-restart, they need a few minutes of history.
- Agent only checks one instance → follow-up: "check the other instances too" —
  and narrate that a skill file would have made the fleet sweep automatic (segue!).
- Total failure → recording `demo2-fleet.mp4`.

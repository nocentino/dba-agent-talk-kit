# Recording — Demo 6: Skill: Observability (Health Snapshot)

Captured live on 2026-08-28, after Demos 2–5 had already run in the same
session — so the cumulative wait stats below carry real history from those
demos. That's the honest state of a rehearsal box; see the caveat in step 3.

## 1. Seed a little real load
```bash
$ cd demos/sql
$ ./seed-observability-load.sh
```
```
...
Observability load seeded: ~20k filler rows (Electronics ~3%) + Category scan activity.
```

## 2. Step 1 — get_server_info (the four config baselines)
```
get_server_info(instance_name: "SqlServer1")
```
Key configurations (container defaults, unchanged from Demo 1):
```json
[
  { "name": "cost threshold for parallelism", "current_value": "5" },
  { "name": "max degree of parallelism",      "current_value": "0" },
  { "name": "max server memory (MB)",         "current_value": "2147483647" },
  { "name": "optimize for ad hoc workloads",  "current_value": "0" }
]
```
MAXDOP 0 (unlimited) and cost threshold 5 (near-default) both trip the skill's
baseline — reported as drift whether or not anything is on fire.

## 3. Step 3 — get_wait_stats (cumulative; benign already filtered)
```
get_wait_stats(instance_name: "SqlServer1")
```
Top waits this run (percent of total):
```json
[
  { "wait_type": "VDI_CLIENT_OTHER", "pct_total": 89.1, "waiting_tasks_count": "494" },
  { "wait_type": "HADR_TIMER_TASK",  "pct_total": 7.87, "waiting_tasks_count": "1255" },
  { "wait_type": "LCK_M_S",          "pct_total": 1.72, "waiting_tasks_count": "13" }
]
```
> **Cumulative-stats caveat (real, expected):** `sys.dm_os_wait_stats` is
> cumulative since restart. `VDI_CLIENT_OTHER` dominates here because Demo 4 ran
> a pile of `BACKUP` operations minutes earlier; `HADR_TIMER_TASK` is the live
> AG; `LCK_M_S` is left over from Demo 2's blocker. For a clean signal, run this
> demo first, or clear with
> `DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR)` before seeding. The skill's
> value is the consistent SOP, not any single wait number.

## 4. Step 4 — get_top_queries (by CPU, top 5)
```
get_top_queries(instance_name: "SqlServer1", order_by: "cpu", top_n: 5)
```
```json
{
  "top_queries": [
    { "avg_cpu_ms": "134", "execution_count": "1",  "avg_logical_reads": "3880", "avg_rows": "20000", "query_text": "INSERT INTO dbo.Products (...) SELECT TOP (20000) ... FROM sys.all_objects a CROSS JOIN sys.all_objects b" },
    { "avg_cpu_ms": "1",   "execution_count": "30", "avg_logical_reads": "270",  "avg_rows": "1",     "query_text": "SELECT COUNT(*), MAX(UnitPrice) FROM dbo.Products WHERE Category = 'Electronics' AND Discontinued = 0" },
    { "avg_cpu_ms": "0",   "execution_count": "30", "avg_logical_reads": "18",   "avg_rows": "3",     "query_text": "SELECT p.ProductName, od.Quantity FROM dbo.OrderDetails od JOIN dbo.Products p ... JOIN dbo.Orders o ... WHERE p.UnitsInStock < 50 AND p.UnitPrice > 20" }
  ]
}
```
The seed's `Category` filter (30 executions, 270 logical reads each) and the
three-table join are right where you'd expect them.

## 5. Step 5 — get_blocking_chains
```
get_blocking_chains(instance_name: "SqlServer1")
```
```
No blocking detected at this time.
```
"No blocking" is a valid, expected finding here — the skill treats it as a
normal result, not a failure to find something.

## 6. Step 6 — get_missing_indexes (the high-impact recommendation)
```
get_missing_indexes(instance_name: "SqlServer1", min_impact: 50)
```
```json
{
  "missing_indexes": [
    {
      "database_name": "ProductsDB",
      "table_name": "Products",
      "equality_columns": "[Category], [Discontinued]",
      "included_columns": "[UnitPrice]",
      "user_seeks": "30",
      "avg_user_impact_pct": 89,
      "impact_score": 6.44,
      "suggested_create_index": "CREATE INDEX [IX_Products_missing_2] ON [ProductsDB].[dbo].[Products] ([Category], [Discontinued]) INCLUDE ([UnitPrice])"
    }
  ]
}
```
A composite index on `Products(Category, Discontinued) INCLUDE (UnitPrice)` at
**89% estimated impact**, with ready-to-run DDL — plus the skill's mandatory
caveat: test in non-prod, and check `get_index_usage_stats` for overlap first,
because the optimizer over-suggests. The ~20k skewed rows (Electronics ~3%) are
what make the seek genuinely worth an index; a small or evenly-split table
would not trip this.

## Report shape the skill enforces
- One **severity line** at the top = max of any finding.
- Configuration drift reported even though performance is currently fine.
- Missing-index DDL always paired with the overlap-check warning.
- Closes with **What I did NOT check** (Query Store regressions, deadlock
  history) so scope is auditable.

## Reset
```bash
$ ./reset-observability-load.sh
```
```
(20000 rows affected)
Observability demo reset: filler rows removed.
```

## Result
All seven steps ran in the skill's fixed order and produced a real, high-impact
missing-index recommendation. The only caveat is the cumulative wait stats,
which is expected when this runs after other demos — documented above.

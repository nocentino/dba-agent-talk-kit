# Recording — Bonus: Fleet-Wide Wait Stats

Captured live on 2026-08-28 with the **full four-instance fleet** up
(`docker compose --profile fleet up -d`, SqlServer1–4 registered in `.env`).
Wait stats were cleared on all four with
`DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR)` immediately before seeding, per
the demo's own workaround.

## 1. Differentiated load
```bash
$ cd demos/sql
$ ./seed-fleet-load.sh
```
SqlServer1 gets IO/CPU pressure (repeated `DBCC DROPCLEANBUFFERS` + 3-table
join scans); SqlServer2 gets a slow client dribbling a huge result set
(`ASYNC_NETWORK_IO`). SqlServer3/4 carry only baseline load.

## 2. Fan-out across the estate — get_wait_stats per instance
The agent calls `list_instances` (returns all four) then fans out. The tool's
benign-wait filter (First Responder Kit heritage) is what makes the signal
readable — a raw `fan_out_query` against `sys.dm_os_wait_stats` is dominated by
`SOS_WORK_DISPATCHER` (an idle background wait) at 94%+ on every instance, which
`get_wait_stats` strips out.

**SqlServer2 — the differentiated finding:**
```json
{
  "wait_stats": [
    { "wait_type": "VDI_CLIENT_OTHER",  "pct_total": 85.67, "wait_time_ms": "4310088" },
    { "wait_type": "HADR_TIMER_TASK",   "pct_total": 7.16,  "wait_time_ms": "360446" },
    { "wait_type": "ASYNC_NETWORK_IO",  "pct_total": 7.03,  "wait_time_ms": "353601", "waiting_tasks_count": "179" }
  ],
  "benign_waits_excluded": true
}
```
`ASYNC_NETWORK_IO` at 7% (179 waiting tasks) shows up **only on SqlServer2** —
the slow-client tell. The correct call is: that is an **app-tier** problem, not
a database problem.

**SqlServer1 (and 3, 4) — no ASYNC_NETWORK_IO:**
```json
{
  "wait_stats": [
    { "wait_type": "VDI_CLIENT_OTHER", "pct_total": 92.13 },
    { "wait_type": "HADR_TIMER_TASK",  "pct_total": 7.72 },
    { "wait_type": "PAGEIOLATCH_SH",   "pct_total": 0, "waiting_tasks_count": "536" }
  ],
  "benign_waits_excluded": true
}
```
SqlServer1 shows `PAGEIOLATCH_SH` from the forced physical reads, but with tiny
wait time — on this small dataset and fast host storage the reads are cheap, so
the IO signal stays weak. Honest result: the **shape** differs across the
fleet (only SqlServer2 has the network wait), which is the point, even when one
instance's synthetic pressure doesn't dominate its own list.

## Real caveats observed this run
- **`VDI_CLIENT_OTHER` dominates (~85–92%) even after a stats clear.** It
  reappears immediately from the container's background VDI/snapshot client, not
  from any demo. It's benign here; the differentiated waits are what to read.
  On a real box you'd rarely see this — it's a dev-container artifact.
- **Cumulative-stats reminder still applies** if you *don't* clear first: run
  this demo standalone/first, or `DBCC SQLPERF(... CLEAR)` before seeding (as
  done here).
- Earlier full-fleet rehearsals also saw `docker compose restart sqlserver1
  sqlserver2` OOM-kill a container (exit 137) with all four SQL instances + dab
  + mcp-server on one host. Prefer targeted `KILL` of the load-loop sessions, or
  just `docker compose --profile fleet down -v` when finished.

## Result
The estate-wide fan-out worked across all four instances, `Promise.allSettled`
style (`instances_failed: 0`), and surfaced `ASYNC_NETWORK_IO` on exactly one
member — the app-tier diagnosis the demo is built to deliver.

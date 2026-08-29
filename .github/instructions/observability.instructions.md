---
applyTo: "**"
description: "Observability SOP: standardized health snapshot and incident report for any SQL Server instance"
---

# Skill: Observability — Health Snapshot

## When this skill applies
The user asks for a health check, health snapshot, incident report, "what's wrong
with this server," or performance triage without a more specific symptom.

## Persona
You produce the estate's standard incident report. The value of this skill is
**consistency**: the same tool sequence, the same thresholds, the same report shape,
every time, on every instance — so reports are comparable across days and servers.

## Procedure — always in this order
1. `get_server_info` — version, uptime, CPU/RAM, and the four config values below.
2. `get_database_info` — recovery models, sizes, `log_reuse_wait_desc` per database.
3. `get_wait_stats` — top waits by percentage (benign waits already filtered).
4. `get_top_queries` ordered by CPU, top 5 — capture avg CPU ms, executions,
   avg logical reads.
5. `get_blocking_chains` — current blocking, if any.
6. `get_missing_indexes` — top recommendations by impact score.
7. Only if step 3 flags it: `get_file_io_stats` (PAGEIOLATCH dominant),
   `get_memory_usage` (RESOURCE_SEMAPHORE / low PLE), `get_cpu_history`
   (SOS_SCHEDULER_YIELD dominant), `get_tempdb_usage` (PAGELATCH on tempdb).

## Configuration baselines
| Setting | This estate's standard | Flag if |
|---|---|---|
| max degree of parallelism | 2–8, sized to NUMA/core count | 0 (unlimited) or > cores |
| cost threshold for parallelism | 50 | ≤ 5 (default) |
| max server memory (MB) | capped, ~75–80% of box RAM | 2147483647 (uncapped) |
| optimize for ad hoc workloads | 1 | 0 with high single-use plan count |

## Wait-stat interpretation table
| Dominant wait | Read it as | Follow-up tool |
|---|---|---|
| PAGEIOLATCH_* ≥ 30% | Storage read latency or missing indexes forcing scans | `get_file_io_stats`, `get_missing_indexes` |
| SOS_SCHEDULER_YIELD ≥ 15% | CPU pressure | `get_cpu_history`, `get_top_queries` (cpu) |
| LCK_M_* ≥ 10% | Blocking / transaction design | `get_blocking_chains`, `get_long_running_transactions` |
| ASYNC_NETWORK_IO ≥ 30% | Client consuming results slowly — app tier, not the DB | (report; out of DB scope) |
| RESOURCE_SEMAPHORE any | Memory grant starvation | `get_memory_usage`, `get_top_queries` (memory) |
| WRITELOG ≥ 10% | Log write latency | `get_file_io_stats` (log files), `get_vlf_count` |
| HADR_SYNC_COMMIT ≥ 10% | Sync replica slow — switch to the Availability skill | `get_ag_health` |

## Report rules
- **Severity is the max of any finding**, stated in the first line.
- File-latency thresholds: reads < 10 ms healthy, 10–20 ms warning, > 20 ms critical;
  log writes < 5 ms healthy, > 10 ms critical.
- Missing-index recommendations: include the ready-to-run DDL, but always append
  "test in non-prod; verify against `get_index_usage_stats` for overlap" — the
  optimizer over-suggests.
- Config findings are reported even when performance is currently fine — drift is
  the finding, symptoms are optional.
- Close every report with **What I did NOT check** (e.g., Query Store regressions,
  deadlock history) so scope is auditable.

## Hard boundaries
- Do not run step-7 tools speculatively on a healthy server; the snapshot should be
  6–7 calls, not 15. Cost discipline is part of the SOP.
- No configuration change scripts unless the user asks; findings first.

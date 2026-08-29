# Recordings Index — Fallback Transcripts

Real command + real output, captured live on 2026-08-28 from a complete
teardown (`docker compose --profile fleet down -v`, all volumes removed)
through every demo in order, against the self-contained
`compose/docker-compose.yml` stack. Use these as a text fallback if a live demo
stalls on stage — copy the exact tool call and paste the recorded output while
you narrate.

> **Run wiring:** the compose file lives in `compose/` and `.env` at the repo
> root, so set `export COMPOSE_FILE=compose/docker-compose.yml
> COMPOSE_ENV_FILES=.env` once per shell (from the repo root). The seed/reset
> scripts under `demos/sql/` set these themselves, so they work from
> `demos/sql/` regardless.

| File | Demo | Status |
|---|---|---|
| [00-intro-and-architecture.md](00-intro-and-architecture.md) | Demo 0 | Narration only, no commands |
| [01-install-and-configure.md](01-install-and-configure.md) | Demo 1 | ✅ Full teardown → fresh bring-up, list_instances + get_server_info |
| [02-blocking-and-dab.md](02-blocking-and-dab.md) | Demo 2 | ✅ Two-level blocking chain (DAB scan as the middle link) + real DAB timeout |
| [03-skill-availability-ag-health.md](03-skill-availability-ag-health.md) | Demo 3 | ✅ Full healthy → CRITICAL (suspend) → healthy cycle, fresh AG |
| [04-skill-backup-recovery.md](04-skill-backup-recovery.md) | Demo 4 | ✅ All 4 seeded databases + LOG_BACKUP smoking gun, policy blind spot confirmed |
| [05-skill-security-audit.md](05-skill-security-audit.md) | Demo 5 | ✅ Most reliable in the set — all four findings first try |
| [06-skill-observability.md](06-skill-observability.md) | Demo 6 | ✅ All 7 steps, real 89% missing-index recommendation; cumulative-wait caveat |
| [07-trust-and-guardrails-wrapup.md](07-trust-and-guardrails-wrapup.md) | Demo 7 | Narration only, no commands |
| [bonus-fleet-wide-waits.md](bonus-fleet-wide-waits.md) | Bonus | ✅ Four-instance fan-out; ASYNC_NETWORK_IO isolated to SqlServer2 |
| [bonus-maintenance-neglect.md](bonus-maintenance-neglect.md) | Bonus | ✅ Fresh SqlServer3, failed job + 37% fragmentation (mind the page-count floor) |
| [bonus-deadlocks-and-tempdb.md](bonus-deadlocks-and-tempdb.md) | Bonus | ✅ Fresh SqlServer4, deadlock victim captured from the XE ring buffer |
| [bonus-snapshot-freeze-safety.md](bonus-snapshot-freeze-safety.md) | Bonus | ⛔ Not runnable here — requires external Fusion MCP |

## What to know from this full run (all reflected in the demo files)
1. **Compose file moved to `compose/`.** The seed/reset scripts and the AG
   helper scripts were updated to locate it + the root `.env` via absolute
   paths, so they work when run from `demos/sql/` or the repo root. If you set
   `COMPOSE_ENV_FILES=.env` (relative) at the repo root and then `cd` elsewhere,
   your own `docker compose` calls need an absolute env path — the scripts
   already handle this for themselves.
2. **Demo 2 came back a two-level chain** — the DAB REST scan was the middle
   link between the head blocker and the SELECT victim. An even cleaner
   cross-MCP-contention illustration than a single blocker.
3. **Cumulative wait stats** still bury the fleet signal if you don't clear
   first. Demo 6 shows this honestly; the fleet-waits bonus was captured after a
   `DBCC SQLPERF(... CLEAR)` on all four instances.
4. **`VDI_CLIENT_OTHER`** dominates wait stats in this dev container even right
   after a clear — a container/VDI artifact, not a demo signal. The
   differentiated waits (e.g. `ASYNC_NETWORK_IO` on SqlServer2) are what to read.
5. **Small-table thresholds:** the maintenance-neglect fragmentation (37%) sits
   under `get_index_fragmentation`'s default 1000-page floor — pass a lower
   `min_page_count` to surface it on stage.
6. **`get_statistics_health`** and **`get_tempdb_usage` top-sessions**
   consistently show no positive finding in this small environment — expected,
   documented in both demo files.

## Final environment state
Full teardown was run again after this recording session completed —
`docker compose --profile fleet down -v`, all containers and volumes removed.
Nothing is left running. To rehearse again, start from
[01-install-and-configure.md](01-install-and-configure.md).

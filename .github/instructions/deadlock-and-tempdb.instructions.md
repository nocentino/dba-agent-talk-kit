---
applyTo: "**"
description: "Deadlock investigation SOP: system_health XE ring buffer analysis, victim/survivor diagnosis, tempdb pressure correlation"
---

# Skill: Deadlock & TempDB

## When this skill applies
The user asks about deadlocks, "why did my job fail with error 1205," a session getting
rolled back, "is tempdb under pressure," or correlates tempdb spills with poor query
performance.

## Persona
You are reading the `system_health` Extended Events ring buffer — the same data a
deadlock graph XML viewer would show, but translated to plain English. Your job is to
name the victim, name the survivor, state what each was doing, and identify the lock
resource and access order that created the cycle. You also correlate tempdb space with
active session spills to determine if tempdb is the bottleneck or just a bystander.

## Procedure
1. [`get_deadlock_history`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) on the target instance — parse the event timestamp and
   deadlock XML. For each deadlock:
   - **Victim process:** victim-list → victimProcess id → match to process-list → extract
     SPID, login, SQL text (executionStack frames), wait resource, isolation level.
   - **Survivor process:** the non-victim in the process-list → extract same details.
   - **Resources:** process/@waitresource — the lock the victim was waiting for when
     chosen as victim; the survivor held it.
   - **Access order:** Compare the two SQL texts. Victim locks A then B; survivor locks
     B then A → **opposite order** is the root cause.
2. If recent deadlocks exist OR user reports "some sessions are slow right now," run
   [`get_tempdb_usage`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) — report file space and top sessions by user + internal objects.
3. **Correlation:** if tempdb free space is < 10% of total, and a top session shows high
   `internal_objects_alloc_total_kb` (sorts/hashes/spills), tempdb is the constraint.
   If deadlock timestamps align with tempdb growth spikes, the workload spike caused both.

## Thresholds — what "good" looks like here
| Metric | Healthy | Warning | Critical |
|---|---|---|---|
| Recent deadlock count (last 24h) | 0 | 1–5 (pattern emerging) | > 5 (systematic issue) |
| Deadlock wait time (victim) | N/A | > 500 ms (victim waited long before chosen) | N/A |
| TempDB free space | > 50% | 10–50% | < 10% or growing > 100 MB/min |
| Top session internal objects | < 50 MB | 50–200 MB | > 200 MB (spill workload running) |
| TempDB file allocation | Stable | Growing per transaction | Can't shrink / out of space |

## Decision rules
- **Any deadlock = evidence of application access order problem.** Lead with the
  opposite-lock-order finding if present; it's the fix.
- **One-time deadlock vs. recurring pattern:** If `deadlock_history` is empty after
  `seed-deadlocks-tempdb.sh` runs, the demo already succeeded and events aged out of
  the ring buffer (ring buffer is ~128 MB, events roll off). Repeat the seed script
  to refresh.
- **Victim was waiting < 100 ms** → deadlock resolution was very fast, both sessions
  completed quickly after (retry in app logic usually succeeds). Not urgent unless
  errors are cascading.
- **Victim was waiting > 1 sec** → deadlock occurred late in a long transaction; the
  victim lost a lot of work. Priority is: fix access order, add application retry
  logic with exponential backoff.
- **TempDB pressure + deadlock in same window** → separate problems or related? Check
  if the deadlock occurred during a large sort/hash. If yes, the sort exhausted
  resources and the contention increased lock wait time → deadlock was the symptom,
  tempdb was the cause. Fix: add index to avoid the sort, or increase tempdb size
  and move to fast storage.
- **TempDB growing fast but no deadlock** → workload is spilling heavily; this is a
  memory grant + index design problem, not a deadlock. Switch to observability skill.

## Recommended-action templates (draft only; human executes)
- Deadlock fix — application layer (no SQL change): code review to ensure all threads
  lock tables in the same order. Example pattern:
  ```
  -- ALWAYS lock in this order: TableA → TableB → TableC
  BEGIN TRAN
    UPDATE TableA SET ... WHERE ...;
    UPDATE TableB SET ... WHERE ...;
    UPDATE TableC SET ... WHERE ...;
  COMMIT;
  ```
- If application order can't be changed: add `WITH (NOLOCK)` on reads, or partition
  the tables to reduce contention. Draft a schema/retry design, human reviews it.
- TempDB relief (if tempdb is the constraint):
  - Check for missing index that would avoid the sort (consult [`get_missing_indexes`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts))
  - Increase tempdb file size: `ALTER DATABASE tempdb MODIFY FILE (NAME = tempdev, SIZE = <new_size>)`
  - Move tempdb to faster storage if on a shared LUN (advanced DBA change control)

## Hard boundaries
- Never recommend `SET DEADLOCK_PRIORITY HIGH` as a "fix" — it's a jury-rigging band-aid,
  not a solution. The access order is the fix.
- Never draft a stored procedure or application code change; you are not responsible
  for writing the fix, only diagnosing the cause. Recommend the pattern, human codes it.
- Never restart SQL Server to "clear tempdb" — tempdb clears on restart, but deadlocks
  recur immediately if the access order is still wrong. Fix the cause, not the symptom.
- Never recommend `DBCC SHRINKFILE` on tempdb without understanding the spill workload.
  Shrinking can cause allocation contention; if the workload is legitimately large,
  you need bigger tempdb, not smaller.

## Report format
Global format. Title: `Deadlock & TempDB Analysis — <instance> — <date>`. Include:
1. **Deadlock Summary** (if any found):
   - Victim: SPID, login, SQL (first 2 lines), wait resource, wait time
   - Survivor: SPID, login, SQL (first 2 lines), locks held
   - Root Cause: opposite-order / shared-lock escalation / other pattern
   - Recommendation: access order fix + retry logic (application layer)
2. **TempDB Status**:
   - File space table: total/allocated/free, per file
   - Top 5 sessions by internal objects, with allocation trend
   - Assessment: no pressure / moderate / critical
3. **Correlation** (if both findings present):
   - Did tempdb pressure increase during deadlock window? Yes/no → implication
   - Recommended action: fix application order OR improve index / memory

---

## Example Session

**Input:** "Were there any deadlocks recently on SqlServer4? Tell me which session won,
which lost, and what they were doing. Also check tempdb usage while you're in there."

**Process:**
1. Call `get_deadlock_history(SqlServer4)` → find event, extract victim SPID 77, survivor SPID 55
2. Victim text: `UPDATE TableB ... UPDATE TableA ...`; Survivor text: `UPDATE TableA ... UPDATE TableB ...`
3. Pattern: **opposite lock order**
4. Call `get_tempdb_usage(SqlServer4)` → 4 MB file, 3 MB allocated, no major spills
5. Report: "Victim (SPID 77, sa) was waiting 1.6 seconds for a lock on TableB key, which the survivor held. Survivor was waiting for TableA, which victim held. Fix: both must UPDATE in the same order (e.g., always TableA first). TempDB is healthy, no pressure detected."

# Bonus · Deadlocks & TempDB

**A deadlock graph is unreadable XML to most people. The agent reads the same `system_health` ring buffer and tells you — in one sentence — who won, who lost, and why.**

*Optional (~5 min) · requires the fleet profile (SqlServer4).*

---

## Before you start

- Fleet profile up; SqlServer4 registered in `.env`
- Run the fleet setup:
  ```bash
  docker compose --profile fleet up -d
  ```
- Fresh Copilot chat
- **Attach the skill** (recommended for deterministic behavior):
  Click **Add Context → Instructions** and select `.github/instructions/deadlock-and-tempdb.instructions.md`
  This loads the SOP so the agent auto-applies the diagnostic procedure to your prompt

---

## Setup — trigger a deadlock + tempdb pressure

```bash
./demos/sql/seed-deadlocks-tempdb.sh
```

Two sessions update `TableA`/`TableB` in opposite order — a textbook deadlock,
landed in the ring buffer reliably. A background unindexed sort adds tempdb pressure.

---

## The prompt

> Were there any deadlocks recently on SqlServer4? Tell me which session won,
> which lost, and what they were doing. Also check tempdb usage while you're in there.

---

## What you'll see

1. [`get_deadlock_history`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) → victim + survivor, the `UPDATE` statements, the lock resources — **reliable every run**
2. [`get_tempdb_usage`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) → file space is always real; the top-session catch is timing-dependent (honest either way)
3. Synthesis: the opposite-lock-order pattern; the fix is **application access order**, not an index

---

## Why it matters

- Nobody reads deadlock XML by hand — same ring buffer every DBA has, just translated
- The fix for a deadlock is almost never query tuning — watch whether the agent says *access order*
- Whatever tempdb shows is real, live data — that's the point, not catching a spike on cue

---

## The Skill (optional, for consistency)

**`.github/instructions/deadlock-and-tempdb.instructions.md`** — a reusable SOP that:
- Defines when to call [`get_deadlock_history`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) vs [`get_tempdb_usage`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts)
- Names the victim and survivor from the XML
- Identifies opposite-lock-order as the root cause
- Sets thresholds (wait time >500ms = warning, deadlock count >5 = critical)
- Enforces hard boundaries: never recommend `SET DEADLOCK_PRIORITY` as a fix

**Why it matters:** In production, the skill ensures your agent applies the same
diagnostic sequence every time, every instance, every human—no variation. On stage,
attach it for a deterministic 4-minute demo that always hits the same talking points.

---

**Next (bonus):** [Snapshot Freeze-Safety →](bonus-snapshot-freeze-safety.md)

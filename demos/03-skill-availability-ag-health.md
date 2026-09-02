# Demo 3 · Skill: Availability Management (AG Health)

**The first demo *with* a skill attached. The agent follows YOUR runbook — primary first, walk the thresholds table, refuse to bless a failover while the send queue is non-zero.**

---

## Before you start

- Core stack up (`docker compose up -d` — HADR on by default) + `compose/init-ag.sh`
- AG `AG_Products`: SqlServer1 primary, SqlServer2 secondary, `ProductsDB` seeded
- Attach the skill: Add Context → Instructions → [availability.instructions.md](../.github/instructions/availability.instructions.md)

---

## Setup — break it

```bash
./demos/sql/seed-ag-lag.sh       # suspend the secondary + churn log on the primary
```

Secondary goes SUSPENDED / NOT SYNCHRONIZING; the send queue on the primary grows.

---

## The prompt

> Is my availability group healthy? If I had to fail over to the secondary right
> now, could I do it without losing data? Give me the full picture.

---

## What you'll see (the skill talking)

1. [`get_ag_health`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) on **SqlServer1 first** — primary before secondary, because the skill says so
2. Finds `ProductsDB` SUSPENDED / NOT SYNCHRONIZING, send queue growing
3. Classifies against the thresholds table → **CRITICAL**
4. Rules out an open txn + disk-full ([`get_long_running_transactions`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts), [`get_database_files`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts))
5. Answers the failover question: **"No — not safely"**, and drafts `SET HADR RESUME` for a human

---

## Restore health — the before/after

```bash
./demos/sql/resume-ag.sh         # ALTER DATABASE [ProductsDB] SET HADR RESUME
```

Re-ask "check it again" → sync catches up → **HEALTHY**.

---

## Why it matters

- Everything it did came out of a **markdown file** — the ordering, the thresholds, the refusal
- It checked what your best DBA would check, **in the same order**, because you wrote it down
- The thresholds table is the slide-worthy bit — show the skill file for 20 seconds

---

**Next:** [Demo 4 · Skill: Backup & Recovery →](04-skill-backup-recovery.md)

# Demo 2 · Tools Without Skills: Blocking + DAB

**The agent doesn't hand you a query to run. It chains tools, gets the answer, and gives you a diagnosis, then *recommends* the KILL it cannot execute.**

---

## The point

- No skill attached yet, just tools and a good question
- The agent picks the DMV itself, chains calls, and synthesizes
- It **recommends** `KILL`; it **cannot run it** (guardrail #1, paid off in Demo 7)

---

## Setup: seed the blocker

Run this from the repo root **1-2 minutes before** starting the demo:

```bash
./demos/sql/seed-blocking.sh
```

What it does:
- Starts a head blocker: open transaction + `WAITFOR DELAY '00:08:00'` holds an exclusive lock on all `Electronics` rows
- Starts a victim `SELECT` that queues behind the blocker (waits on shared lock)
- Optionally starts a third victim via DAB REST scan
- The blocker will auto-rollback after 8 minutes

**Note:** The script uses file-based SQL execution (not inline `-Q` queries) to keep sqlcmd sessions persistent during WAITFOR.

---

## The prompt

> Are there any blocking sessions right now on SqlServer1? Who is blocking whom,
> how long has the block been in place, and what SQL is running on both sides?
> What should I do about it?

---

## What you'll see

1. Calls [`get_blocking_chains`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts)(instance_name: "SqlServer1") from the tool description alone
2. Names the head blocker (open txn + `WAITFOR`), the `LCK_M_S` waiters, wait time, both SQL texts
3. Recommends `KILL <spid>` **as a script**; it cannot run it

The chain can come back **two levels deep**: the DAB REST scan queues behind the
blocker and then blocks the plain `SELECT` itself. Cross-MCP contention, live.

---

## Cleanup

When you're done with the demo, clear the blocking scenario:

```bash
./demos/sql/clear-blocking.sh
```

This kills the blocker session and returns the database to a clean state.

---

## Why it matters

- It picked the tool from the description; you never named a DMV
- Blocker SQL text comes from `most_recent_sql_handle` (First Responder Kit pattern)
- **The trust story in one screenshot:** `sql-dba` is SELECT-only, enforced in code, not a prompt
- It diagnoses; **you decide**

---

**Next:** [Interlude · Anatomy of a Skill File →](02b-anatomy-of-a-skill-file.md)

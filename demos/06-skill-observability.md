# Demo 6 · Skill: Observability

**[`get_wait_stats`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) alone tells you a number. The skill runs the *same seven-step sequence* every time and turns it into one incident report with a single severity line. Consistency is the value.**

---

## Before you start

- Fresh Copilot chat; attach [observability.instructions.md](../.github/instructions/observability.instructions.md)
- Stack up, `sql-dba` tools visible

---

## Setup: seed a little real load

```bash
./demos/sql/seed-observability-load.sh
```

~20k skewed rows (`Electronics` ≈ 3%) + ~30 filtered/join queries, just enough
to give [`get_missing_indexes`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) a real, high-impact recommendation.

---

## The prompt

> Pull a full health snapshot of SqlServer1: server info, databases, wait
> stats, top queries by CPU, any blocking, and missing indexes. Write it up as
> an incident report.

---

## What you'll see: the same order, every time

1. [`get_server_info`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) → four config baselines (MAXDOP, CTFP, max memory, ad-hoc)
2. [`get_database_info`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) → recovery model, size, `log_reuse_wait_desc`
3. [`get_wait_stats`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) → top waits, benign filtered out
4. [`get_top_queries`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts)(cpu, 5) → the seeded filter query near the top
5. [`get_blocking_chains`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) → "none" is a valid finding
6. [`get_missing_indexes`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) → composite on `Products(Category, Discontinued) INCLUDE (UnitPrice)` ~89%

---

## Why it matters

- Same seven calls, same order, healthy or on fire; **the SOP doesn't change with the model's mood**
- Config drift is reported even when nothing's wrong; *drift is the finding*
- Missing-index DDL ships with a "check for overlap first" warning; don't trust the optimizer blindly
- Report closes with **"What I did NOT check"**; scope you can trust

---

**Next:** [Demo 7 · Trust & Guardrails →](07-trust-and-guardrails-wrapup.md)

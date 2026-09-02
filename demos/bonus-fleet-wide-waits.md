# Bonus · Fleet-Wide Wait Stats

**One question, parallel fan-out, one synthesized answer across the whole estate. The "get your arms around a complex estate" moment.**

*Optional — not in the 60-minute core (~4 min).*

---

## Before you start

- SqlServer1 + SqlServer2 registered in `.env` `INSTANCES`
- Bigger version: bring up the fleet profile for a four-instance fan-out
  (`docker compose --profile fleet up -d`, see [compose/README.md](../compose/README.md#fleet-profile-bonus-demos))
- **Clear stats first** for a clean signal: `DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR)` on each

---

## Setup — differentiated load

```bash
./demos/sql/seed-fleet-load.sh    # start 2–3 min before
```

- **SqlServer1** — IO + CPU pressure (repeated scans that force physical reads)
- **SqlServer2** — a slow client dribbling a huge result set → `ASYNC_NETWORK_IO`

---

## The prompt

> Check wait stats on all my SQL Server instances and tell me if there are any
> concerns. Compare the instances — are they suffering from the same problem or
> different ones?

---

## What you'll see

1. [`list_instances`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) → finds them all
2. [`fan_out_query`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) / per-instance [`get_wait_stats`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) — parallel across the estate
3. **SqlServer1** → IO/CPU pressure; **SqlServer2** → `ASYNC_NETWORK_IO`
4. Key call: the second one is an **app-tier** problem, not a database problem

---

## Why it matters

- The benign-wait filter is First Responder Kit heritage — no `CXCONSUMER` noise
- One instance down doesn't break it — `Promise.allSettled`, degrades gracefully
- `ASYNC_NETWORK_IO` → "go look at the app tier" — the answer a lot of humans get wrong

---

**That's the kit.** [← Back to the demo index](README.md)

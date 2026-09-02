# Demo 4 · Skill: Backup & Recovery Posture

**Without the skill, [`get_backup_status`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) returns timestamps. With it, the agent ranks databases by *minutes of data loss* against your RPO policy. Policy in, judgment out.**

---

## Before you start

- Fresh Copilot chat. Seed script run (below) — time-independent, nothing goes stale
- Have [backup-recovery.instructions.md](../.github/instructions/backup-recovery.instructions.md) ready — but **run the prompt once without it first**

---

## Setup — three violations, one clean control

```bash
./demos/sql/seed-backup-gaps.sh
```

- **PaymentsDB** — FULL recovery, full backup, **no log backups ever** [Violation: unbounded RPO]
- **ClaimsDB** — **no backup at all** (unrecoverable) [Critical: no restore chain]
- **OrdersProdDB** — Tier-1 but **SIMPLE recovery** (policy mismatch) [Violation: no PIT recovery]
- **InventoryDB** — full + log, compliant (the control) [Reference: production-ready]

---

## The prompt

> What's the backup situation across this instance? Treat PaymentsDB, ClaimsDB,
> and OrdersProdDB as Tier-1. If we lost the server right now, what would we
> actually lose, database by database?

---

## With the skill attached

1. Calls [`get_backup_status`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) — last full, last log per database
2. Calls [`get_database_info`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) — recovery models, log_reuse_wait_desc, sizes
3. Ranks by **minutes of data loss** against Tier-1 RPO (15 min)
4. Names which databases violate policy and why

| Database | Tier | RPO Policy | Data Loss NOW | Status |
|---|---|---|---|---|
| **ClaimsDB** | 1 | 15 min | **ALL (unrecoverable)** | **CRITICAL** |
| **PaymentsDB** | 1 | 15 min | **~1 hour** | **CRITICAL** |
| **OrdersProdDB** | 1 | 15 min | **~1 hour** (no PIT possible) | **CRITICAL** |
| InventoryDB | — | — | ~1 min | OK |

---

## Why it matters

- [`get_backup_status`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) didn't change — **the skill changed what the answer means**
- Exposure in **minutes of data loss** is the number the business understands
- The standing line, baked into the skill: *a backup never test-restored is a hypothesis*

---

**Next:** [Demo 5 · Skill: Security & Auditing →](05-skill-security-audit.md)

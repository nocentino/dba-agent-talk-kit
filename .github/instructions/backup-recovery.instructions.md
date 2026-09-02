---
applyTo: "**"
description: "Backup and recovery SOP: evaluate backup posture against the estate's RPO/RTO policy, quantify exposure, draft recovery plans"
---

# Skill: Backup & Recovery

## When this skill applies
The user asks about backups, restore capability, RPO/RTO, "what's my exposure,"
log growth caused by backup gaps, or requests a recovery plan for a database.

## Persona
You are auditing backup posture **against policy**, not just reporting timestamps.
A backup report without a policy comparison is noise. Your job is to turn
"last log backup was 04:12" into "Tier-1 database X is 47 minutes past its RPO —
you would lose up to 62 minutes of data right now."

## Backup policy for this estate (the yardstick)
| Tier | Recovery model | Full | Diff | Log | Max tolerable data loss (RPO) | Max restore time (RTO) |
|---|---|---|---|---|---|---|
| Tier-1 (revenue / customer-facing) | FULL | Daily | — | Every 15 min | 15 min | 1 h |
| Tier-2 (internal LOB) | FULL | Daily | Every 6 h | Every 60 min | 1 h | 4 h |
| Tier-3 (dev / scratch) | SIMPLE | Weekly | — | — | 24 h | Best effort |

Tier assignment: databases are tagged in the estate inventory; if untagged, ask the
user or assume Tier-1 for anything with "Prod" semantics and say you assumed it.

## Procedure
1. [`list_instances`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts), then [`get_backup_status`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) on each in-scope instance. Collect per
   database: recovery model, last full, last diff, last log.
2. [`get_database_info`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) — cross-check recovery model and `log_reuse_wait_desc`.
   `LOG_BACKUP` as the reuse wait on a FULL-recovery database with no recent log
   backup is the smoking gun for both RPO exposure AND impending log growth.
3. [`get_database_files`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) — if log reuse is blocked, report current log size and growth
   settings so the human sees the secondary blast radius (disk fill).
4. For every database, compute **current exposure** = time since last log backup
   (FULL recovery) or time since last full (SIMPLE). Compare to the tier's RPO.
5. If the user asks for a recovery plan: enumerate the restore chain
   (full → latest diff → logs in sequence), estimate restore time from backup sizes,
   and state the exact point-in-time recoverable to.

## Decision rules
- **FULL recovery + zero log backups ever** → CRITICAL. Exposure is unbounded
  (everything since the last full). This also means the log never truncates.
- **No full backup at all** → CRITICAL. The database is unrecoverable. Nothing else
  about it matters until this is fixed. Lead with it.
- **Recovery model contradicts tier policy** (e.g., Tier-1 in SIMPLE) → CRITICAL
  policy violation even if backups are "current" — point-in-time recovery is
  impossible in SIMPLE.
- **Log backup late but < 2× RPO** → WARNING; likely a stalled job — check
  [`get_job_status`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) for the log backup job before assuming worse.
- Always express exposure in **minutes of data loss right now**, per database,
  ranked worst-first. Humans act on that number.

## Recommended-action templates (draft only; human executes)
- Missing full: `BACKUP DATABASE [<db>] TO DISK = N'<path>' WITH CHECKSUM, COMPRESSION;`
- Start log chain: full first, then
  `BACKUP LOG [<db>] TO DISK = N'<path>' WITH CHECKSUM, COMPRESSION;` on the policy cadence.
- Tier mismatch: `ALTER DATABASE [<db>] SET RECOVERY FULL;` **plus** an immediate
  full backup (the model change is meaningless until a full establishes the chain —
  say this explicitly).

## Hard boundaries
- Never draft a RESTORE against an existing database without `WITH REPLACE` called
  out in red and a statement of what will be destroyed. Prefer restoring to a new
  name (`RESTORE ... MOVE ...`) in every plan unless the user explicitly says overwrite.
- Never mark posture healthy based on backup **existence** alone — a backup that has
  never been test-restored is a hypothesis. If the estate has no restore-test history
  to check, include that as a standing risk in every report.
- Do not recommend `BACKUP LOG ... WITH TRUNCATE_ONLY` era hacks or switching to
  SIMPLE to "fix" log growth on a Tier-1/Tier-2 database.

## Report format
Global format. Title: `Backup Posture — <scope>`. Include an exposure table:
database | tier | recovery model | last full | last log | exposure now | RPO | status.

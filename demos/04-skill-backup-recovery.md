# Demo 4 — Skill: Backup & Recovery Posture (Objective 2, ~5 min)

**Point being made:** without the skill, `get_backup_status` returns timestamps.
With the skill, the agent evaluates timestamps **against your RPO policy** and ranks
databases by minutes of data loss. Policy in, judgment out. This demo feeds the
"money slide" (with/without comparison) that follows it.

## Pre-demo state
- Fresh Copilot chat, attach `backup-recovery.instructions.md` as context.
- Seed script run (below). Time-independent scenarios — nothing here goes stale
  during a long conference day.

## Setup — three violations, one clean database
`demos/sql/seed-backup-gaps.sql` (run via sqlcmd on SqlServer1):

```sql
-- DB 1: Tier-1, FULL recovery, full backup taken, NO log backups ever.
-- Violation: unbounded RPO exposure + log will never truncate.
CREATE DATABASE [PaymentsDB];
ALTER DATABASE [PaymentsDB] SET RECOVERY FULL;
BACKUP DATABASE [PaymentsDB] TO DISK = N'/var/opt/mssql/data/PaymentsDB.bak'
  WITH CHECKSUM, COMPRESSION, INIT;
-- generate log activity so exposure is real
USE [PaymentsDB];
CREATE TABLE dbo.Ledger (ID INT IDENTITY PRIMARY KEY, Amount MONEY, At DATETIME2 DEFAULT SYSUTCDATETIME());
INSERT INTO dbo.Ledger (Amount) SELECT TOP (50000) 1.00 FROM sys.all_objects a CROSS JOIN sys.all_objects b;

-- DB 2: Tier-1, NO full backup at all. Unrecoverable.
CREATE DATABASE [ClaimsDB];
ALTER DATABASE [ClaimsDB] SET RECOVERY FULL;

-- DB 3: "Prod" semantics but SIMPLE recovery. Policy mismatch:
-- point-in-time recovery impossible regardless of backup cadence.
CREATE DATABASE [OrdersProdDB];
ALTER DATABASE [OrdersProdDB] SET RECOVERY SIMPLE;
BACKUP DATABASE [OrdersProdDB] TO DISK = N'/var/opt/mssql/data/OrdersProdDB.bak'
  WITH CHECKSUM, COMPRESSION, INIT;

-- DB 4: the control - fully compliant so the report isn't all red.
CREATE DATABASE [InventoryDB];
ALTER DATABASE [InventoryDB] SET RECOVERY FULL;
BACKUP DATABASE [InventoryDB] TO DISK = N'/var/opt/mssql/data/InventoryDB.bak'
  WITH CHECKSUM, COMPRESSION, INIT;
BACKUP LOG [InventoryDB] TO DISK = N'/var/opt/mssql/data/InventoryDB_log.trn'
  WITH CHECKSUM, COMPRESSION, INIT;
```

Re-run `BACKUP LOG [InventoryDB] ...` right before going on stage so the control
database is inside its 15-minute RPO window at demo time.

## The prompt
> What's the backup situation across this instance? Treat PaymentsDB, ClaimsDB, and
> OrdersProdDB as Tier-1. If we lost the server right now, what would we actually
> lose, database by database?

## Expected agent behavior (the skill talking)
1. `get_backup_status` + `get_database_info` (cross-checks `log_reuse_wait_desc` —
   PaymentsDB shows LOG_BACKUP, the smoking gun).
2. Leads with **ClaimsDB: CRITICAL — no full backup, unrecoverable** (skill rule:
   nothing else about it matters until this is fixed).
3. PaymentsDB: CRITICAL — exposure unbounded since last full; log never truncating;
   probably pulls `get_database_files` to show the growing log.
4. OrdersProdDB: CRITICAL policy violation — SIMPLE on a Tier-1; PIT recovery
   impossible; the fix script explicitly says the model change is meaningless
   until a new full establishes the chain.
5. InventoryDB: HEALTHY — inside RPO. (The control proves it's not just alarmist.)
6. Exposure table ranked worst-first, remediation drafted, human executes.

## Talking points
- "`get_backup_status` didn't change. The SKILL changed what the answer means."
- "Exposure in minutes-of-data-loss is the number your business understands.
  The skill forces that framing every single time."
- "And the standing line in every report: a backup that's never been test-restored
  is a hypothesis. I put my paranoia in the skill so the agent has it too."

## Reset
```sql
DROP DATABASE IF EXISTS [PaymentsDB];
DROP DATABASE IF EXISTS [ClaimsDB];
DROP DATABASE IF EXISTS [OrdersProdDB];
DROP DATABASE IF EXISTS [InventoryDB];
```

## Failure modes / fallback
- Agent doesn't rank ClaimsDB first → follow-up: "which of these is the most urgent
  and why?" — it will course-correct against the skill. Narrate that skills tighten,
  not perfect, behavior.
- Fallback recording: `demo4-backup.mp4`.

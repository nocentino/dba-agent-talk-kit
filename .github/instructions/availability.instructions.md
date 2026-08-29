---
applyTo: "**"
description: "Availability management SOP: Always On AG health checks, sync state evaluation, failover readiness for the SQL Server estate"
---

# Skill: Availability Management

## When this skill applies
The user asks about Always On Availability Groups, replica health, synchronization,
send/redo queues, failover readiness, RPO/RTO exposure on the data-movement path, or
says anything like "is my AG healthy," "can I fail over," "are my secondaries caught up."

## Persona
You are performing the availability portion of the estate's daily and incident-time
checks. The estate standard is: every Tier-1 database is in an AG with at least one
synchronous replica; failover must be possible at any moment without data loss.

## Procedure
1. `list_instances` — identify all registered instances; AG topology may span them.
2. `get_ag_health` on the **primary** first, then each secondary. Collect for every
   replica/database pair: role, synchronization_state, synchronization_health,
   send_queue_kb, redo_queue_kb, redo_rate_kb_sec, last_commit_time.
3. If any database shows `NOT SYNCHRONIZING`, `SUSPENDED`, or a growing queue, run
   `get_wait_stats` on the affected replica and check for HADR_* waits, then
   `get_long_running_transactions` on the primary (an open transaction blocks log
   truncation and inflates send queues).
4. If redo is the concern, run `get_vlf_count` on the affected database — VLF counts
   above threshold serialize redo — and `get_file_io_stats` on the secondary to rule
   out storage latency on the log/data files.
5. `get_backup_status` — confirm log backups are running; log backup failures on any
   replica surface as availability risk during long outages.

## Thresholds — what "good" looks like here
| Metric | Healthy | Warning | Critical |
|---|---|---|---|
| synchronization_health | HEALTHY | PARTIALLY_HEALTHY | NOT_HEALTHY |
| Sync replica state | SYNCHRONIZED | SYNCHRONIZING > 5 min | NOT SYNCHRONIZING / SUSPENDED |
| send_queue_kb (sync replica) | < 1,000 | 1,000–10,000 | > 10,000 or growing 3 checks in a row |
| redo_queue_kb | < 10,000 | 10,000–100,000 | > 100,000 |
| redo_rate vs log generation | redo ≥ generation | redo 50–99% of generation | redo < 50% of generation |
| VLF count per database | < 300 | 300–1,000 | > 1,000 |
| Estimated data loss (async) | < 15 s | 15–60 s | > 60 s |

## Decision rules
- **SUSPENDED data movement** → report as CRITICAL. Most common causes in this
  estate: manual suspend, disk full on secondary, log growth failure. Check
  `get_database_files` for free-space/growth settings before recommending resume.
  Recommended action: `ALTER DATABASE [<db>] SET HADR RESUME` — draft it, human runs it.
- **Send queue growing on primary** → look for an open transaction
  (`get_long_running_transactions`) or network between replicas; do NOT recommend
  failover while the send queue is non-trivial on a sync replica — that is data loss.
- **Redo queue growing on secondary** → the secondary is behind for reads and slow
  for failover (RTO risk). Correlate with VLF count and secondary storage latency.
  If VLF > 1,000, include a log-shrink-and-regrow maintenance plan as the fix.
- **Failover readiness question** → answer with a yes/no per database, justified by
  sync state and send queue, plus the estimated data-loss window for async replicas.

## Hard boundaries
- Never draft `ALTER AVAILABILITY GROUP ... FAILOVER` with `FORCE_FAILOVER_ALLOW_DATA_LOSS`
  unless the user has explicitly stated the primary is lost AND acknowledges data loss.
  Even then, present it with a red warning block and require them to type the command.
- Never recommend restarting SQL Server or the container as a first-line fix.
- Suspend/resume of data movement is a human action. Draft the script; do not treat
  a "yes" in chat as execution authority — you cannot execute it anyway.

## Report format
Use the global report format. Title: `AG Health — <AG name>`. Include a per-replica
table (role, state, health, send queue, redo queue, est. data loss) before the
interpretation section.

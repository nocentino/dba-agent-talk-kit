# Recording — Demo 3: Skill: Availability Management (AG Health)

Captured live on 2026-08-28 against the consolidated compose file
(`compose/docker-compose.yml`). HADR is on by default, so the AG comes up from
`docker compose up -d` + `./compose/init-ag.sh`; no separate overlay file.
Full healthy → CRITICAL → healthy cycle below.

## 0. Baseline (from init-ag.sh + verify-ag.sh)
```bash
$ ./compose/init-ag.sh && ./compose/verify-ag.sh
```
Both replicas start `SYNCHRONIZED` / `HEALTHY` (SqlServer1 PRIMARY, SqlServer2
SECONDARY, database `ProductsDB`).

## 1. Break it — seed AG lag
```bash
$ cd demos/sql
$ ./seed-ag-lag.sh
```
```
AG lag seeded: secondary SUSPENDED, log generating on primary.
```

## 2. Tool call: get_ag_health on the PRIMARY first (skill orders it)
```
get_ag_health(instance_name: "SqlServer1")
```
```json
{
  "ag_health": [
    {
      "ag_name": "AG_Products",
      "replica_server_name": "sqlserver1",
      "role_desc": "PRIMARY",
      "availability_mode_desc": "SYNCHRONOUS_COMMIT",
      "synchronization_health_desc": "HEALTHY",
      "synchronization_state_desc": "SYNCHRONIZED",
      "is_suspended": false,
      "last_commit_time": "2026-08-29T00:09:36.957Z"
    },
    {
      "ag_name": "AG_Products",
      "replica_server_name": "sqlserver2",
      "role_desc": "SECONDARY",
      "availability_mode_desc": "SYNCHRONOUS_COMMIT",
      "synchronization_health_desc": "NOT_HEALTHY",
      "synchronization_state_desc": "NOT SYNCHRONIZING",
      "is_suspended": true,
      "suspend_reason_desc": "SUSPEND_FROM_USER",
      "redo_queue_mb": "0",
      "last_commit_time": "2026-08-29T00:08:30.380Z",
      "last_hardened_time": "2026-08-29T00:08:30.383Z",
      "estimated_data_loss_seconds": 0
    }
  ]
}
```
The primary's own view already exposes the problem on the secondary:
`is_suspended = true`, `suspend_reason_desc = SUSPEND_FROM_USER`, state
`NOT SYNCHRONIZING`, health `NOT_HEALTHY`. The secondary's `last_commit_time`
lags the primary's by ~66 seconds — that gap is the exposure. Classified
against the skill's thresholds table → **CRITICAL**.

`get_ag_health(instance_name: "SqlServer2")` returns the same secondary row
(`is_local: true` there) — consistent from both sides.

## 3. Skill's decision-rule follow-ups
The availability skill says: on a suspend, rule out an open transaction and
disk-full before recommending resume.
```
get_long_running_transactions(instance_name: "SqlServer1")
```
```
No transactions running longer than 0 seconds.
```
```
get_database_files(instance_name: "SqlServer1", database_name: "ProductsDB")
```
```json
{
  "database_files": [
    { "logical_name": "ProductsDB",     "file_type": "ROWS", "size_mb": 8,  "growth_setting": "64 MB", "max_size": "Unlimited" },
    { "logical_name": "ProductsDB_log", "file_type": "LOG",  "size_mb": 72, "growth_setting": "64 MB", "max_size": "Unlimited" }
  ]
}
```
No blocking open transaction, log file has room and unlimited growth — so the
suspend is **not** disk-driven. Cause is the manual `SUSPEND_FROM_USER` the tool
already reported.

## 4. The verdict
Failover question answered **"No — not without risk"**: the secondary is
`NOT SYNCHRONIZING`, so it is not a safe synchronous failover target right now.
Recommended action, drafted for a human to run (never executed by the agent):
```sql
ALTER DATABASE [ProductsDB] SET HADR RESUME;
```

## 5. Restore health (the satisfying before/after)
```bash
$ ./resume-ag.sh
```
```
Data movement resumed.
```
Re-check after ~12 s:
```
get_ag_health(instance_name: "SqlServer1")
```
```json
{
  "ag_health": [
    { "replica_server_name": "sqlserver1", "role_desc": "PRIMARY",   "synchronization_health_desc": "HEALTHY", "synchronization_state_desc": "SYNCHRONIZED", "is_suspended": false, "last_commit_time": "2026-08-29T00:09:36.957Z" },
    { "replica_server_name": "sqlserver2", "role_desc": "SECONDARY", "synchronization_health_desc": "HEALTHY", "synchronization_state_desc": "SYNCHRONIZED", "is_suspended": false, "send_queue_mb": "0", "redo_queue_mb": "0", "last_commit_time": "2026-08-29T00:09:36.957Z", "last_hardened_time": "2026-08-29T00:10:04.790Z" }
  ]
}
```
Secondary caught up — `last_commit_time` now matches the primary, queues at 0,
health `HEALTHY`. (`estimated_data_loss_seconds` briefly showed `-28`, a
harmless container clock-skew artifact between the two instances.)

## Result
Clean healthy → CRITICAL → healthy cycle. Primary-first ordering, the suspend
classification, the open-transaction and disk-full rule-outs, and the refusal
to bless the failover all came straight out of the skill file.

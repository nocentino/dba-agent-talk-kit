# Recording — Demo 4: Skill: Backup & Recovery Posture

Captured live on 2026-08-28. Four seeded databases with deliberately different
backup postures, plus `ProductsDB` (the live AG database) as a real bystander.

## 1. Seed the scenario
```bash
$ export COMPOSE_FILE=compose/docker-compose.yml COMPOSE_ENV_FILES=.env
$ source .env
$ docker compose exec -T sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U sa -P "$SA_PASSWORD" -C < demos/sql/seed-backup-gaps.sql
```
```
Processed 360 pages for database 'PaymentsDB' ...
BACKUP DATABASE successfully processed 362 pages ... (PaymentsDB)
(50000 rows affected)
BACKUP DATABASE successfully processed 362 pages ... (OrdersProdDB)
BACKUP DATABASE successfully processed 362 pages ... (InventoryDB)
BACKUP LOG successfully processed 3 pages ...      (InventoryDB)
```
(`ClaimsDB` is created with no backup at all — that's the point.)

## 2. Tool call: get_backup_status
```
get_backup_status(instance_name: "SqlServer1")
```
```json
{
  "backup_status": [
    { "database_name": "ClaimsDB",     "recovery_model_desc": "FULL",   "last_full_backup": null,                       "last_log_backup": null,                       "backup_health": "NEVER_BACKED_UP" },
    { "database_name": "PaymentsDB",    "recovery_model_desc": "FULL",   "last_full_backup": "2026-08-29T00:10:59.000Z", "last_log_backup": null,                       "backup_health": "NO_LOG_BACKUPS" },
    { "database_name": "OrdersProdDB",  "recovery_model_desc": "SIMPLE", "last_full_backup": "2026-08-29T00:11:00.000Z", "last_log_backup": null,                       "backup_health": "OK" },
    { "database_name": "InventoryDB",   "recovery_model_desc": "FULL",   "last_full_backup": "2026-08-29T00:11:00.000Z", "last_log_backup": "2026-08-29T00:11:00.000Z", "backup_health": "OK" },
    { "database_name": "ProductsDB",    "recovery_model_desc": "FULL",   "last_full_backup": "2026-08-29T00:02:50.000Z", "last_log_backup": "2026-08-29T00:02:39.000Z", "backup_health": "OK" }
  ]
}
```

## 3. Cross-check: get_database_info (the log_reuse_wait smoking gun)
```
get_database_info(instance_name: "SqlServer1")
```
Key rows:
```json
{ "name": "ClaimsDB",     "recovery_model_desc": "FULL",   "log_reuse_wait_desc": "NOTHING",    "log_mb": "8"  }
{ "name": "PaymentsDB",   "recovery_model_desc": "FULL",   "log_reuse_wait_desc": "LOG_BACKUP", "log_mb": "72" }
{ "name": "OrdersProdDB", "recovery_model_desc": "SIMPLE", "log_reuse_wait_desc": "NOTHING",    "log_mb": "8"  }
{ "name": "InventoryDB",  "recovery_model_desc": "FULL",   "log_reuse_wait_desc": "NOTHING",    "log_mb": "8"  }
```
`PaymentsDB` shows `log_reuse_wait_desc = LOG_BACKUP` with a 72 MB log — one
signal that proves both the RPO exposure **and** the impending log-growth
problem at the same time.

## 4. Skill step: show the trapped log — get_database_files
```
get_database_files(instance_name: "SqlServer1", database_name: "PaymentsDB")
```
```json
{
  "database_files": [
    { "logical_name": "PaymentsDB",     "file_type": "ROWS", "size_mb": 8,  "growth_setting": "64 MB", "max_size": "Unlimited" },
    { "logical_name": "PaymentsDB_log", "file_type": "LOG",  "size_mb": 72, "growth_setting": "64 MB", "max_size": "Unlimited" }
  ]
}
```
The log can only grow — with no log backup it never truncates. Secondary blast
radius: disk fill.

## Interpretation the skill produces (ranked worst-first)
1. **ClaimsDB — CRITICAL, unrecoverable.** FULL recovery, `NEVER_BACKED_UP`.
   Nothing else about it matters until a full backup exists. Lead with it.
2. **PaymentsDB — CRITICAL, unbounded exposure.** Full exists but zero log
   backups; everything since the last full is at risk and the log never
   truncates (`LOG_BACKUP` reuse wait, 72 MB and climbing).
3. **OrdersProdDB — CRITICAL policy violation.** Treated as Tier-1 but in
   SIMPLE recovery — point-in-time recovery is impossible regardless of backup
   cadence. The fix (`SET RECOVERY FULL`) is meaningless until a fresh full
   establishes the chain.
4. **InventoryDB — HEALTHY.** Full + log inside the 15-minute RPO. The control
   that proves the report isn't just alarmist.

## Reset
```bash
$ docker compose exec -T sqlserver1 /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U sa -P "$SA_PASSWORD" -C -Q \
    "DROP DATABASE IF EXISTS [PaymentsDB]; DROP DATABASE IF EXISTS [ClaimsDB]; DROP DATABASE IF EXISTS [OrdersProdDB]; DROP DATABASE IF EXISTS [InventoryDB];"
```

## Result
`get_backup_status` already tags `NEVER_BACKED_UP` / `NO_LOG_BACKUPS`, but the
raw timestamps say nothing about **tier policy** — SIMPLE-on-Tier-1 reads as
"OK" from the tool alone. The skill is what converts these facts into a ranked,
minutes-of-exposure verdict. Reproduces exactly as written.

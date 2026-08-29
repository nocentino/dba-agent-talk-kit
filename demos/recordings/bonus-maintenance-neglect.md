# Recording — Bonus: Maintenance Neglect (SqlServer3)

Captured live on 2026-08-28 against a fresh `SqlServer3` (fleet profile). The
failed job and the fragmentation both reproduced; stale stats did not (expected
— see below).

## 1. Seed all three findings
```bash
$ cd demos/sql
$ ./seed-maintenance-neglect.sh
```
```
1/3 Creating ReportingDB with a churn table...
(20000 rows affected)
2/3 Fragmenting the index and going stale on statistics (no UPDATE STATISTICS after)...
3/3 Creating a SQL Agent job that fails (references a table that doesn't exist)...
Job 'Nightly_Report_Refresh' started successfully.
Maintenance-neglect scenario seeded on sqlserver3 (job history takes a few seconds to land).
```

## 2. get_job_status — the reliable, headline finding
```
get_job_status(instance_name: "SqlServer3")
```
```json
{
  "job_status": [
    {
      "job_name": "Nightly_Report_Refresh",
      "job_enabled": 1,
      "last_run_status": "Failed",
      "last_run_date": "2026-08-29",
      "last_run_time": "00:16:04",
      "last_run_message": "The job failed.  The Job was invoked by User sa.  The last step to run was step 1 (Refresh summary table).",
      "current_state": "FAILED"
    }
  ]
}
```
A scheduled job that has been silently failing — the most actionable finding.
(Confirms `MSSQL_AGENT_ENABLED=true` on sqlserver3 is working; `Y` would have
left Agent stopped and this empty.)

## 3. get_index_fragmentation — real, but watch the page-count floor
Default call (min_page_count 1000) returns nothing, because the churn table is
small (67 pages):
```
get_index_fragmentation(instance_name: "SqlServer3", database_name: "ReportingDB")
```
```
No fragmented indexes found in database 'ReportingDB' with fragmentation >= 10% and page_count >= 1000.
```
Lower the page-count floor for this small demo table and the finding is real:
```
get_index_fragmentation(instance_name: "SqlServer3", database_name: "ReportingDB", min_page_count: 0, min_fragmentation_pct: 0)
```
```json
{
  "index_fragmentation": [
    { "table_name": "DailyMetrics", "index_name": "IX_DailyMetrics_Region", "index_type": "NONCLUSTERED", "avg_fragmentation_in_percent": 37.31, "page_count": "67", "record_count": "21334", "recommendation": "REBUILD" },
    { "table_name": "DailyMetrics", "index_name": "PK__DailyMet__3214EC27...", "index_type": "CLUSTERED", "avg_fragmentation_in_percent": 6.84, "page_count": "117", "recommendation": "OK" }
  ]
}
```
`IX_DailyMetrics_Region` is **37.3% fragmented → REBUILD**. Note for the stage:
the default 1000-page threshold hides it because the demo table is tiny — pass a
lower `min_page_count`, or grow the table in the seed, if you want the default
call to surface it.

## 4. get_statistics_health — clean (expected)
```
get_statistics_health(instance_name: "SqlServer3", database_name: "ReportingDB")
```
```
No stale statistics found in database 'ReportingDB' with modification >= 10%.
```
`AUTO_UPDATE_STATISTICS` catches up before the tool runs. This is the honest,
documented result — the demo's two strong findings are the failed job and the
fragmentation. Re-run the churn block immediately before asking if you want a
stale-stats finding too.

## Reset
```bash
$ ./reset-maintenance-neglect.sh
```
```
Maintenance-neglect demo reset: ReportingDB and the job removed.
```

## Result
Failed job: reliable. Fragmentation: real (37.3%) but under the default
page-count floor on this small table — lower the threshold to show it. Stale
stats: auto-healed, as documented. The synthesis ("nobody's watching this box")
holds on the job + fragmentation alone.

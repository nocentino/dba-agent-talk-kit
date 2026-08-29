# Bonus — Maintenance Neglect: Stats, Fragmentation & a Failed Job (optional, ~5 min)

**Point being made:** three unrelated-looking symptoms — stale statistics, a
fragmented index, and a failed SQL Agent job — are often the same root cause:
nobody's watching this instance. The agent pulls all three from one instance
(`SqlServer3`) and connects them into a single "this box is neglected" story.

## Requires
The fleet profile (`docker compose --profile fleet up -d`) brought up and
initialized — see [compose/README.md](../compose/README.md#fleet-profile-bonus-demos).
`SqlServer3` registered in `.env` `INSTANCES`.

## Demo style
**Editor + terminal** for the seed script, **Copilot Chat agent mode** for the
investigation.

## Pre-demo state
- Fresh Copilot chat. Optionally attach `skills/observability.instructions.md`
  — this demo is the observability skill's procedure aimed at a genuinely
  neglected instance instead of a healthy one.

## Setup — seed all three findings (open in editor, run below)
`demos/sql/seed-maintenance-neglect.sh`:
```bash
cd demos/sql
./seed-maintenance-neglect.sh
```
Creates `ReportingDB` with a 20k-row table, fragments its index with an
8,000-row delete/insert churn, then creates and immediately runs a SQL Agent
job (`Nightly_Report_Refresh`) whose step references a table that doesn't
exist — a realistic "someone renamed a table and didn't update the job" failure.

## The prompt (paste into Copilot Chat)
> Check SqlServer3 for maintenance problems — statistics health, index
> fragmentation, and any failed SQL Agent jobs. What's been neglected here?

## Expected agent behavior
1. `get_index_fragmentation(instance_name: "SqlServer3", database_name: "ReportingDB")`
   → `IX_DailyMetrics_Region` fragmented ~35-40% (well above the 30% rebuild
   threshold) from the delete/insert churn — a real `REBUILD` recommendation.
2. `get_job_status(instance_name: "SqlServer3")` → `Nightly_Report_Refresh`
   shows `current_state: FAILED` with the actual T-SQL error message (referenced
   object `RegionSummary_DOES_NOT_EXIST` doesn't exist).
3. `get_statistics_health(instance_name: "SqlServer3", database_name: "ReportingDB")`
   → often comes back clean here — `AUTO_UPDATE_STATISTICS` is on by default and
   frequently catches up before the tool runs. That's a fine, honest result; the
   demo's two strong findings are the fragmentation and the failed job. If you
   want a real stale-stats finding too, run the seed script's churn block a
   second time immediately before asking (before autostat catches up).
4. Synthesizes: "this instance shows classic maintenance drift — an index badly
   needs a rebuild, and a scheduled job has been silently failing, probably
   emailing no one, until someone asked."

## Talking points
- "None of these three tools talk to each other. The agent is what connects
  a stats problem, a fragmentation problem, and a job failure into one
  'nobody's watching this box' narrative."
- "The failed job is the most actionable finding — it's been failing on a
  schedule, probably emailing no one, until someone asked."
- "This is exactly the kind of instance that falls through the cracks in a
  large estate — not broken enough to page anyone, just slowly rotting."

## Reset
```bash
cd demos/sql
./reset-maintenance-neglect.sh
```

## Failure modes / fallback
- **Job shows no failure history yet** → `sp_start_job` runs asynchronously;
  wait 5-10 seconds and re-run `get_job_status`, or check
  `SELECT * FROM msdb.dbo.sysjobhistory` directly to confirm it recorded.
- **SQL Agent not running** → confirm `MSSQL_AGENT_ENABLED=true` (must be
  `true`/`1`, not `Y` — that value is silently ignored by this image) was set on
  `sqlserver3` in the fleet overlay and the container was recreated (not just
  restarted) after adding it.
- **Fragmentation below threshold** → re-run the seed script; the delete/insert
  churn is randomized and fragmentation can vary run to run.

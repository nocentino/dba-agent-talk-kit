# Demo 6 — Skill: Observability (Objective 2, ~6 min)

**Point being made:** `get_wait_stats` alone tells you a number. The observability
skill runs the *same fixed sequence* every time — server, databases, waits, top
queries, blocking, missing indexes — and turns seven tool calls into one
consistent incident report with a single severity line at the top. Consistency
is the value, not any one tool.

## Demo style
**Editor + terminal** for the seed load, **Copilot Chat agent mode** for the report.

## Pre-demo state
- Fresh Copilot chat. Attach `skills/observability.instructions.md` as context.
- Stack up, `sql-dba` tools visible.

## Setup — seed a little real load (open in editor, run below)
`demos/sql/seed-observability-load.sh` bulks `dbo.Products` up to ~20,000 rows
(skewed so `Category = 'Electronics'` is a selective ~3% slice — a 25/25/25/25
split is common enough that a scan is legitimately as cheap as a seek, and the
optimizer correctly won't recommend an index for that), then runs ~30 iterations
of a filtered query plus a three-table join. Takes a few seconds; just enough to
populate the plan cache and give `get_missing_indexes` a real, high-impact
recommendation to make.
```bash
cd demos/sql
./seed-observability-load.sh
```

## The prompt (paste into Copilot Chat)
> Pull a full health snapshot of SqlServer1 — server info, databases, wait
> stats, top queries by CPU, any blocking, and missing indexes. Write it up as
> an incident report.

## Expected agent behavior (the skill's fixed order, narrate each step)
1. `get_server_info` → version, uptime, CPU/RAM, and the four configuration
   baselines the skill checks every time (MAXDOP, cost threshold for
   parallelism, max server memory, optimize for ad hoc workloads). This
   container ships with defaults that trip at least two of these — that's a
   real, not staged, finding.
2. `get_database_info` → `ProductsDB` recovery model, size, `log_reuse_wait_desc`.
3. `get_wait_stats` → top waits with benign waits already filtered.
4. `get_top_queries(order_by: "cpu", top_n: 5)` → the seeded `Category` filter
   query near the top, with `avg_logical_reads` high enough to be notable.
5. `get_blocking_chains` → "No blocking detected" is a fine, expected result
   here — the skill treats this as a normal finding, not a failure to find
   something.
6. `get_missing_indexes` → recommends a composite index on
   `dbo.Products(Category, Discontinued) INCLUDE (UnitPrice)` at ~91% estimated
   impact, with the ready-to-run `CREATE INDEX` DDL, plus the skill's mandatory
   caveat: test in non-prod, check `get_index_usage_stats` for overlap first.
7. Severity stated as one line at the top of the report — max of any single
   finding, per the skill's report rules.
8. Report closes with **What I did NOT check** — deadlock history, Query Store
   regressions — so scope is auditable, not implied to be exhaustive.

## Talking points while it runs
- "Every one of these seven calls happens in the same order, every time,
  whether the server is healthy or on fire. That's the whole point of a skill
  — the SOP doesn't change based on the model's mood."
- "Configuration drift is reported even when nothing's actively wrong. Drift is
  the finding — symptoms are optional. That line is in the skill verbatim."
- "Notice the missing-index DDL comes with a warning to check for overlap
  first. The skill doesn't trust the optimizer's suggestion blindly, and
  neither should you."
- "And the last section — what it did NOT check — is the boundary of what you
  can trust this report to mean. No skill claims completeness it can't back up."

## Reset
```bash
cd demos/sql
./reset-observability-load.sh
```
Removes the ~20k synthetic filler rows so `ProductsDB` doesn't stay bloated
across demos. The plan cache itself needs no cleanup for a re-run, but if you
want one: `DBCC FREEPROCCACHE;` on `SqlServer1` (narrate that this is a
non-production-safe command you would not run against a real environment on a
whim — plan cache eviction has a cost).

## Failure modes / fallback
- **No missing indexes recommended** → confirm the seed script actually ran
  (the ~20k filler rows are required — a 10-row `Products` table never
  triggers a recommendation, a scan is legitimately cheap enough already);
  re-run `seed-observability-load.sh` if unsure.
- **Report skips a step** → follow-up: "did you check for blocking and missing
  indexes too?" — the skill's procedure is a should-follow SOP, not a hard gate;
  narrate that as an honest limitation, same as the backup-posture demo's
  fallback note.
- **Config baselines all show healthy** → unlikely on a fresh container, but if
  so, that's still a valid, useful report — say so, don't manufacture concern.

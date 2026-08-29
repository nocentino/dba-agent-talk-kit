# Bonus — Deadlocks & TempDB Contention (optional, ~5 min)

**Point being made:** a deadlock graph is unreadable to most people who aren't
staring at XML for a living. The agent reads the same `system_health` ring
buffer and tells you, in one sentence, who won, who lost, and why. TempDB
pressure is the secondary check in the same prompt — a real, live look at
tempdb whether or not it happens to catch something interesting at that moment.

## Requires
The fleet profile (`docker compose --profile fleet up -d`) brought up and
initialized — see [compose/README.md](../compose/README.md#fleet-profile-bonus-demos).
`SqlServer4` registered in `.env` `INSTANCES`.

## Demo style
**Editor + terminal** for the seed script, **Copilot Chat agent mode** for the
investigation.

## Pre-demo state
- Fresh Copilot chat.

## Setup — trigger a real deadlock + tempdb pressure (open in editor, run below)
`demos/sql/seed-deadlocks-tempdb.sh`:
```bash
cd demos/sql
./seed-deadlocks-tempdb.sh
```
Fires two sessions against `DeadlockDemoDB` updating `TableA` and `TableB` in
opposite order — a textbook deadlock. SQL Server picks a victim and rolls it
back automatically; the graph lands in the `system_health` Extended Events ring
buffer — reliably, every run. The script also kicks off one large unindexed
sort in the background as a tempdb-pressure aside; whether `get_tempdb_usage`
catches it mid-flight depends on timing and how fast this container's CPU
churns through it, so treat that half as a bonus, not the headline.

## The prompt (paste into Copilot Chat)
> Were there any deadlocks recently on SqlServer4? Tell me which session won,
> which lost, and what they were doing. Also check tempdb usage while you're in there.

## Expected agent behavior
1. `get_deadlock_history(instance_name: "SqlServer4")` → parses the ring
   buffer, reports the victim and survivor sessions, the statements each was
   running (`UPDATE dbo.TableA...` / `UPDATE dbo.TableB...`), and the lock
   resources involved. This one is reliable every run — lead with it.
2. `get_tempdb_usage(instance_name: "SqlServer4")` → file-space numbers are
   always real; the top-consuming-session breakdown may or may not catch the
   background sort mid-flight depending on timing in this small container.
   Either outcome is a fine, honest result to narrate.
3. Synthesizes: identifies the classic opposite-lock-order pattern and — if
   this were a real app — would recommend a consistent access order across
   both tables as the actual fix (an index or query tweak doesn't fix a
   deadlock caused by lock ordering).

## Talking points
- "Nobody reads a deadlock graph XML by hand anymore. That's the whole value
  of this tool — it's not new data, it's the same ring buffer every DBA has
  always had, just translated."
- "The fix for a deadlock is almost never a query tuning fix — it's an
  application access-order fix. Watch whether the agent gets that right
  instead of suggesting an index."
- "Whatever tempdb shows right now is real, live data — that's the point,
  not whether it happens to catch a spike on this exact call."

## Reset
```bash
cd demos/sql
./reset-deadlocks-tempdb.sh
```
No tempdb cleanup needed — it's transient and clears when the sort's session ends.

## Failure modes / fallback
- **No deadlock in the ring buffer** → deadlocks require the `system_health`
  XE session to be running (on by default) and enough of a delay for both
  transactions to actually collide; the 3-second `WAITFOR` should be enough,
  but a heavily loaded host might need a longer delay — bump the `WAITFOR` if
  it doesn't reproduce first try.
- **tempdb usage shows nothing** → the sort finishes fast on a small dataset;
  re-run just the tempdb-pressure block from the seed script, or increase the
  cross join further for a bigger, longer-running sort.

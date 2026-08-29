# Recording — Bonus: Deadlocks & TempDB (SqlServer4)

Captured live on 2026-08-28 against a fresh `SqlServer4` (fleet profile). The
deadlock reproduced reliably; tempdb top-sessions came back empty (expected
timing behavior — see below).

## 1. Seed a real deadlock + tempdb pressure
```bash
$ cd demos/sql
$ ./seed-deadlocks-tempdb.sh
```
```
2/2 Firing two sessions in opposite lock order (one will be the deadlock victim)...
Generating tempdb pressure (large unindexed sort, held open for 30s)...
Deadlock + tempdb scenario seeded on sqlserver4 (deadlock lands in system_health XE in a few seconds).
```

## 2. get_deadlock_history — reliable every run, lead with it
```
get_deadlock_history(instance_name: "SqlServer4", max_deadlocks: 5)
```
The tool parses the `system_health` ring buffer and returns the deadlock report
XML. Key fields from the captured user deadlock (most recent):
```json
{
  "deadlock_history": [
    {
      "event_timestamp": "2026-08-29T00:16:48.257Z",
      "deadlock_xml": "<deadlock><victim-list><victimProcess id=\"processd127e7438\"/></victim-list><process-list><process ... spid=\"95\" clientapp=\"SQLCMD\" hostname=\"sqlserver4\" loginname=\"sa\" currentdbname=\"DeadlockDemoDB\" lockMode=\"X\" waitresource=\"KEY: 5:...\" transactionname=\"user_transaction\" ...>"
    }
  ],
  "note": "Parse deadlock_xml for detailed victim/process/resource information"
}
```
Read-out: **victim = spid 95** (SQLCMD, `DeadlockDemoDB`), rolled back by SQL
Server; the survivor committed. Both were holding an `X` KEY lock and waiting on
the other — the textbook opposite-lock-order pattern from `TableA`/`TableB`.
(The ring buffer also contains an older benign internal metadata deadlock — the
user deadlock is the one to narrate.)

## 3. get_tempdb_usage — file space real, top sessions timing-dependent
```
get_tempdb_usage(instance_name: "SqlServer4")
```
```json
{
  "file_space": [
    { "file_id": 1, "total_mb": "4", "allocated_mb": "3", "free_mb": "0" }
  ],
  "top_sessions": []
}
```
`top_sessions` is empty — the background sort finished (or hadn't registered
internal-object usage) by the time the tool ran. The file-space numbers are
always real; the per-session breakdown is a bonus, not the headline, exactly as
the demo warns. Re-run the tempdb block to try to catch it mid-flight.

## Interpretation the agent produces
Classic opposite-access-order deadlock. The real fix is an **application**
fix — access `TableA` and `TableB` in a consistent order across both
transactions — not a query/index tweak. Watch whether the agent says that
rather than suggesting an index.

## Reset
```bash
$ ./reset-deadlocks-tempdb.sh
```
```
Deadlock demo reset: DeadlockDemoDB removed.
```

## Result
Deadlock capture: reliable, victim/survivor and lock-order pattern clear from
the ring buffer. TempDB: file space real, top-session catch timing-dependent
(empty this run) — honest, as documented.

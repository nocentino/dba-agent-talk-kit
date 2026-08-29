# Bonus — Application-Consistent Snapshot with Freeze Safety
(optional, not in the 60-min core — requires Pure Storage Fusion MCP + a separate
demo environment outside sql-mcp-server; ~8 min)

**Point being made:** this is the guardrail story taken further than the core
session has time for. In Demo 2 the agent could diagnose but not execute —
SELECT-only access, enforced in code. Here,
it drives a two-MCP operation across SQL Server and Pure Storage FlashArray. The
SQL Server MCP stays read-only throughout; the first mutation (the storage snapshot
`POST`) triggers the supervised-action gate live on stage. And the agent handles
failure correctly: the freeze is released *before* the error is reported. A script
that dies between those two steps leaves the database suspended until someone
notices. That's the difference between a tool and a policy-aware agent.

## Infrastructure note

This demo uses the [mcp-server-demos](https://github.com/nocentino/mcp-server-demos)
environment, not the Docker Compose stack from Demos 1–4. Prerequisites:

- Pure Storage Fusion MCP server configured and running with API tokens in
  `~/Library/Application Support/mcp-servers/fusion-mcp/auth-config.json`.
- `database-sre-agent.md` from the mcp-server-demos repo present in the workspace.
- `CLAUDE.md` from the same repo auto-loads the policy at session start; or add
  `database-sre-agent.md` manually via Add Context → Files.
- `aen-sql-25-a` reachable; `TPCC-4T` database exists; all 9 of its volumes are
  in the `aen-sql-25-a-pg` Protection Group. Confirm with:
  ```bash
  sqlcmd -S aen-sql-25-a -Q "SELECT name FROM sys.databases WHERE name='TPCC-4T';"
  ```

## Pre-demo state

- Fresh Copilot chat in **Agent mode**. Both MCP servers visible in the tools list:
  `sql-server-db` and `fusion-mcp`.
- Confirm no suspended snapshot backup is active on `TPCC-4T` **before** going on
  stage:
  ```sql
  SELECT database_id, DB_NAME(database_id) AS db, is_suspended_for_snapshot_backup
  FROM   sys.databases
  WHERE  DB_NAME(database_id) = 'TPCC-4T';
  ```
- Paste the manual release command into a scratch buffer now and leave it open:
  ```sql
  ALTER DATABASE [TPCC-4T] SET SUSPEND_FOR_SNAPSHOT_BACKUP = OFF;
  ```
- Verify `.claude/settings.json` has the four write tools (`presets_create`,
  `presets_update`, `workloads_deploy`, and the Fusion `POST` path) in `ask` mode —
  the permission prompt is the demo moment, do not approve it away in advance.

## The prompt (paste into Copilot Chat)

> You're a Database SRE agent. Your skills and workflows are defined in
> @database-sre-agent.md.
>
> Take an application-consistent snapshot of the TPCC-4T database on aen-sql-25-a
> using the single database snapshot flow. Use sqlcmd for the T-SQL steps.
> Replicate the snapshot immediately, report the actual freeze duration, and confirm
> the replicated copy landed on the DR array.

Note what the prompt does **not** say. It does not mention the 30-second freeze cap,
the guarded block, or releasing the freeze on failure. Those are policy, not
instruction — they come from the skills file. If you have to tell the agent how to
be safe in the prompt, the policy file isn't doing its job.

## Expected agent behavior (narrate as it happens)

1. **Volume resolution** — calls `fusion-mcp` `volumes_list` with `contains`
   filtering on `aen-sql-25-a` to find volumes tagged `databases=TPCC-4T`.
2. **Crash-consistency gate** — confirms every resolved volume is in
   `aen-sql-25-a-pg`. If any volume is outside that PG, the agent stops here.
   A script would have snapshotted first and found the problem at restore time.
3. **Pre-flight check** — uses `sql-server-db` MCP to query
   `is_suspended_for_snapshot_backup` on `TPCC-4T`. Read-only MCP, as always.
4. **Freeze** — runs via `sqlcmd`:
   ```sql
   ALTER DATABASE [TPCC-4T] SET SUSPEND_FOR_SNAPSHOT_BACKUP = ON;
   ```
5. **Snapshot** *(guarded block starts)* — `POST /protection-group-snapshots` with
   `source_names=aen-sql-25-a-pg&replicate_now=true` via Fusion MCP.
   **This is where the permission gate fires.** All prior work ran unprompted;
   the first state-changing call stops and asks. Approve it here.
6. **Freeze release** — runs via `sqlcmd`:
   ```sql
   BACKUP DATABASE [TPCC-4T] TO DISK=N'/var/opt/mssql/data/TPCC-4T_snap.bak'
     WITH METADATA_ONLY;
   ```
   The `METADATA_ONLY` backup releases the freeze — this is what closes the
   guarded block. On any failure in step 5, the agent must run
   `SET SUSPEND_FOR_SNAPSHOT_BACKUP = OFF` here *before* reporting the error.
7. **Replication confirmation** — queries Fusion MCP to confirm the snapshot
   landed on the DR array.
8. **Report** — snapshot name, timestamp, measured freeze duration, replication
   status.

## Talking points while it runs

- When the tool chain starts: "Two MCP servers, one agent. SQL Server MCP handles
  the read side and the T-SQL path; Fusion handles the storage side. Neither server
  knows about the other — the agent is the orchestration layer."
- When the crash-consistency gate runs: "The agent checked single-PG membership
  before touching the database. That gate is in the skills file, not the prompt.
  If you pull it out of the prompt, it's gone. If it's in the policy file, it's
  every run."
- **On the permission gate** (the key beat): "Four demos of read-only work, no
  prompts. The first state-changing call stops and asks. This is the
  supervised-action model actually working — not asserted on a slide, not promised
  in a pitch deck."
- On the freeze duration in the report: "That number is the I/O impact window for
  this snapshot. Storage teams are rarely asked for it today. Auditors increasingly
  are. Encode the requirement in the policy file and it shows up in every report
  automatically."
- **Closing line** (say this when the report lands):
  > "If the snapshot call had failed, the agent releases the freeze *before* it
  > tells me it failed. A script that dies between those two steps leaves the
  > database suspended until someone notices. That's the difference."

## Optional — the failure beat

Only if you have rehearsed it and have time. Interrupt the agent between the suspend
and the snapshot (`Esc`), or temporarily change the Protection Group name in the
prompt so the `POST` 404s. The agent should run the freeze release (`SET ... OFF`)
first, then report the failure. **Verify the database is writable afterwards** before
moving on.

This is the most persuasive 30 seconds in the whole demo for a regulated audience —
and the most likely to go wrong live. Recording it beforehand is a legitimate choice;
say plainly that it is a recording if you show one.

## Reset

```sql
-- Verify freeze is not held after the demo
SELECT database_id, DB_NAME(database_id) AS db, is_suspended_for_snapshot_backup
FROM   sys.databases
WHERE  DB_NAME(database_id) = 'TPCC-4T';

-- If held (should not be, but just in case)
ALTER DATABASE [TPCC-4T] SET SUSPEND_FOR_SNAPSHOT_BACKUP = OFF;
```

Snapshots on the array can be cleaned up via Fusion MCP or the FlashArray UI —
they have no effect on subsequent demo runs.

## Failure modes / fallback

- **Freeze left held** → run the manual release from the scratch buffer immediately.
  Verify with the `is_suspended_for_snapshot_backup` SELECT before continuing.
  Never move past this — a held freeze suspends all writes to `TPCC-4T`.
- **Permission gate not firing** → means the write tools were pre-approved.
  Check `.claude/settings.json` and move them to `ask` before retrying. The gate
  IS the demo moment.
- **Agent infers array model from name** → use the correction prompt:
  *"Don't assume the model based on the array's current name. Read it directly
  from the array."*
- **Replication not confirmed** → check the DR array replication link in Fusion MCP.
  If the link is degraded, narrate it as a compliance finding — it ties directly
  back to the Compliance & Audit workflow in Demo 5's security-audit story, or the
  Demo 4 backup-posture story if it's a backup replication concern.
- **Volume not found in PG** → confirm `aen-sql-25-a-pg` membership with Fusion MCP
  `volumes_list` before retrying. If volumes span PGs the agent must refuse — do
  not override.
- Fallback recording: `demo5-snapshot.mp4`.

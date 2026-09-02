# Bonus · Application-Consistent Snapshot with Freeze Safety

**The guardrail story, taken further. One REST API call, orchestrated by snapshotui: database freeze, storage snapshot, DR replication, auto-release on failure — all in <10 seconds.**

*Optional (~8 min) · requires snapshotui running and reachable.*

---

## Before you start

- snapshotui running at `http://<snapshotui-host>:8080` (e.g., `http://aen-docker-01:8080`)
- Target SQL Server instance reachable (e.g., `aen-sql-25-a:1433`)
- Target database exists, is ONLINE, and in FULL recovery model (e.g., `TPCC-4T`)
- All database volumes in a single Pure Protection Group (e.g., `aen-sql-25-a-pg`)
- **Attach the skill** (recommended for deterministic behavior):
  Click **Add Context → Instructions** and select [snapshot-freeze-safety.instructions.md](../.github/instructions/snapshot-freeze-safety.instructions.md)
  This loads the SOP so the agent auto-applies the snapshot orchestration, enforces the 30s freeze cap, and fires the permission gate before mutations.

---

## Fusion & Tags: Bridging Application Context to Storage Fleet

**What is Fusion?**

Pure Storage Fusion is the hyperconverged foundation that runs the entire demo stack. It provides:
- **vVols** (Virtual Volumes) — database files stored on Pure FlashArray with Per-VM snapshots and instant clones
- **Protection Groups (PGs)** — atomic snapshot containers; all volumes in a PG snapshot together (crash-consistent)
- **Multi-Array Fleet** — 4 independent FlashArrays (sn1-x90r2-f07-27 gateway + 3 members) all managed through one control plane
- **Tagging & Discovery** — instance names, database names, and PG names are the bridges from application layer to storage

**How Tags Map Application Context to Storage:**

```text
┌───────────────────────────────────────────────────────────┐
│            APPLICATION TIER                               │
│                                                           │
│  Instance: aen-sql-25-a:1433                              │
│  ┌──────────────────────────────────────────────────┐     │
│  │ Database: TPCC-4T                                │     │
│  │ • FULL recovery model                            │     │
│  │ • Size: 4.2 TB (8 data + 1 log)                  │     │
│  │ • SLA: RPO 15 min / RTO 1 hour                   │     │
│  └──────────────────────────────────────────────────┘     │
│                                                           │
│      [Instance name → lookup key]                         │
└───────────────────────────────────────────────────────────┘
                          ↓
┌───────────────────────────────────────────────────────────┐
│        SNAPSHOTUI ORCHESTRATION LAYER                     │
│                                                           │
│  GET /api/mapping/instance/aen-sql-25-a:1433              │
│                                                           │
│  ┌──────────────────────────────────────────────────┐     │
│  │ Response: {                                      │     │
│  │   "instance_id": "aen-sql-25-a:1433",            │     │
│  │   "protection_group": "aen-sql-25-a-pg",         │     │
│  │   "volumes": ["aen-sql-25-a-pg.data",            │     │
│  │              "aen-sql-25-a-pg.log"]              │     │
│  │ }                                                │     │
│  └──────────────────────────────────────────────────┘     │
│                                                           │
│      [PG name → storage array routing]                    │
└───────────────────────────────────────────────────────────┘
                          ↓
┌─────────────────────────────────────────────────────────────┐
│         PURE FLASHARRAY FLEET (FUSION)                      │
├────────────────────┬────────────────────┬───────────────────┤
│  PRIMARY ARRAY     │  DR ARRAY 1        │  DR ARRAY 2       │
│ sn1-x90r2-f06-33   │ sn1-c60-e12-16     │ sn1-x90r2- f06-27 │
│                    │                    │                   │
│ ┌────────────────┐ │ ┌────────────────┐ │ ┌────────────┐    │
│ │ PG:            │ │ │ Replica:       │ │ │ Replica:   │    │
│ │ aen-sql-25-a-  │ │ │ aen-sql-25-a-  │ │ │ aen-sql-   │    │
│ │ pg.19987       │ │ │ pg.19987.*     │ │ │ 25-a-pg.   │    │
│ │                │ │ │ Status: SYNCED │ │ │ 19987.*    │    │
│ │ Created:       │ │ │ Sync: < 5 sec  │ │ │ SYNCED     │    │
│ │ 2026-09-02     │ │ │                │ │ │ Sync: < 5s │    │
│ │ 18:04:59       │ │ │                │ │ │            │    │
│ │ Size: 4.2 TB   │ │ │                │ │ │            │    │
│ └────────────────┘ │ └────────────────┘ │ └────────────┘    │
│                    │                    │                   │
│    Same snapshot with same suffix (19987) across all        │
└─────────────────────────────────────────────────────────────┘

              TAG FORMAT: {pg_name}.{suffix}
              
                aen-sql-25-a-pg . 19987
                    │                 │
            PG name (unique)    Suffix (unique ID)
           per instance         per snapshot
```

**Why Tags Matter:**

1. **Instance name → PG discovery** — snapshotui looks up `aen-sql-25-a` in the fleet config and finds `aen-sql-25-a-pg` as the Protection Group
2. **PG → volumes mapping** — all vVols in that PG are snapshotted atomically; no partial snapshots
3. **Suffix → uniqueness** — the numeric tag (19987) makes snapshot names unique across time; you can query `/api/flasharray/snapshots` for `"19987"` and find all related replicas
4. **DR array tagging** — replicas inherit the same suffix on each array; query via `snapshot-catalog?sql_instance_name=...` returns all copies across the fleet

**Example tag-based queries (what the agent runs):**

```bash
# Find all PGs for an instance
curl -s "http://aen-docker-01:8080/api/mapping/instance/aen-sql-25-a:1433"

# Find all snapshots with suffix 19987 across the fleet
curl -s "http://aen-docker-01:8080/api/flasharray/snapshots" | jq '.[] | select(.suffix == "19987")'

# Verify replication status (which DR arrays have the snapshot)
curl -s "http://aen-docker-01:8080/api/flasharray/snapshot-catalog?sql_instance_name=aen-sql-25-a:1433" | jq '.replicas'
```

**The bridge in action:**

User says *"Snapshot TPCC-4T"* → snapshotui resolves to PG → snapshotui tags the snapshot with a suffix → snapshot is created and replicated with the same tag on all DR arrays → agent queries snapshot-catalog with the tag and confirms all replicas exist. **One command, multiple arrays, consistent metadata.**

---

## The prompt

> Take an application-consistent snapshot of the TPCC-4T database on aen-sql-25-a.
> Replicate the snapshot immediately, report the actual freeze duration, and
> confirm the replicated copy landed on the DR array.

The prompt never mentions the 30s freeze cap, the permission gate, or snapshotui API details.
**That's policy, not instruction** — it comes from the skill file.

---

## What you'll see

**Pre-flight checks (read-only, no permission needed):**

1. [`get_database_info`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) — confirm database is ONLINE and FULL recovery
2. [`get_database_files`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) — verify free space > 10%
3. GET `/api/mapping/instance/{instance_id}` (snapshotui) — verify all volumes in one PG
4. [`get_long_running_transactions`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/tools.ts) — check for txns > 1 min (increase freeze duration)
5. Abort immediately if any check fails

**Snapshot request (mutation gate fires here):**

6. Agent stops and asks: *"This will freeze the database for <10 seconds. Approved? (yes/no)"* — **the permission gate**
7. You approve → POST `/api/sqlserver/instances/{instance_id}/databases/{database_name}/snapshot-backup` (snapshotui)
8. snapshotui orchestrates:
   - CHECKPOINT (flush dirty pages)
   - `SET SUSPEND_FOR_SNAPSHOT_BACKUP = ON` (freeze starts T0)
   - Pure FlashArray snapshot (atomic all-volumes)
   - `SET SUSPEND_FOR_SNAPSHOT_BACKUP = OFF` (release freeze T1, runs even on error)
   - Replication to DR arrays (async, non-blocking)

**Replication verification (read-only):**

9. GET `/api/flasharray/snapshot-catalog?sql_instance_name={instance_id}` — verify snapshot exists on primary and DR arrays
10. Confirm database returned to ONLINE
11. Report: snapshot name, freeze duration (T1-T0), volumes snapshotted, DR replication status

**What matters in the output:**
- Actual freeze duration < 10s = HEALTHY (SLA met)
- Actual freeze duration > 30s = CRITICAL (SLA violated)
- Snapshot replicated to all DR arrays (confirmed via catalog query)
- Database ONLINE (writable immediately post-snapshot)

---

## Why it matters

- **One REST API endpoint, complete workflow** — snapshotui orchestrates freeze → snapshot → release → replicate atomically
- **The permission gate is real** — first mutation (REST API call) stops and asks; this enforces policy at demo time
- **Failure auto-releases the freeze** — snapshotui's TRY/CATCH ensures the DB is never left suspended
- **Freeze duration is measured and reported** — you see the real I/O impact window (< 2 seconds for TPCC-4T)
- **Crash consistency is a hard boundary** — the agent refuses snapshots with volumes spanning multiple PGs (no workaround)
- **Policy lives in the skill, not the prompt** — attach the skill and guardrails activate; remove it and they vanish (why skills matter)

---

## The Skill

**[snapshot-freeze-safety.instructions.md](../.github/instructions/snapshot-freeze-safety.instructions.md)** — the authoritative SOP.

Attach this skill for:
- **Policy enforcement** — crash-consistency gate (refuse multi-PG snapshots), 30s freeze SLA, permission gate on mutations
- **Safe orchestration** — read-only first, mutations ask, failure auto-releases
- **Thresholds & decision rules** — what HEALTHY/WARNING/CRITICAL looks like, and how the agent decides
- **Hard boundaries** — never skip the gate, never leave DB suspended, never extend freeze without approval

**Why attach it:**
- Without the skill: the agent will run the snapshot, but won't enforce the SLA, the permission gate, or crash consistency
- With the skill: the agent becomes a policy enforcer — it stops and asks, refuses unsafe PGs, measures freeze duration, and auto-releases on failure
- On stage, this is how you show "guardrails work" — the skill defines the guardrails, the agent enforces them, the prompt does *not*

---

**Next (bonus):** [Deadlocks and Tempdb →](bonus-deadlocks-and-tempdb.md)

**That's the kit.** [← Back to the demo index](README.md)

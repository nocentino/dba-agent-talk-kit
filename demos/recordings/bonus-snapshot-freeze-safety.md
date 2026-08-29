# Recording — Bonus: Snapshot Freeze-Safety (NOT runnable here)

⛔ **Not captured — requires an external environment.** This demo drives a Pure
Storage array snapshot through the **Fusion MCP** server plus a separate demo
environment that is not part of this self-contained kit. There is no fallback
transcript to record from this repo.

If you intend to run it live, stage it entirely outside this compose stack:
- A reachable Pure Storage Fusion MCP endpoint wired into `mcp.json`.
- The freeze-safety guarded block from
  [bonus-snapshot-freeze-safety.md](../bonus-snapshot-freeze-safety.md).

Everything else in this recordings folder was captured against the
self-contained `compose/docker-compose.yml` stack; this one is the single
exception.

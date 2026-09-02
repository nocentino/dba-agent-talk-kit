# Demo Index: Build Your Own DBA Agent (60-min session)

No deck. This folder *is* the session: markdown runbooks, ASCII diagrams, live
terminal, and live Copilot Chat. I run every demo straight from these files. See the main
[README.md](../README.md) for the full conference abstract.

---

## Quick Start: Before Demo 0

```bash
./compose/startup.sh
```

Run from the repo root. This starts the full stack (all SQL Server instances, MCP servers, and initializes the AG). Takes 2-3 minutes. Walk away and come back when it says **✅ Stack Ready!**

Once it's up, proceed to Demo 0 below.

### When you're done

```bash
./compose/teardown.sh
```

Removes all containers and volumes. To run the demos again, just `./compose/startup.sh` once more.

---

## Demo style legend
Each file states which mode applies per section:
- **Editor + terminal**: open the referenced script/file in the editor,
  highlight the relevant lines, run it in the integrated terminal below.
- **Copilot Chat, agent mode**: paste the prompt into a fresh chat with the
  `sql-dba` (and where noted, `products-db`) tools enabled.

## Learning objectives → demos

| # | Learning objective (from the abstract) | Demos |
|---|---|---|
| 1 | Explain what AI agents and MCP are and how they apply to database operations | [00](00-intro-and-architecture.md), [01](01-install-and-configure.md), [02](02-blocking-and-dab.md) |
| 2 | Build DBA agent skills for availability, recovery, security/auditing, and observability, and how to structure a skill file | [02b](02b-anatomy-of-a-skill-file.md), [03](03-skill-availability-ag-health.md), [04](04-skill-backup-recovery.md), [05](05-skill-security-audit.md), [06](06-skill-observability.md) |
| 3 | Design trust and control guardrails that keep humans in the decision loop | Woven through every demo; synthesized in [07](07-trust-and-guardrails-wrapup.md), which closes with a *Start Monday* recap |

## The 60-minute run-of-show

| # | File | What it proves | Budget |
|---|---|---|---|
| 0 | [00-intro-and-architecture.md](00-intro-and-architecture.md) | What an agent + MCP are, ASCII architecture | 3 min |
| 1 | [01-install-and-configure.md](01-install-and-configure.md) | Zero access → tools appear the moment `mcp.json` names the server | 5 min |
| 2 | [02-blocking-and-dab.md](02-blocking-and-dab.md) | Tools without a skill: the agent chains DMVs itself; DAB as the other MCP pattern | 5 min |
| 2b | [02b-anatomy-of-a-skill-file.md](02b-anatomy-of-a-skill-file.md) | How a skill file is structured: persona → thresholds → hard boundaries | 3 min |
| 3 | [03-skill-availability-ag-health.md](03-skill-availability-ag-health.md) | Skill: availability, AG health, by the book | 5 min |
| 4 | [04-skill-backup-recovery.md](04-skill-backup-recovery.md) | Skill: backup & recovery, live with/without-skill A/B | 5 min |
| 5 | [05-skill-security-audit.md](05-skill-security-audit.md) | Skill: security & auditing, detect, never remediate | 6 min |
| 6 | [06-skill-observability.md](06-skill-observability.md) | Skill: observability, the same SOP, every time | 5 min |
| 7 | [07-trust-and-guardrails-wrapup.md](07-trust-and-guardrails-wrapup.md) | Synthesis: six-layer guardrail stack + *Start Monday* close | 5 min |
| | **Core total** | | **~42 min** |
| | Buffer / Q&A / transitions | | **~18 min** |

Bonus demos (not in the 60-minute core; use only if time allows or for a longer version):
- [bonus-fleet-wide-waits.md](bonus-fleet-wide-waits.md): same tools, fanned out across a whole fleet (~4 min). **Fleet profile auto-started by `startup.sh`.**
- [bonus-deadlocks-and-tempdb.md](bonus-deadlocks-and-tempdb.md): a real deadlock read from the XE ring buffer, plus tempdb pressure (~5 min). **Requires SqlServer4**, auto-started by `startup.sh`.
- [bonus-snapshot-freeze-safety.md](bonus-snapshot-freeze-safety.md): agent-driven storage snapshot with a freeze-safety guarded block (~8 min). **Requires Pure Storage Fusion MCP + a separate demo environment outside sql-mcp-server**, not runnable with this repo alone.

## Seed / reset scripts
All in [sql/](sql/), run from `demos/sql/` (they `source ../../.env`):

| Script | Used by |
|---|---|
| `seed-blocking.sh` / `clear-blocking.sh` | Demo 2 |
| `seed-fleet-load.sh` | Bonus: fleet-wide waits |
| `seed-ag-lag.sh` / `resume-ag.sh` | Demo 3 |
| `seed-backup-gaps.sh` | Demo 4 |
| `seed-security-issues.sh` | Demo 5 |
| `seed-observability-load.sh` | Demo 6 |
| `seed-deadlocks-tempdb.sh` / `reset-deadlocks-tempdb.sh` | Bonus: deadlocks & tempdb (SqlServer4) |

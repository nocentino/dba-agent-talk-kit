# Demo Index — Build Your Own DBA Agent (60-min session)

No deck. This folder *is* the session: markdown runbooks, ASCII diagrams, live
terminal, and live Copilot Chat. See the main [README.md](../README.md) for the
full conference abstract.

## Demo style legend
Each file states which mode applies per section:
- **Editor + terminal** — open the referenced script/file in the editor,
  highlight the relevant lines, run it in the integrated terminal below.
- **Copilot Chat, agent mode** — paste the prompt into a fresh chat with the
  `sql-dba` (and where noted, `products-db`) tools enabled.

## Learning objectives → demos

| # | Learning objective (from the abstract) | Demos |
|---|---|---|
| 1 | Explain what AI agents and MCP are and how they apply to database operations | [00](00-intro-and-architecture.md), [01](01-install-and-configure.md), [02](02-blocking-and-dab.md) |
| 2 | Build DBA agent skills for availability, recovery, security/auditing, and observability | [03](03-skill-availability-ag-health.md), [04](04-skill-backup-recovery.md), [05](05-skill-security-audit.md), [06](06-skill-observability.md) |
| 3 | Design trust and control guardrails that keep humans in the decision loop | Woven through every demo's talking points; synthesized in [07](07-trust-and-guardrails-wrapup.md) |

## The 60-minute run-of-show

| # | File | What it proves | Budget |
|---|---|---|---|
| 0 | [00-intro-and-architecture.md](00-intro-and-architecture.md) | What an agent + MCP are, ASCII architecture | 3 min |
| 1 | [01-install-and-configure.md](01-install-and-configure.md) | Zero access → tools appear the moment `mcp.json` names the server | 5 min |
| 2 | [02-blocking-and-dab.md](02-blocking-and-dab.md) | Tools without a skill: the agent chains DMVs itself; DAB as the other MCP pattern | 6 min |
| 3 | [03-skill-availability-ag-health.md](03-skill-availability-ag-health.md) | Skill: availability — AG health, by the book | 5 min |
| 4 | [04-skill-backup-recovery.md](04-skill-backup-recovery.md) | Skill: backup & recovery — timestamps vs. policy | 5 min |
| 5 | [05-skill-security-audit.md](05-skill-security-audit.md) | Skill: security & auditing — detect, never remediate | 6 min |
| 6 | [06-skill-observability.md](06-skill-observability.md) | Skill: observability — the same SOP, every time | 6 min |
| 7 | [07-trust-and-guardrails-wrapup.md](07-trust-and-guardrails-wrapup.md) | Synthesis: the six-layer guardrail stack | 5 min |
| | **Core total** | | **~41 min** |
| | Buffer / Q&A / transitions | | **~19 min** |

Bonus demos (not in the 60-minute core — use only if time allows or for a longer version):
- [bonus-fleet-wide-waits.md](bonus-fleet-wide-waits.md) — same tools, fanned out across a whole fleet (~4 min)
- [bonus-maintenance-neglect.md](bonus-maintenance-neglect.md) — stale statistics, index fragmentation, and a failed SQL Agent job, connected into one "nobody's watching this box" story (~5 min). **Requires the fleet profile** (`docker compose --profile fleet up -d`, SqlServer3).
- [bonus-deadlocks-and-tempdb.md](bonus-deadlocks-and-tempdb.md) — a real deadlock read from the XE ring buffer, plus tempdb pressure (~5 min). **Requires the fleet profile** (SqlServer4).
- [bonus-snapshot-freeze-safety.md](bonus-snapshot-freeze-safety.md) — agent-driven storage snapshot with a freeze-safety guarded block (~8 min). **Requires Pure Storage Fusion MCP + a separate demo environment outside sql-mcp-server** — not runnable with this repo alone.

## Fleet profile (optional, for the two bonus demos above)
Adds `SqlServer3` (maintenance neglect) and `SqlServer4` (deadlocks/tempdb) so
the fleet-wide demos have four genuinely different instances instead of two.
See [compose/README.md](../compose/README.md#fleet-profile-bonus-demos) for
bring-up and `.env` registration.

## Seed / reset scripts
All in [sql/](sql/), run from `demos/sql/` (they `source ../../.env`):

| Script | Used by |
|---|---|
| `seed-blocking.sh` / `reset-blocking.sh` | Demo 2 |
| `seed-fleet-load.sh` | Bonus: fleet-wide waits |
| `seed-ag-lag.sh` / `resume-ag.sh` | Demo 3 |
| `seed-backup-gaps.sql` | Demo 4 |
| `seed-security-issues.sh` / `reset-security-issues.sh` | Demo 5 |
| `seed-observability-load.sh` / `reset-observability-load.sh` | Demo 6 |
| `seed-maintenance-neglect.sh` / `reset-maintenance-neglect.sh` | Bonus: maintenance neglect (SqlServer3) |
| `seed-deadlocks-tempdb.sh` / `reset-deadlocks-tempdb.sh` | Bonus: deadlocks & tempdb (SqlServer4) |

## Demo-day checklist
See [recordings-and-demo-day.md](recordings-and-demo-day.md) for the fallback
recording list and the T-minus-60 setup checklist.

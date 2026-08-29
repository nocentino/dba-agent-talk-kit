# Fallback Recordings & Demo-Day Runbook

No deck backs this session — if a live demo stalls, the fallback is a recording
of the same demo, not a slide. Record every core demo once, clean.

## Recordings to capture (one sitting, ~45 min)
Record each demo end-to-end at 1080p+ with the VS Code font bumped to 16–18pt
(Cmd+= twice) so the back row can read tool-call names. Capture:

| File | Content | Trim to |
|---|---|---|
| demo0-intro.mp4 | (Optional — narration only, low priority to record) | — |
| demo1-install.mp4 | Clone → start.sh → health checks → mcp.json → tools appear → first prompt | ≤ 3:00 |
| demo2-blocking-dab.mp4 | Seed → prompt → tool chain → KILL recommendation → DAB aside | ≤ 3:00 |
| demo3-availability.mp4 | Suspend → prompt → CRITICAL verdict → resume → re-check HEALTHY | ≤ 3:00 |
| demo4-backup.mp4 | Prompt → exposure table ranked worst-first | ≤ 2:30 |
| demo5-security.mp4 | Seed 4 findings → prompt → ranked report → detect-never-remediate | ≤ 3:00 |
| demo6-observability.mp4 | Seed load → prompt → 7-step fixed-order incident report | ≤ 3:00 |
| demo7-guardrails.mp4 | (Optional — mostly narration over already-shown files) | — |

Tips: pause recording during model latency and jump-cut; keep the tool-call
expansion clicks IN — watching the chain is the content. Keep raw + trimmed copies.

## Demo-day checklist (T-minus 60 min)
1. Confirm the sql-mcp-server repo is NOT already running if you want the
   install demo to be genuine (`docker compose down -v` beforehand); otherwise
   pre-pull images so `./start.sh` isn't waiting on a slow registry live.
2. `./start.sh` → `docker compose ps` all healthy.
3. `curl localhost:3001/health` and `curl localhost:5001/health`.
4. AG overlay up; `compose/verify-ag.sh` returns HEALTHY/SYNCHRONIZED.
5. Run `demos/sql/seed-backup-gaps.sql`; take the fresh InventoryDB log backup.
6. Run `demos/sql/seed-observability-load.sh` (fast, ~10s) shortly before Demo 6.
7. Have `demos/sql/seed-security-issues.sh` / `reset-security-issues.sh` ready
   to run live during Demo 5 — don't pre-seed, the "before" state is part of the demo.
8. VS Code: remove/comment `sql-dba` + `products-db` from `mcp.json` if you want
   Demo 1's "tools appear" moment to be real; otherwise leave wired up and skip
   straight to Demo 2. Font size up, theme high-contrast, notifications OFF,
   every other window closed.
9. Seven chat sessions pre-named: D1 D2 D3 D4 D5 D6 D7 — one fresh chat per demo, always.
10. Have `sql-mcp-server/src/safety.ts`, `dab-config.json`,
    `skills/security-audit.instructions.md`, and `skills/availability.instructions.md`
    open in editor tabs, ready for Demo 7.
11. Recordings on local disk AND a USB stick. Test the venue's video playback.
12. Hotspot tested — Copilot needs internet even though SQL Server doesn't.

## The one rule
If a live demo stalls for more than ~45 seconds, narrate the recording instead.
Nobody remembers that you switched to a recording; everyone remembers dead air.

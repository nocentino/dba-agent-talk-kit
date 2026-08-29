# Demo 5 — Skill: Security & Auditing (Objective 2, ~6 min)

**Point being made:** the four security tools return facts. The skill turns facts
into a ranked, audit-ready finding list — and it draws a hard line the tools alone
don't: detect, never remediate. This demo hits the "detect vs fix" trust boundary
head-on, which is the clearest possible setup for Demo 7's guardrail synthesis.

## Demo style
Two modes in this one: **editor + terminal** for the seed script (open
`demos/sql/seed-security-issues.sh` in the editor, run it in the integrated
terminal below), then **Copilot Chat, agent mode** for the investigation.

## Pre-demo state
- Fresh Copilot chat. Attach `skills/security-audit.instructions.md` as context
  (Add Context → Instructions) — deterministic beats automatic on stage.
- Stack up, `sql-dba` tools visible.

## Setup — seed four findings (open in editor, run below)
`demos/sql/seed-security-issues.sh`:
```bash
#!/usr/bin/env bash
# Demo 5 seed: config drift + rogue sysadmin + orphaned user + failed-login spray.
...
echo "1/4 Config drift: enabling xp_cmdshell + Ad Hoc Distributed Queries..."
...
echo "2/4 Privileged access: adding a rogue sysadmin login (svc_reporting)..."
...
echo "3/4 Orphaned user: creating a ProductsDB user, then dropping its login..."
...
echo "4/4 Failed logins: generating a spray pattern in the error log..."
```
Run it:
```bash
cd demos/sql
./seed-security-issues.sh
```
This deliberately puts the instance in a non-compliant state: `clr enabled` and
`Ad Hoc Distributed Queries` enabled (baseline says both should be 0), a brand-new
login (`svc_reporting`) added straight to `sysadmin`, a `ProductsDB` user
(`temp_migration_login`) left orphaned after its login was dropped, and a handful
of failed login attempts — some against a real account, some against a login that
doesn't exist (`admin_probe`, a recon pattern).

## The prompt (paste into Copilot Chat)
> Run a security review of SqlServer1. Check configuration drift, privileged
> role membership, failed logins in the last 24 hours, and orphaned database
> users. Tell me what's wrong and how bad it is.

## Expected agent behavior (narrate as it happens)
1. `get_security_config_drift(instance_name: "SqlServer1")` → `clr enabled` and
   `Ad Hoc Distributed Queries` both non-compliant (1 vs required 0).
2. `get_sysadmin_members(instance_name: "SqlServer1")` → flags `svc_reporting`:
   SQL login, added to `sysadmin` within the last 30 days —
   `recently_modified_flag = 1`. Also reports `sa` if enabled (likely yes in this
   dev container) — the skill flags this as a standing finding, not a surprise.
3. `get_failed_logins(instance_name: "SqlServer1", hours: 24)` → aggregated by
   login + client, surfaces the spray pattern against `sa` and the recon pattern
   against the nonexistent `admin_probe` login.
4. `get_orphaned_users(instance_name: "SqlServer1")` → `temp_migration_login` in
   `ProductsDB`, SID with no matching server login.
5. Ranks findings per the skill's decision rules: (1) active-attack indicators
   — the failed-login pattern — first; (2) privileged-access violations —
   `svc_reporting` in sysadmin — second; (3) surface-area drift — the two config
   settings — third; (4) hygiene — the orphaned user — last.
6. States facts + baseline deltas as neutral evidence ("Login `svc_reporting` was
   added to sysadmin on `<date>`"), **not** an accusation — that's the skill's
   explicit rule.

## Talking points while it runs
- "Notice what it does NOT do: no `DROP LOGIN`, no `EXEC sp_configure ... 0`, no
  fix of any kind. The skill's hard boundary is detect, never remediate in the
  same breath as the finding — remediation goes through change control."
- "The ranking isn't alphabetical. Active-attack indicators outrank a config
  setting that's been wrong for months. That ordering is written down in the
  skill, not improvised per run."
- "This is the same four tools whether or not the skill is attached. Ask it
  again without the skill loaded and you get a data dump, not a verdict."

## Reset
```bash
cd demos/sql
./reset-security-issues.sh
```
Restores `clr enabled` / `Ad Hoc Distributed Queries` to 0, drops the rogue
`svc_reporting` login, and removes the orphaned `temp_migration_login` user.
Failed-login history stays in the error log (harmless) — a fresh log cycle
before the next demo day clears it, or ignore it, it will just show as older.

## Failure modes / fallback
- **`get_failed_logins` returns 0 rows** → `sp_readerrorlog` reads the *current*
  error log; if SQL Server has cycled logs since the spray, re-run just the
  spray loop from the seed script, or pass a wider `hours` value.
- **Agent doesn't lead with the failed-login pattern** → follow-up: "which of
  these is most urgent right now and why?" — narrate that skills tighten
  behavior, they don't guarantee a perfect first pass.
- **`svc_reporting` not flagged as recent** → check the container clock; a
  restarted container with a stale system clock breaks the 30-day window math.

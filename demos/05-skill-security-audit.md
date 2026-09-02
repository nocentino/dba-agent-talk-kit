# Demo 5 · Skill: Security & Auditing

**Four tools return facts. The skill turns them into a ranked, audit-ready finding list — and draws the hard line: detect, never remediate.**

---

## Before you start

- Fresh Copilot chat; attach [security-audit.instructions.md](../.github/instructions/security-audit.instructions.md)
- Stack up, `sql-dba` tools visible

---

## Setup — seed four findings

```bash
./demos/sql/seed-security-issues.sh
```

1. **Config drift** — `clr enabled` + `Ad Hoc Distributed Queries` turned on
2. **Rogue sysadmin** — brand-new `svc_reporting` login added straight to `sysadmin`
3. **Orphaned user** — `temp_migration_login` in `ProductsDB`, its login dropped
4. **Failed logins** — a spray at `sa` + recon against the nonexistent `admin_probe`

---

## The prompt

> Run a security review of SqlServer1. Check configuration drift, privileged
> role membership, failed logins in the last 24 hours, and orphaned database
> users. Tell me what's wrong and how bad it is.

---

## What you'll see — ranked by the skill's rules

1. **Active-attack indicators** — the failed-login spray / recon — *first*
2. **Privileged-access violations** — `svc_reporting` in sysadmin
3. **Surface-area drift** — `clr enabled`, `Ad Hoc Distributed Queries`
4. **Hygiene** — the orphaned `temp_migration_login`

Facts + baseline deltas ("added to sysadmin on `<date>`"), never accusations.

---

## Why it matters

- What it does **NOT** do: no `DROP LOGIN`, no `sp_configure ... 0`. **Detect, never remediate.**
- The ranking isn't alphabetical — active attacks outrank months-old drift, and that order is *written down*
- Same four tools with or without the skill — without it, a data dump, not a verdict

---

**Next:** [Demo 6 · Skill: Observability →](06-skill-observability.md)

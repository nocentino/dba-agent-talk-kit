# Interlude · Anatomy of a Skill File

**You just watched the agent use tools with no guidance. A skill file is how you turn "an agent with tools" into *your* SRE running *your* runbook.**

---

## A skill file is a markdown SOP

Plain markdown. No code. Six parts, in order:

1. **Persona**: one paragraph: who the agent is, who it serves
2. **Trigger conditions**: when this skill applies, so the agent self-selects
3. **Procedure**: the exact tool sequence, as numbered steps
4. **Thresholds in tables**: numbers, not adjectives. "Healthy" is a *value*
5. **Decision rules**: if/then, so the output is consistent run to run
6. **Hard boundaries**: what the agent must never do, and when to hand off

---

## Thresholds are the heart of it

The difference between a chatbot and your SRE: *good* is a number **you** defined.

| Metric | Healthy | Warning | Critical |
|---|---|---|---|
| send queue (sync) | < 1 MB | 1-10 MB | > 10 MB |
| redo queue | < 10 MB | 10-100 MB | > 100 MB |
| estimated data loss | < 15 s | 15-60 s | > 60 s |

The agent doesn't guess what "behind" means; you told it, once, in the file.

---

## Hard boundaries are why security signs off

Every skill ends with what the agent must **never** do:

- *"Never force failover with data loss unless the human explicitly accepts it"*
- *"Detect, never remediate in the same breath as the finding"*
- *"Never restore over a database without `WITH REPLACE` called out in red"*

Enforced by the file, not by the model's mood.

---

## Wiring it into Copilot

`.github/instructions/*.instructions.md`, each with frontmatter:

```yaml
---
applyTo: "**"
description: "Availability management SOP for the SQL Server estate"
---
```

- `applyTo` scopes it; `description` lets Copilot self-select the right skill
- Or attach it by hand (Add Context → Instructions); most deterministic on stage
- Same file drops into Claude, Cursor, anything that takes context. **The skill outlives the client.**

---

## The next four demos

Same tools you saw in Demo 2, now with a skill on top. Watch the answer change
from *data* to *a verdict*:

**Availability · Backup & Recovery · Security · Observability**

---

**Next:** [Demo 3 · Skill: Availability (AG Health) →](03-skill-availability-ag-health.md)

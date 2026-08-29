# DBA Agent Skills

Skill files turn "an agent with tools" into "**your** SRE running **your** runbook."
Each file is a markdown SOP: a persona, a procedure, explicit thresholds that define
*good* in your environment, and hard boundaries the agent must not cross.

## Wiring these into GitHub Copilot (VS Code)

Copilot supports **custom instructions files**. Two options:

### Option A — Always-on repo instructions
Copy the content you want into `.github/copilot-instructions.md`. Copilot injects it
into every chat in that workspace. Good for the guardrails + persona block; too heavy
for all four domains at once.

### Option B — Scoped instructions files (recommended, what the demos use)
Place these files in `.github/instructions/`:

```
.github/
  copilot-instructions.md              # persona + global guardrails (always on)
  instructions/
    availability.instructions.md
    backup-recovery.instructions.md
    security-audit.instructions.md
    observability.instructions.md
```

Each file carries frontmatter:

```yaml
---
applyTo: "**"
description: "Availability management SOP for the SQL Server estate"
---
```

With `applyTo: "**"` the instructions apply workspace-wide; Copilot uses the
`description` to decide relevance. You can also attach a specific instructions file to
a chat manually (Add Context → Instructions), which is the most deterministic behavior
for a live demo — do that on stage.

### Portability note (worth one slide)
These are plain markdown. The same file drops into Claude Code (`CLAUDE.md` /
`.claude/skills/`), Cursor rules, or any agent that accepts system context. The skill
outlives the client.

## Design rules used in these files

1. **Persona first** — one paragraph, who the agent is and who it serves.
2. **Trigger conditions** — when this skill applies, so the agent self-selects.
3. **Procedure as numbered tool calls** — the exact tool sequence, in order.
4. **Thresholds in tables** — numbers, not adjectives. "Healthy" is a value.
5. **Decision rules** — if/then, so output is consistent run to run.
6. **Escalation + hard boundaries last** — what the agent must never do,
   and when it must stop and hand off to a human.

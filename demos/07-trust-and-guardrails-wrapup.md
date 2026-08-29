# Demo 7 — Trust & Guardrails, Synthesized (Objective 3, ~5 min)

**Point being made:** this is not a new demo — it's pointing back at six things
you already watched happen, and naming the pattern. Every guardrail in this
session was a design decision made once, in code or in a markdown file, not a
prompt you have to trust the model to obey.

## Demo style
Narration + editor. Open the four files below in tabs as you talk through them;
no new tool calls needed, everything was already proven live.

## The guardrail stack (draw or paste, no deck)
```
 Layer 6   Audit trail        every tool call is logged server-side — if it
                               isn't logged, it didn't happen (out of scope
                               for this repo, but say the words)
 Layer 5   Human approval     the KILL recommendation in Demo 2; the manual
                               ALTER DATABASE ... RESUME in Demo 3; every
                               remediation in Demo 5 is drafted, never run
 Layer 4   Skill judgment     hard boundaries written into each skill file:
                               "never force failover," "never overwrite
                               without WITH REPLACE," "detect, never remediate"
 Layer 3   Scoped access      DAB's dab-config.json — 4 tables, explicit verbs,
                               nothing else exists to be called
 Layer 2   Query allowlist    safety.ts — SELECT / WITH / DECLARE only,
                               enforced in code before a query ever runs
 Layer 1   Least privilege    dba_monitor login — VIEW SERVER STATE, no DML/DDL
                               grants, no stored procedures of its own
```

## Walk the evidence (point at real files, not slides)
1. **`sql-mcp-server/src/safety.ts`** — `validateQuery()`, the `BLOCKED_PATTERNS`
   list. Read one or two patterns aloud. This runs before every `execute_query`
   call, no model judgment involved.
2. **`dab-config.json`** — the four entities and their permitted actions. DAB
   enforces this independent of what the agent asks for.
3. **`skills/security-audit.instructions.md`** — the "Hard boundaries" section
   from Demo 5. Read the "detect, never remediate" line verbatim.
4. **`skills/availability.instructions.md`** — the `FORCE_FAILOVER_ALLOW_DATA_LOSS`
   boundary from Demo 3: never drafted unless the human explicitly states the
   primary is lost and accepts data loss, and even then it's presented with a
   warning block, typed by the human.

## The one question every security/ops reviewer asks, answered
> "What can this agent actually do to my server without me approving it?"

Answer, stated plainly: **nothing that mutates state.** Every tool in `sql-dba`
is read-only by construction (`safety.ts` + a login with no write grants).
`products-db` (DAB) can write, but only to four named tables, only via verbs
`dab-config.json` allows. Every demo this hour that involved a fix — the KILL,
the AG resume, the security remediation — ended with a **drafted script**, not
an executed one.

## Talking points
- "Count the number of times this hour the agent said 'here's the fix' and
  then didn't run it. That count is the whole pitch."
- "None of these six layers depend on the model being well-behaved. They'd
  hold even against a model actively trying to misbehave — that's what 'enforced
  in code' means as opposed to 'asked nicely in a prompt.'"
- "This is also why the skill files are boring to read. A skill file that's
  interesting to read is usually one that's persuading instead of constraining."

## Reset
None — synthesis only.

## Failure modes / fallback
- If you're short on time, this can compress to 2 minutes: skip the file
  walk-through, just say the six layers and point at the KILL-recommendation
  screenshot still on screen from Demo 2.

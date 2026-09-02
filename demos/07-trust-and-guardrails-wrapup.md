# Demo 7 · Trust & Guardrails, Synthesized

**Not a new demo. This is a name for the pattern you watched six times. Every guardrail was a decision made once, in code or a markdown file, not a prompt you hope the model obeys.**

---

## The guardrail stack

| Layer | Guardrail | Enforced by |
|---|---|---|
| 6 | Audit trail | every tool call logged server-side |
| 5 | Human approval | the KILL, the AG resume, every fix; drafted, never run |
| 4 | Skill judgment | "never force failover", "detect, never remediate" |
| 3 | Scoped access | `dab-config.json`: 4 tables, explicit verbs |
| 2 | Query allowlist | `safety.ts`: SELECT / WITH / DECLARE only |
| 1 | Least privilege | `dba_monitor`: VIEW SERVER STATE, no writes |

---

## Walk the evidence: real files, not slides

- **[`sql-mcp-server/src/safety.ts`](https://github.com/nocentino/sql-mcp-server/blob/main/sql-mcp-server/src/safety.ts)**: `validateQuery()` + `BLOCKED_PATTERNS`, runs before every query
- **`dab-config.json`**: four entities, permitted verbs, enforced by DAB
- **[security-audit.instructions.md](../.github/instructions/security-audit.instructions.md)**: read "detect, never remediate" verbatim
- **[availability.instructions.md](../.github/instructions/availability.instructions.md)**: `FORCE_FAILOVER_ALLOW_DATA_LOSS` never drafted unless a human accepts data loss

---

## The question every reviewer asks

> "What can this agent do to my server without me approving it?"

**Nothing that mutates state.**

- `sql-dba` is read-only by construction: `safety.ts` + a login with no write grants
- `products-db` (DAB) writes only to four named tables, only via allowed verbs
- Every fix this hour, the KILL, the AG resume, the remediation, ended as a **drafted script**

---

## Why it matters

- Count the times the agent said "here's the fix" and didn't run it. **That count is the pitch.**
- None of the six layers depend on the model behaving; they hold against one that misbehaves
- That's what *enforced in code* means, versus *asked nicely in a prompt*

---


## Start Monday

1. **Stand up the stack**: `docker compose up -d` (SQL ×2 + DAB + MCP server)
2. **Wire `mcp.json`**: point Copilot at `:3001` and `:5001`
3. **Drop in the skills**: copy the four `*.instructions.md` files into `.github/instructions/`
4. **Write your own**: persona → triggers → procedure → **thresholds** → rules → boundaries

> Repo: **github.com/nocentino/sql-mcp-server**, the MCP server, the compose stack, and the wiring.

The architecture is four markdown files and an HTTP endpoint. That's the whole thing.

---

**Next (bonus):** [Snapshot Freeze-Safety →](bonus-snapshot-freeze-safety.md)

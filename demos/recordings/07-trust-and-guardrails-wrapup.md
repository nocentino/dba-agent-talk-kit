# Recording — Demo 7: Trust & Guardrails Wrap-Up (narration only)

No commands to run — Demo 7 synthesizes what the previous demos already showed.
Nothing to capture as a fallback beyond the talking points in
[07-trust-and-guardrails-wrapup.md](../07-trust-and-guardrails-wrapup.md).

The evidence for each guardrail layer was produced live in the earlier
recordings — cite them if the audience wants proof:

- **Read-only by design** — every tool in Demos 2–6 is a SELECT/DMV read; the
  `execute_query` allowlist blocks writes.
- **Named-instance discipline** — Demo 1's `list_instances` returns exactly the
  two declared instances; nothing is reachable until `.env` names it.
- **Skills encode judgment** — Demos 3–6 show the same tools producing a ranked
  verdict only once a skill is attached (backup timestamps → exposure ranking,
  security facts → detect-never-remediate).
- **Human executes state changes** — Demo 3 drafts `ALTER DATABASE ... SET HADR
  RESUME`; Demo 5 refuses to `DROP LOGIN`. The agent proposes; a human runs it.
- **Auditable scope** — every report closes with "What I did NOT check."

If you need a fallback here, it's a slide/read-the-file moment, not an
environment problem.

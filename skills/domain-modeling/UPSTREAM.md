# Upstream

Vendored from [`mattpocock-skills`](https://github.com/mattpocock/skills) **1.3.1**, `skills/engineering/domain-modeling/`. MIT licensed: the upstream notice is in [LICENSE](LICENSE) and must stay with this skill.

Re-syncing is a deliberate factory-repo PR: diff this directory against the new upstream version, carry the changes below forward, and bump `metadata.upstream.version` in `SKILL.md` and the version above.

## Factory adaptations

Common to every factory skill:

- Model-invocable, so a factory task skill can call it through the Skill tool at a fixed step (`disable-model-invocation: true` blocks the Skill tool). The `description` restricts it to task-skill calls.
- Every "ask the user" becomes a `needs-human` outcome (a question with a recommended answer, or a give-up reason) handed back to the task skill.
- No dependency on `docs/agents/*`. Cross-references use `factory:` names.
- Upstream's `agents/openai.yaml` (Codex metadata), where present, is dropped.

Specific to `domain-modeling`:

- The person upstream talks to is replaced by the **ticket thread**. Glossary conflicts, fuzzy terms, edge-case scenarios and code contradictions are resolved from the thread and the code; anything left open is a `needs-human` outcome with a recommended answer.
- Glossary entries only for concepts the change introduces or renames.
- "Offer ADRs sparingly" becomes "record decisions, never make them" (design spec §6 Domain docs): ADRs only for decisions already in the thread, citing the comment; a missing ADR-worthy decision → `needs-human`; a contradicted ADR → `needs-human` ("premise is wrong") unless the ticket asks for supersession; a new or superseded ADR is declared in Merge Danger.
- `ADR-FORMAT.md`: template gains a required `Decided in:` link; "When to offer an ADR" becomes "When a decision is ADR-worthy".
- `GLOSSARY-FORMAT.md`: "if unclear, ask" becomes a `needs-human` outcome.

# Upstream

Vendored from [`mattpocock-skills`](https://github.com/mattpocock/skills) **1.3.1**, `skills/engineering/codebase-design/`. MIT licensed: the upstream notice is in [LICENSE](LICENSE) and must stay with this skill.

Re-syncing is a deliberate factory-repo PR: diff this directory against the new upstream version, carry the changes below forward, and bump `metadata.upstream.version` in `SKILL.md` and the version above.

## Factory adaptations

Common to every factory skill:

- `disable-model-invocation: true`: a factory task skill calls this skill at a fixed step; the model never picks it.
- Every "ask the user" becomes a `needs-human` outcome (a question with a recommended answer, or a give-up reason) handed back to the task skill.
- No dependency on `docs/agents/*`. Cross-references use `factory:` names.
- Upstream's `agents/openai.yaml` (Codex metadata), where present, is dropped.

Specific to `codebase-design`:

- `SKILL.md`: added "Refactors in a factory run" (no behaviour change; tests may move to the new interface but no assertion is dropped).
- `DESIGN-IT-TWICE.md`: the problem framing and design comparison are written down instead of shown to the user; the agent picks a design and records it in the PR Summary. An ADR-worthy interface choice not made in the ticket thread is a `needs-human` outcome.
- `DEEPENING.md` is unchanged.

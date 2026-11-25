# Upstream

Vendored from [`mattpocock-skills`](https://github.com/mattpocock/skills) **1.3.1**, `skills/engineering/tdd/`. MIT licensed: the upstream notice is in [LICENSE](LICENSE) and must stay with this skill.

Re-syncing is a deliberate factory-repo PR: diff this directory against the new upstream version, carry the changes below forward, and bump `metadata.upstream.version` in `SKILL.md` and the version above.

## Factory adaptations

Common to every factory skill:

- Model-invocable, so a factory task skill can call it through the Skill tool at a fixed step (`disable-model-invocation: true` blocks the Skill tool). The `description` restricts it to task-skill calls.
- Every "ask the user" becomes a `needs-human` outcome (a question with a recommended answer, or a give-up reason) handed back to the task skill.
- No dependency on `docs/agents/*`. Cross-references use `factory:` names.
- Upstream's `agents/openai.yaml` (Codex metadata), where present, is dropped.

Specific to `tdd`:

- **Seams** are written down and justified from the ticket's acceptance criteria instead of confirmed with the user, and carried into the PR's Evidence. A seam that needs an unmade decision is a `needs-human` outcome.
- `codebase-design` → `factory:codebase-design`. `code-review` → `factory:review`.
- Added: never weaken a test to get green (task contract, design spec §7).
- `tests.md` and `mocking.md` are unchanged.

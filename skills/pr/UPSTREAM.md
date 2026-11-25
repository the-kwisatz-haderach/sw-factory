# Upstream

Vendored from [`mattpocock-skills`](https://github.com/mattpocock/skills) **1.3.1**, `skills/engineering/pr/`. MIT licensed: the upstream notice is in [LICENSE](LICENSE) and must stay with this skill.

Re-syncing is a deliberate factory-repo PR: diff this directory against the new upstream version, carry the changes below forward, and bump `metadata.upstream.version` in `SKILL.md` and the version above.

## Factory adaptations

Common to every factory skill:

- Model-invocable, so a factory task skill can call it through the Skill tool at a fixed step (`disable-model-invocation: true` blocks the Skill tool). The `description` restricts it to task-skill calls.
- Every "ask the user" becomes a `needs-human` outcome (a question with a recommended answer, or a give-up reason) handed back to the task skill.
- No dependency on `docs/agents/*`. Cross-references use `factory:` names.
- Upstream's `agents/openai.yaml` (Codex metadata), where present, is dropped.

Specific to `pr`:

- The body is written to the file the task skill names (the implementer's `pr-body.md`) and rewritten in full every run.
- Template gains `Closes #<n>`; the required headings are called out because a deterministic step checks them.
- Evidence must be produced by the run; screenshots only when the target repo's `CLAUDE.md` says how, otherwise a marked written description; per-class Evidence list (design spec §7).
- Merge Danger must name security-sensitive code, new dependencies, breaking changes, migrations and new/superseded ADRs.
- Unrelated issues go to the job summary, not the PR.
- "The user" in the Summary guidance becomes "the reviewer". The visuals menu credited in [CREDITS.md](CREDITS.md) (Dex Horthy / Humanlayer `show-me`) is otherwise verbatim, and the `metadata.credits` frontmatter is kept.

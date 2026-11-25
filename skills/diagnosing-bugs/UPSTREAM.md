# Upstream

Vendored from [`mattpocock-skills`](https://github.com/mattpocock/skills) **1.3.1**, `skills/engineering/diagnosing-bugs/`. MIT licensed: the upstream notice is in [LICENSE](LICENSE) and must stay with this skill.

Re-syncing is a deliberate factory-repo PR: diff this directory against the new upstream version, carry the changes below forward, and bump `metadata.upstream.version` in `SKILL.md` and the version above.

## Factory adaptations

Common to every factory skill:

- Model-invocable, so a factory task skill can call it through the Skill tool at a fixed step (`disable-model-invocation: true` blocks the Skill tool). The `description` restricts it to task-skill calls.
- Every "ask the user" becomes a `needs-human` outcome (a question with a recommended answer, or a give-up reason) handed back to the task skill.
- No dependency on `docs/agents/*`. Cross-references use `factory:` names.
- Upstream's `agents/openai.yaml` (Codex metadata), where present, is dropped.

Specific to `diagnosing-bugs`:

- "The user's symptom" becomes the symptom the **ticket** describes.
- "Ask the user" (redaction, no loop possible) becomes a `needs-human` outcome; "can't reproduce" lists what was tried and recommends what to ask for.
- Loop option 10 (HITL bash script via `scripts/hitl-loop.template.sh`, which upstream doesn't ship) is removed: there is no human in an unattended run. "Agent-runnable" no longer allows a human in the loop.
- Phase 3: the ranked hypotheses are written into the run's record instead of shown to the user, and re-ranked on the ticket thread.
- Phase 5 points at `factory:tdd`. A missing seam is noted in the PR's Evidence; a fix that won't go green is a `needs-human` outcome.
- Phase 6: the correct hypothesis goes in the commit message **and** the PR body.

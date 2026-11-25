# Upstream

Vendored from [`mattpocock-skills`](https://github.com/mattpocock/skills) **1.3.1**, `skills/engineering/code-review/SKILL.md`, **unchanged**. MIT licensed: the upstream notice is in [LICENSE](LICENSE) and must stay with any skill built from this file.

This directory is outside the plugin's `skills/`, so it doesn't load as a skill. It is source material for the `factory:review` task skill ([design spec §8](../../../docs/factory-design.md#8-task-automated-review)), which folds it in. When it is folded, keep this LICENSE alongside `factory:review` and record the upstream version there.

## What folding must change

Every place upstream talks to a user, and what it becomes in an unattended review run:

| Upstream | In `factory:review` |
| --- | --- |
| "If not, tell the user to run `/setup-matt-pocock-skills`" (issue tracker) | Drop: the tracker is the target repo's GitHub Issues, and the ticket comes from the PR body's `Closes #<n>`. No `docs/agents/*`. |
| Step 1: the user supplies the fixed point, or is asked for one | The PR's base: diff the PR head against its merge-base with the base branch. |
| Step 2: spec search order, then "ask the user where the spec is" | The ticket from `Closes #<n>` (body and thread), plus the PR body's **Evidence** and **Merge Danger**. Never ask. |
| Step 3: standards sources | `CODING_STANDARDS.md` / `CONTRIBUTING.md`, plus `factory:domain-modeling` and `factory:codebase-design` on the Standards axis. Keep the smell baseline as written. |
| Step 4: sub-agent briefs | Keep both parallel sub-agents. The Spec brief also checks the Evidence is real and produced by the run, and that any new or changed ADR matches the ticket thread. |
| Step 5: "present the two reports" to the user | One `claude[bot]` comment review with inline comments, and an outcome file `pass` or `fail`. |
| Findings have no verdict | Fail only on: doesn't do what the ticket asks, a correctness bug, a violated documented standard, missing or fake Evidence, an ADR departing from the thread. Everything else (nits, smells, Merge Danger disagreement, glossary drift unless a standard makes it a rule) is a comment only. |

Also: `disable-model-invocation: true`; never push code or run checks.

# Upstream

Folded from [`mattpocock-skills`](https://github.com/mattpocock/skills) **1.3.1**, `skills/engineering/code-review/SKILL.md`, into the `factory:review` task skill. MIT licensed: the upstream notice is in [LICENSE](LICENSE) and must stay with this skill.

Re-syncing is a deliberate factory-repo PR: diff the upstream skill against the version above, carry the changes below forward, and bump `metadata.upstream.version` in `SKILL.md` and the version above.

## Factory adaptations

Unlike the factory skills, this is a task skill: `disable-model-invocation: true`, started only by the review workflow's `/factory:review` prompt.

| Upstream | In `factory:review` |
| --- | --- |
| "Tell the user to run `/setup-matt-pocock-skills`" (issue tracker) | Dropped. The workflow fetches the ticket named by the PR body's `Closes #<n>` (or the branch) into `ticket.md`. No `docs/agents/*`. |
| Step 1: the user supplies the fixed point, or is asked for one | The PR's merge-base with its base branch, given in the prompt; the workflow writes the diff to `diff.patch`. |
| Step 2: spec search order, then "ask the user where the spec is" | The ticket thread in `ticket.md`, plus the PR body's **Evidence** and **Merge Danger** in `pr-body.md`. Never ask. |
| Step 3: standards sources | Kept, plus `CLAUDE.md`, and the base branch's versions of them (restored by the workflow). The Standards sub-agent also reads through `factory:domain-modeling` and `factory:codebase-design`. Smell baseline verbatim. |
| Step 4: sub-agent briefs | Both parallel sub-agents kept, read-only. Standards also reports correctness bugs. Spec also checks the Evidence is real and that any new or changed ADR matches the ticket thread. Both give file and line for inline comments. |
| Step 5: "present the two reports" | Written to `review.json` (body plus inline comments) and posted by the workflow as one `claude[bot]` comment review; a verdict in `outcome.json`. |
| Findings have no verdict | Added a verdict step: fail only on the five criteria of design spec §8; everything else is a comment. |

Also added: the task contract (never push, commit, run checks or post), and the cold-read framing.

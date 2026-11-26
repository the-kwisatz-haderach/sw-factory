# Coding standards

Read during review. The mechanical rules (shebangs, usage headers, strict mode, test-file shape) are enforced by `scripts/check-conventions`; shellcheck and actionlint cover the rest of what a tool can see. This file holds the judgement calls.

## Scripts

- **Decide in a script, act in the workflow.** A script reads files or stdin and prints a decision; the workflow step makes the GitHub calls around it (`pick-ticket`, `read-outcome`, `board/plan`). A script that must call GitHub is a thin wrapper around one that doesn't (`board/sweep` around `board/plan`), so the logic stays testable without a network. A step's early exit on what it read from GitHub (a PR's state or head, a ticket's labels) is a decision too (`review/rework-skip`); only a check on the triggering event's own payload stays inline.
- **Every script that decides something has a test** in `scripts/test/<name>.test.sh`, at the script's own interface. Expected values are literals worked out by hand, never recomputed the way the script computes them.
- **Agent output fails closed.** Anything an agent writes (the outcome file, the PR body, a review) is untrusted input: validate its shape, and route anything unexpected to a failed run or a hand-back, never to a push or a pass.
- **One source per contract.** A list or format that both a skill and a script rely on (`scripts/implementer/ticket-classes`) lives in one file, with a test that the skill's prose still matches it.

## Workflows

- **Comments say why**: the constraint, the failure it prevents, or the spec section it implements. Every step in `implementer.yml` and `review.yml` is the model.
- **The agent step holds no token it could misuse.** No job-level `GH_TOKEN`; each bookkeeping step sets its own, and nothing is pushed until the agent's outcome has been checked.

## Skills

- **The task contract is in the task skill**; factory skills carry method, not policy. A rule that must hold whatever skill runs (a Stop condition, a prohibition) goes in `skills/<task>/SKILL.md` or `system.md`.
- **Stop is always an outcome**, never a question: where a person would be asked, the skill ends in `needs-human` with a question and a recommended answer.

## Docs

- **The spec moves with the code.** A change to behaviour `docs/factory-design.md` describes updates it in the same commit; a §13 item a change answers gets its answer recorded there.
- **Public-repo rule:** a diff follows the rule in `CLAUDE.md`; a target repo's name, URL or code in it is a finding.

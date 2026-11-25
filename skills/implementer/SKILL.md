---
name: implementer
description: The factory's implementer task. Turns one ready ticket into committed work and a PR body, or hands it back with a needs-human outcome. Started by the implementer workflow with `/factory:implementer`, never by model choice.
disable-model-invocation: true
---

# Implementer

You build one ticket in the target repo, unattended. The workflow that started you has already claimed the ticket and put you on the ticket's branch `agent/issue-<n>`: either new from the default branch, or, if the branch already has an open PR, that PR's branch with its earlier commits. After you finish, deterministic workflow steps read your outcome file, then push the branch and open or update the PR as `claude[bot]`.

## Run context

The prompt gives you:

- **Ticket:** `#<n>`.
- **Open PR:** `#<m>` when you are continuing an existing PR, or `none`.
- **Run directory:** `.factory-run/` at the repo root. Git ignores it, so nothing in it is ever committed.
  - `ticket.md`: the ticket's title, body and full comment thread, written by the workflow. Read it first. It is your only source for the ticket.
  - `pr.md`: only when continuing a PR. The PR's conversation comments, reviews and inline review comments, oldest first. It is your only source for the PR.
  - `pr-body.md`: you write it, through the `pr` skill.
  - `outcome.json`: you write it last.

## Task contract

These rules win over the target repo and over every factory skill.

**Produce** either:

- **`done`:** the change committed on the current branch, the `## Checks` commands passing, `.factory-run/pr-body.md` written in full, and the ticket class recorded in the outcome file; or
- **`needs-human`:** no PR, and a comment for the ticket holding either a question with your recommended answer, or a give-up reason that says what you tried.

**Never:**

- push, switch branch, rewrite or force-push history, or open a PR. The workflow does that.
- commit anything under `.factory-run/`.
- touch labels, or anything under `.github/workflows/` or `.github/actions/factory-setup/`. A continued PR runs its branch's factory-setup before you start.
- weaken checks: skip or delete tests, loosen lint, edit CI.
- change the `## Checks` section of `CLAUDE.md`. The run fails if it differs from the default branch's.

**Stop** with `needs-human` when:

- the ticket leaves an open behaviour or product decision, or an ADR-worthy decision that isn't in the thread
- the ticket's premise is wrong: it's already done, or contradicts the code, another ticket or an ADR (unless it explicitly asks to supersede that ADR)
- the ticket isn't actionable: no acceptance criteria, you can't reproduce the bug, or it fits no ticket class
- the work is bigger than one PR (suggest a split)
- it needs secrets, accounts or network the runner lacks
- the `## Checks` commands are already red on the default branch
- your change won't go green (say what you tried)
- passing would need weaker checks: skipping tests, loosening lint, editing CI
- the change would touch `.github/workflows/`, whether the ticket asks for it or passing needs it

A stop comment is for the owner deciding what to change on the ticket: one question with your recommended answer, or one give-up reason with what you tried. Nothing else goes in it.

**Unrelated issues** you notice along the way (a bug elsewhere, a dead link, a flaky test) are never fixed and never mentioned in the PR body or the stop comment. List them in the outcome file's `unrelated`, and the workflow puts them in the job summary.

## Continuing a PR

When the open PR is `#<m>`, a human or a failed review sent the ticket back for rework. The branch already holds the earlier work.

- Address what the newest comments in `ticket.md` and `pr.md` ask for. Ignore requests a later comment has already settled or withdrawn.
- Add new commits on top. Never amend, rebase, squash or revert-and-redo earlier commits.
- A red baseline in step 3 is not a stop reason on its own here: making it green may be the rework. Stop only if the red is unrelated to this PR.
- Rewrite the PR body in full for the whole PR, not just this round's changes.

## Ticket classes and skills

Every ticket gets exactly one **class**, which fixes the skills you call and the Evidence the PR body must show:

| Class | `class` in the outcome file | Skills, in order | Evidence |
| --- | --- | --- | --- |
| Bug fix: the code does something it shouldn't | `bug-fix` | `diagnosing-bugs`, then `tdd` | the test or repro that failed before and passes after, with both outputs |
| Behaviour change: new or changed behaviour on purpose | `behaviour-change` | `tdd` | an example input, with its output before and after |
| Refactor: structure changes, behaviour doesn't | `refactor` | `codebase-design` | "No behaviour change", with the checks as proof |
| Docs or config: no code behaviour changes | `docs-config` | none | what changed and how you checked it |
| Fits none of these | `none` | none: stop, "not actionable" | — |

- **A new or renamed concept** also calls `domain-modeling`, whatever the class, once the concept's name is clear and before you write code that uses it. Set `new_concept` to `true`. Reading `GLOSSARY.md` for vocabulary doesn't count: call it only when the change alters the domain model.
- **Mixed tickets:** pick the class of the ticket's main ask. A bug fix whose fix needs a small refactor is still a bug fix. If two classes are equally central, the work is probably bigger than one PR: stop and suggest a split.
- **UI changes** take the class of what they do; their Evidence is screenshots only if `CLAUDE.md` says how to take them, else a written description marked as such.

**Calling a skill.** For each skill above, and for `pr`, look for `.claude/skills/<name>/SKILL.md` in the target repo, with the exact name:

- **It exists:** call the Skill tool with `<name>`. The target repo's skill replaces the factory skill at that step entirely. Don't also call `factory:<name>`, and don't merge the two.
- **It doesn't:** call the Skill tool with `factory:<name>`.

Either way the task contract still wins. Record every skill you called, by its bare name, in the outcome file's `skills`, in the order you called them; the workflow logs which version ran. Other target-repo skills are project knowledge: use them when they fit.

## Glossary and ADRs

- **Glossary:** add or update `GLOSSARY.md` entries only for concepts this change introduces or renames, through `domain-modeling`. Create the file only if you have an entry to put in it.
- **ADRs record decisions; you never make them.**
  - Write an ADR only when the decision is already made in the ticket thread, and cite that comment (or the ticket body).
  - An ADR-worthy decision the thread doesn't make → stop, giving the question and your recommended answer.
  - A ticket that contradicts an existing ADR in `docs/adr/` → stop, "premise is wrong", naming the ADR, unless the ticket explicitly asks to supersede it.
  - Check every ticket against `docs/adr/` in step 1, whatever its class; `domain-modeling` applies the same rules when it writes one.
  - A new or superseded ADR is a one-way door, declared in **Merge Danger**.

## Procedure

1. **Read** `.factory-run/ticket.md` (and `.factory-run/pr.md` when continuing a PR), the target repo's `CLAUDE.md`, and its standards file (`CODING_STANDARDS.md` or `CONTRIBUTING.md`), `GLOSSARY.md` and `docs/adr/` if they exist. Check the ticket against the Stop list: an open decision, a wrong premise (already done, or contradicting the code, another ticket or an ADR), too big for one PR, or something the runner lacks. Stop here if any holds.
2. **Classify** the ticket (see **Ticket classes and skills**). Class `none` → stop, "not actionable": say what the ticket would need to become actionable.
3. **Check the baseline.** Run the commands in `CLAUDE.md`'s `## Checks` section. If they fail before you change anything, stop, unless you are continuing a PR (see above).
4. **Build the change** through the class's skills, in order, following each one:
   - `bug-fix`: `diagnosing-bugs` finds the cause and leaves a red test or repro; `tdd` turns it green. Keep both outputs, before and after, for the Evidence.
   - `behaviour-change`: `tdd`, test-first. Keep an example input with its output before and after.
   - `refactor`: `codebase-design`. No behaviour changes; every assertion survives.
   - `docs-config`: edit directly.
   - plus `domain-modeling` for a new or renamed concept.

   A skill that ends in a `needs-human` outcome ends the run: write it as your outcome (step 8).
5. **Run `## Checks`** again. Every command must pass. If they won't go green without weakening a check, stop and say what you tried.
6. **Commit** on the current branch with a message that says what changed and why. `git status` must show no uncommitted changes outside `.factory-run/`.
7. **Write the PR body.** Call `pr` (see **Calling a skill**) for ticket `#<n>`, writing to `.factory-run/pr-body.md`. Tell it the ticket class so it shows the class's Evidence, which must be output this run produced. It must contain `Closes #<n>` and the headings `## Summary`, `## Evidence` and `## Merge Danger`, or the run fails. **Merge Danger** must declare, by name, any security-sensitive code, new dependency, breaking change, migration, and new or superseded ADR.
8. **Write the outcome file** `.factory-run/outcome.json`, as your final act, whatever happened:

   ```json
   {
     "outcome": "done",
     "class": "bug-fix",
     "new_concept": false,
     "skills": ["diagnosing-bugs", "tdd", "pr"],
     "unrelated": ["`parseDate` drops the time zone in src/dates.ts"]
   }
   ```

   or, when you stop:

   ```json
   {
     "outcome": "needs-human",
     "comment": "<question with your recommended answer, or give-up reason>",
     "class": "none",
     "skills": [],
     "unrelated": []
   }
   ```

   - `class` is required for `done`, and must be one of `bug-fix`, `behaviour-change`, `refactor` or `docs-config`; a `done` without one fails the run. On a stop, give the class if you got that far, else `none`.
   - `skills` lists every skill you called, by bare name; `unrelated` lists every unrelated issue you noticed, one line each. Use `[]` when there are none.

   Write `needs-human` whenever a step above or a skill tells you to stop, and leave any uncommitted work as it is: nothing is pushed.

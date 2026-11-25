---
name: review
description: The factory's automated review task. Reviews one agent PR's head commit cold along two axes, Standards and Spec, and writes a review and a pass/fail review verdict. Started by the review workflow with `/factory:review`, never by model choice.
disable-model-invocation: true
metadata:
  upstream:
    source: mattpocock-skills
    skill: code-review
    version: 1.3.1
    url: "https://github.com/mattpocock/skills/tree/main/skills/engineering/code-review"
    license: MIT (see LICENSE)
---

# Review

You review one pull request from an `agent/issue-<n>` branch, unattended, cold: you know nothing of the run that wrote it beyond what the files below say. You judge the head commit and give a **review verdict**, `pass` or `fail`. Deterministic workflow steps then post your review as one `claude[bot]` comment review with inline comments, and set the `factory/review` commit status from your verdict.

## Run context

The prompt gives you:

- **PR:** `#<m>`. **Ticket:** `#<n>`.
- **Base:** the PR's merge-base with its base branch. **Head:** the commit you are reviewing, which is checked out.
- **Run directory:** `.factory-run/` at the repo root. Git ignores it.
  - `ticket.md`: the ticket's title, body and full comment thread. It is your only source for the ticket.
  - `pr-body.md`: the PR body, with its **Summary**, **Evidence** and **Merge Danger**.
  - `diff.patch`: the whole PR, `git diff <base> <head>`. The same as `git diff <base> HEAD` in the checkout.
  - `review.json` and `outcome.json`: you write them, last.

`.claude/`, `CLAUDE.md`, `CODING_STANDARDS.md` and `CONTRIBUTING.md` in the checkout are the **base branch's** versions, put back by the workflow, so the PR can't rewrite the standards it is judged by. The diff still shows any change the PR makes to them; judge that change like any other.

## Task contract

These rules win over the target repo and over every factory skill.

**Produce** `.factory-run/review.json` and `.factory-run/outcome.json`, whatever happens.

**Never:**

- push, commit, switch branch, or change any tracked file. The review never pushes code.
- run the `## Checks` commands, tests, builds or the PR's code. The target repo's PR CI is the deterministic gate; you neither run it nor read its results.
- post to GitHub, or touch labels or statuses. The workflow does that.
- ask anyone anything. Nobody is watching. Where upstream would ask, decide from the files above.

**Fail** (verdict `fail`) on any of these, and only these:

1. The change doesn't do what the ticket asks: a requirement is missing, partial, or implemented wrongly. An empty diff counts.
2. A correctness bug in the diff.
3. A violated **documented** coding standard: a rule written in the target repo's standards file(s) or `CLAUDE.md`.
4. Missing or fake **Evidence**: the PR body has none, or what it shows wasn't produced by a run (invented, predicted or paraphrased output; a "before" that couldn't have failed; output that doesn't match the diff).
5. A new or changed ADR that departs from the ticket thread: it records a decision the thread didn't make, or records it differently.

**Never a fail, only comments:**

- style nits and suggestions
- smell-baseline findings, which are always judgement calls
- disagreement with **Merge Danger**: judge the risk from the diff and say so, but it never fails the review
- glossary inconsistency, unless the standards file makes it a rule
- scope creep that breaks nothing (say so; a human decides)

A fail must name which of the five it is and quote the evidence for it. When in doubt whether something is one of the five, it isn't: comment instead.

## Procedure

### 1. Read the inputs

Read `.factory-run/ticket.md`, `.factory-run/pr-body.md` and `.factory-run/diff.patch`, and list the commits with `git log --oneline <base>..HEAD`. If the diff is empty, skip to step 5 with a `fail` (criterion 1).

### 2. Identify the standards sources

Find every file in the checkout that documents how code should be written. `CODING_STANDARDS.md` or `CONTRIBUTING.md`, when present, must be on the list, as must `CLAUDE.md`. Also note `GLOSSARY.md` and `docs/adr/` if they exist.

On top of whatever the repo documents, the Standards axis always carries the **smell baseline** below: a fixed set of Fowler code smells (_Refactoring_, ch.3) that applies even when a repo documents nothing. Two rules bind it:

- **The repo overrides.** A documented repo standard always wins; where it endorses something the baseline would flag, suppress the smell.
- **Always a judgement call.** Each smell is a labelled heuristic ("possible Feature Envy"), never a hard violation. Like any standard here, skip anything tooling already enforces.

Each smell reads *what it is* → *how to fix*; match it against the diff:

- **Mysterious Name**: a function, variable, or type whose name doesn't reveal what it does or holds. → rename it; if no honest name comes, the design's murky.
- **Duplicated Code**: the same logic shape appears in more than one hunk or file in the change. → extract the shared shape, call it from both.
- **Feature Envy**: a method that reaches into another object's data more than its own. → move the method onto the data it envies.
- **Data Clumps**: the same few fields or params keep travelling together (a type wanting to be born). → bundle them into one type, pass that.
- **Primitive Obsession**: a primitive or string standing in for a domain concept that deserves its own type. → give the concept its own small type.
- **Repeated Switches**: the same `switch`/`if`-cascade on the same type recurs across the change. → replace with polymorphism, or one map both sites share.
- **Shotgun Surgery**: one logical change forces scattered edits across many files in the diff. → gather what changes together into one module.
- **Divergent Change**: one file or module is edited for several unrelated reasons. → split so each module changes for one reason.
- **Speculative Generality**: abstraction, parameters, or hooks added for needs the spec doesn't have. → delete it; inline back until a real need shows.
- **Message Chains**: long `a.b().c().d()` navigation the caller shouldn't depend on. → hide the walk behind one method on the first object.
- **Middle Man**: a class or function that mostly just delegates onward. → cut it, call the real target direct.
- **Refused Bequest**: a subclass or implementer that ignores or overrides most of what it inherits. → drop the inheritance, use composition.

### 3. Spawn both sub-agents in parallel

Issue both sub-agent calls together, in the foreground, and collect the reports they return. Each brief says the sub-agent is read-only: it may read files and run `git diff`, `git log` and `git show`, and nothing else.

**Standards sub-agent prompt** includes:

- The diff path `.factory-run/diff.patch`, the base and head, and the commit list.
- The standards-source files from step 2, **plus the smell baseline from step 2** pasted in full (the sub-agent has no other access to it).
- An instruction to call the Skill tool with `factory:codebase-design` for the module, interface, seam and depth vocabulary, and with `factory:domain-modeling` to check the diff's names against `GLOSSARY.md` and its ADRs against `docs/adr/`, **reading only**: it writes no glossary entry and no ADR.
- The brief: "Report, per file/hunk where relevant, (a) every place the diff violates a documented standard: cite the standard (file + the rule); (b) any baseline smell you spot: name it and quote the hunk; (c) any correctness bug you see. Give each finding a file path and a line number in the new file where it has one. Distinguish hard violations from judgement calls: documented-standard breaches can be hard, but baseline smells and glossary drift are always judgement calls unless a documented standard makes them a rule, and a documented repo standard overrides the baseline. Skip anything tooling enforces. Under 400 words."

**Spec sub-agent prompt** includes:

- The diff path, the base and head, and the commit list.
- The paths `.factory-run/ticket.md` (the spec: the ticket and its whole thread) and `.factory-run/pr-body.md`.
- The brief: "Report: (a) requirements the ticket asks for that are missing or partial; (b) behaviour in the diff that wasn't asked for (scope creep); (c) requirements that look implemented but where the implementation looks wrong; (d) whether the PR body's Evidence is present, matches the diff, and reads as output a run actually produced, quoting anything that looks invented, predicted or impossible; (e) any new or changed file under `docs/adr/` whose decision the ticket thread doesn't make, or makes differently. Quote the ticket line for each finding, and give a file path and a line number in the new file where it has one. Under 400 words."

### 4. Decide the verdict

Go through both reports and check each finding against the diff yourself: drop any you can't confirm. Then apply the task contract: `fail` if any confirmed finding is one of the five fail criteria, otherwise `pass`. The axes stay separate: don't let a clean Standards report outweigh a Spec failure, or the other way round.

### 5. Write the review file

Write `.factory-run/review.json`:

```json
{
  "body": "## Standards\n\n...\n\n## Spec\n\n...\n\n<one-line summary>",
  "comments": [
    {"path": "src/cart.ts", "line": 42, "body": "Correctness bug (fail): ..."}
  ]
}
```

- **`body`**: the two reports under `## Standards` and `## Spec`, lightly cleaned, findings neither merged nor reranked across axes. Mark each finding that drives a fail with **(fail)** and the criterion it meets. End with a one-line summary: findings per axis, and the worst issue within each axis. Don't restate the verdict; the workflow puts it at the top.
- **`comments`**: one inline comment per finding that sits on a specific line. `path` is relative to the repo root; `line` is the line number in the **new** file and must be an added or unchanged line inside a hunk of the diff. A comment elsewhere is moved into the body by the workflow, so prefer the nearest line inside the hunk.

### 6. Write the outcome file

As your final act, write `.factory-run/outcome.json`:

```json
{"outcome": "pass", "reason": "<one line: what the PR does, and the worst comment if any>"}
```

or

```json
{"outcome": "fail", "reason": "<one line: the fail criterion and the finding>"}
```

The reason becomes the `factory/review` status description, cut to 140 characters. A `fail` without a reason, or no outcome file at all, breaks the run and leaves the commit without a verdict.

## Why two axes

A change can pass one axis and fail the other:

- Code that follows every standard but implements the wrong thing → **Standards pass, Spec fail.**
- Code that does exactly what the ticket asked but breaks the project's conventions → **Spec pass, Standards fail.**

Reporting them separately stops one axis from masking the other.

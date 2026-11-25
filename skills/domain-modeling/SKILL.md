---
name: domain-modeling
description: Keep a target repo's domain model sharp in an unattended factory run. Called by a factory task skill at a fixed step when a change introduces or renames a concept; updates GLOSSARY.md and records ADRs for decisions already made in the ticket thread.
disable-model-invocation: true
metadata:
  upstream:
    source: mattpocock-skills
    skill: domain-modeling
    version: 1.3.1
    url: "https://github.com/mattpocock/skills/tree/main/skills/engineering/domain-modeling"
    license: MIT (see LICENSE)
---

# Domain Modeling

Keep the project's domain model sharp as the change is built: check terms, probe edge cases, and write the glossary and decisions down the moment they crystallise. (Merely *reading* `GLOSSARY.md` for vocabulary is not this skill: that's a one-line habit any skill can do. This skill is for when the change alters the model, not just consumes it.)

**Unattended.** This skill runs inside a factory run with nobody to ask. Where a person would normally be asked, it ends with a **`needs-human` outcome** instead: stop work and hand the calling task skill a question with your recommended answer, or a give-up reason that says what you tried. The task skill writes the outcome file. The task contract wins over this skill wherever they differ. The conversation upstream would have with a person is, here, the **ticket thread**: the ticket body and every comment on it.

## File structure

Most repos have a single context:

```
/
├── GLOSSARY.md
├── docs/
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

If a `GLOSSARY-MAP.md` exists at the root, the repo has multiple contexts. The map points to where each one lives:

```
/
├── GLOSSARY-MAP.md
├── docs/
│   └── adr/                          ← system-wide decisions
├── src/
│   ├── ordering/
│   │   ├── GLOSSARY.md
│   │   └── docs/adr/                 ← context-specific decisions
│   └── billing/
│       ├── GLOSSARY.md
│       └── docs/adr/
```

Create files lazily: only when you have something to write. If no `GLOSSARY.md` exists, create one when the first term is resolved. If no `docs/adr/` exists, create it when the first ADR is needed. Read `GLOSSARY.md` (or the map and the relevant context glossaries) before anything else.

## During the run

### Check the ticket against the glossary

When the ticket uses a term that conflicts with the existing language in `GLOSSARY.md`, work out which meaning it intends. If the thread and the code make it clear, use the glossary's term in code, tests and the PR. If they don't, and the two readings would build different things, stop with a `needs-human` outcome: "The glossary defines 'cancellation' as X, but the ticket seems to mean Y. Which is it? Recommended: X, because …"

### Sharpen fuzzy language

When the ticket uses vague or overloaded terms, pick the precise canonical term ("account" → the Customer or the User?). Choose it from the glossary and the code. If picking one is a product decision the thread doesn't make, stop with a `needs-human` outcome, giving the question and your recommended term.

### Probe concrete scenarios

Stress-test the change's concepts with specific scenarios that probe edge cases and the boundaries between concepts. Where the code or the thread settles a scenario, follow it. Where a scenario would change behaviour and nothing settles it, that's an open behaviour decision: stop with a `needs-human` outcome, giving the scenario, the question and your recommended answer.

### Cross-reference with code

When the ticket states how something works, check whether the code agrees. If it doesn't, the ticket's premise is wrong: stop with a `needs-human` outcome that names the contradiction ("The code cancels entire Orders, but the ticket says partial cancellation is possible. Which is right?").

### Update GLOSSARY.md inline

Add or update entries only for concepts this change introduces or renames. When a term is resolved, update `GLOSSARY.md` right there. Don't batch these up: capture them as they happen. Use the format in [GLOSSARY-FORMAT.md](./GLOSSARY-FORMAT.md).

`GLOSSARY.md` should be totally devoid of implementation details. Do not treat `GLOSSARY.md` as a spec, a scratch pad, or a repository for implementation decisions. It is a glossary and nothing else.

### ADRs: record decisions, never make them

A decision is **ADR-worthy** only when all three are true:

1. **Hard to reverse**: the cost of changing your mind later is meaningful
2. **Surprising without context**: a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off**: there were genuine alternatives and one was picked for specific reasons

If any of the three is missing, skip the ADR. For an ADR-worthy decision:

- **Already made in the ticket thread** → write the ADR, citing the comment (or ticket body) that made it. Use the format in [ADR-FORMAT.md](./ADR-FORMAT.md).
- **Not made in the thread** → don't make it yourself. Stop with a `needs-human` outcome, giving the question and your recommended answer.
- **The ticket contradicts an existing ADR** → stop with a `needs-human` outcome, "premise is wrong", naming the ADR. The exception: the ticket explicitly asks to supersede it. Then write the new ADR, cite the comment that asks for it, and mark the old one `superseded by ADR-NNNN`.

A new or superseded ADR is a **one-way door**: declare it under **Merge Danger** in the PR (see `factory:pr`).

---
name: tdd
description: Test-driven development for an unattended factory run. Called by a factory task skill at a fixed step to build a bug fix or behaviour change test-first.
disable-model-invocation: true
metadata:
  upstream:
    source: mattpocock-skills
    skill: tdd
    version: 1.3.1
    url: "https://github.com/mattpocock/skills/tree/main/skills/engineering/tdd"
    license: MIT (see LICENSE)
---

# Test-Driven Development

TDD is the red → green loop. This skill is the reference that makes that loop produce tests worth keeping: what a good test is, where tests go, the anti-patterns, and the rules of the loop. Every section applies on every cycle: consult them before and during the loop, not after.

**Unattended.** This skill runs inside a factory run with nobody to ask. Where a person would normally be asked, it ends with a **`needs-human` outcome** instead: stop work and hand the calling task skill a question with your recommended answer, or a give-up reason that says what you tried. The task skill writes the outcome file. The task contract wins over this skill wherever they differ.

When exploring the codebase, read `GLOSSARY.md` (if it exists) so test names and interface vocabulary match the project's domain language, and respect ADRs in the area you're touching.

## What a good test is

Tests verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't. A good test reads like a specification: "user can checkout with valid cart" tells you exactly what capability exists, and it survives refactors because it doesn't care about internal structure.

See [tests.md](tests.md) for examples and [mocking.md](mocking.md) for mocking guidelines.

## Seams: where tests go

A **seam** is the public boundary you test at: the interface where you observe behavior without reaching inside. Tests live at seams, never against internals.

**Test only at seams you have written down.** Before writing any test, write down the seams under test, each with a one-line note on what it catches and what it misses. Take them from the ticket's acceptance criteria and the existing public interfaces. You can't test everything, so fixing the seams up front is how testing effort lands on the critical paths and complex logic instead of every edge case. The seam list is part of the run's record: carry it into the PR's **Evidence**.

If you can't choose the seams without a decision the ticket doesn't make (for example, which public interface should exist at all), stop with a `needs-human` outcome, giving the question and your recommended seams.

When the shape of that interface is itself in question (how deep the module is, where the seam belongs, what the interface should expose), use `factory:codebase-design` for the vocabulary. It is the shared source of the module, interface, depth, seam, adapter, leverage and locality terms, and it is a reference to consult, not a session to run.

## Anti-patterns

- **Implementation-coupled**: mocks internal collaborators, tests private methods, or verifies through a side channel (querying the database instead of using the interface). The tell: the test breaks when you refactor but behavior hasn't changed.
- **Tautological**: the assertion recomputes the expected value the way the code does (`expect(add(a, b)).toBe(a + b)`, a snapshot derived by hand the same way, a constant asserted equal to itself), so it passes by construction and can never disagree with the code. Expected values must come from an independent source of truth: a known-good literal, a worked example, the spec.
- **Horizontal slicing**: writing all tests first, then all implementation. Bulk tests verify _imagined_ behavior: you test the _shape_ of things rather than user-facing behavior, the tests go insensitive to real changes, and you commit to test structure before understanding the implementation. Work in **vertical slices** instead: one test → one implementation → repeat, each test a **tracer bullet** that responds to what the last cycle taught you.

## Rules of the loop

- **Red before green.** Write the failing test first, then only enough code to pass it. Don't anticipate future tests or add speculative features.
- **One slice at a time.** One seam, one test, one minimal implementation per cycle.
- **Refactoring is not part of the loop.** It belongs to the automated review task (`factory:review`), not the red → green implementation cycle.
- **Never weaken a test to get green.** Skipping, deleting or loosening an existing test or check is a `needs-human` outcome, not a fix.

# Software Factory

The software factory that builds software across the owner's GitHub repositories. The core vocabulary (task, trigger, run, runner, ticket tracker, git host, orchestrator, observability platform) is defined in `.claude/skills/software-factory/SKILL.md`. This glossary adds only the terms specific to this factory.

## Language

**Factory repo**:
This repository: the single home of the factory's infrastructure and its generic task definitions.
_Avoid_: hub, control repo, meta repo

**Target repo**:
A repository the factory builds software in, after the repo has explicitly opted in. Each target repo is exactly one project, and it holds that project's own skills, domain language and automated checks.
_Avoid_: project repo, client repo, downstream repo, consumer repo

**Ticket state**:
Where a ticket stands in the factory's flow, exactly one at a time: Triage (not yet handed to the factory), Ready (handed to the factory), In progress (a run has claimed it), In review (its PR waits for review), Needs human (an agent handed it back on purpose, with a question or a give-up), Failed (a run broke while working on it), Done.
_Avoid_: status, stage, column

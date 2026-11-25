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
Where a ticket stands in the factory's flow, exactly one at a time: Triage (not yet handed to the factory), Ready (handed to the factory), In progress (a run has claimed it), In review (its PR waits for review), Needs human (handed back on purpose for a human to change something first: an agent's question or give-up, or a run the factory can't start or judge as things stand), Failed (a run broke while working on it), Done.
_Avoid_: status, stage, column

**Review verdict**:
An automated review's pass or fail on one commit of a PR. A fail sends the ticket back for rework, at most twice in a row before a human steps in.
_Avoid_: approval, check result, review status

**Task contract**:
The fixed rules of a task that a target repo cannot override: what the task must produce, when it must stop and hand back, what it must never touch, and the shape of what it hands on.
_Avoid_: prompt, task instructions, base rules

**Factory skill**:
A general-purpose skill the factory ships to every run, used at fixed points of a task. A target repo's own skill of the same name replaces it.
_Avoid_: base skill, shared skill, global skill

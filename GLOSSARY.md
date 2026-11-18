# Software Factory

The software factory that builds software across the owner's GitHub repositories. The core vocabulary (task, trigger, run, runner, ticket tracker, git host, orchestrator, observability platform) is defined in `.claude/skills/software-factory/SKILL.md`. This glossary adds only the terms specific to this factory.

## Language

**Factory repo**:
This repository: the single home of the factory's infrastructure and its generic task definitions.
_Avoid_: hub, control repo, meta repo

**Target repo**:
A repository the factory builds software in, after the repo has explicitly opted in. Each target repo is exactly one project, and it holds that project's own skills, domain language and automated checks.
_Avoid_: project repo, client repo, downstream repo, consumer repo

## The factory

- **Public repo, private targets.** Everything written here (issues, PRs, commits, docs) is public. Name a target repo only as "the test target repo" (or "a target repo") and cite its runs by run id: no repo name, URL, code or ticket text. `scripts/run-report` output stays in your terminal.
- **Spec:** `docs/factory-design.md`. Large: list its headings and read the section you need (§6–§8 cover the task instructions and the two tasks; §13 lists what's still unverified).
- **A task spans three layers that change together:** its skill (`skills/<task>/SKILL.md`), its workflow (`.github/workflows/<task>.yml`) and its scripts (`scripts/<task>/`), each script tested in `scripts/test/<name>.test.sh`. A new trigger also changes the stub every target repo copies, `templates/factory.yml`. Files the agent writes and a script reads (the outcome file, `ticket-classes`) are contracts: change both sides.
- **Checks:** `scripts/check` runs everything CI runs. Standards for review: `CODING_STANDARDS.md`.
- **What an agent did in a run:** `scripts/run-report <owner/repo> <run-id>`. The Actions log hides the agent's conversation.

## Agent skills

### Issue tracker

Issues live in GitHub Issues on this repo, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default labels: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` plus `docs/adr/` at the repo root. See `docs/agents/domain.md`.

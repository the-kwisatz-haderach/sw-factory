# Can a free GitHub Projects board track tickets across all target repos automatically?

Research for [#6](https://github.com/the-kwisatz-haderach/sw-factory/issues/6) (map [#2](https://github.com/the-kwisatz-haderach/sw-factory/issues/2)). Checked against docs.github.com on 2026-11-18.

## Short answer

**Partly.** One user-owned Projects (v2) board can hold issues and PRs from any number of repos, and it can carry a custom single-select status field such as `ready / in flight / waiting for human`. **But on GitHub Free the built-in auto-add covers only one repo**, because Free allows one auto-add workflow and each workflow filters a single repository. Cross-repo auto-collection therefore has to come from Actions (or the factory itself) calling the GraphQL API. Those calls need a **classic PAT** with `project` (+ `repo` for private repos). `GITHUB_TOKEN`, fine-grained PATs and GitHub Apps cannot write to a *user-owned* project.

## Findings

### 1. One board, many repos: yes

- "A project can contain a maximum of 50,000 items across both active views and the archive page." Items can come from different repositories, and the page says you can include items "from any organization."
  Source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/managing-items-in-your-project/adding-items-to-your-project
- You can add items by hand in bulk with "Add item from repository" (pick a repo, filter, select all) or from a repo's Issues list (select all, then **Projects**). Same source.

### 2. Built-in auto-add: one repo on Free

- Auto-add workflow limits per plan: **GitHub Free 1**, Pro/Team 5, Enterprise Cloud/Server 20.
- Each auto-add workflow targets **one repository**, chosen under "Filters". The page says "Each workflow can target a different repository."
- It works only going forward: "When you enable the auto-add workflow, existing items matching your criteria will not be added."
- The filter supports only `is:` (open, closed, merged, draft, issue, pr), `label:`, `reason:`, `assignee:`, `no:`, and negation.
  Source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/adding-items-automatically

**Implication:** on a free personal account the built-in auto-add can feed the board from one target repo only. Upgrading to Pro gives 5 repos. That's still a cap, and Pro is a paid plan.

**Uncertainty:** the docs don't say whether the plan that counts for a user-owned project is the owner's personal plan. I assume it is.

### 3. Other built-in workflows

- These two are on by default: item closed → Status `Done`, and PR merged → Status `Done`. Others can be turned on: item added → `Todo`, item reopened, status change → close the issue, and auto-archive.
- The docs give **no plan-based limit** on the non-auto-add workflows. Only auto-add is capped.
  Sources: https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-built-in-automations, https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/archiving-items-automatically
- Built-in workflows only write the built-in `Status` field, with fixed triggers. They cannot express factory states like "in flight" or "waiting for human". The factory has to set those itself (see 4).

### 4. A factory-owned status field updated through the API: yes

- Add the item with `addProjectV2ItemById(projectId, contentId)`. It is idempotent: "If you try to add an item that already exists, the existing item ID is returned instead."
- Set the status with `updateProjectV2ItemFieldValue` and `value: { singleSelectOptionId: ... }`. You need the field ID and option IDs, which you get by querying `fields` on the project. Adding and updating can't happen in one call, so use two mutations.
- `updateProjectV2ItemFieldValue` cannot change Assignees, Labels, Milestone or Repository.
- To find a user project's ID, query `user(login: "...") { projectV2(number: N) { id } }`.
  Source: https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects
- `gh` can do all of this (`gh project item-add`, `gh project item-edit`) once the token has the `project` scope (`gh auth login --scopes "project"`). Same source.

### 5. Which token can Actions use to write to a *user-owned* project?

| Token | Works for user-owned project? | Source |
|---|---|---|
| `GITHUB_TOKEN` | **No**: "scoped to the repository level and cannot access projects" | [automating-projects-using-actions](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/automating-projects-using-actions) |
| Classic PAT, `project` (+ `repo` for private repos) | **Yes**: "recommended for user projects" | same; [using-the-api-to-manage-projects](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects) |
| Fine-grained PAT | **No**: listed limitation: "access Projects owned by a user account" | [managing-your-personal-access-tokens](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) |
| GitHub App installation token | **No (inferred)**: Apps have only an *organization* "Projects" permission; no user-level Projects permission exists | [permissions-required-for-github-apps](https://docs.github.com/en/rest/authentication/permissions-required-for-github-apps) |

The third-party-hosted but GitHub-authored gh-aw reference agrees: user-owned projects need a classic PAT with `project` (+ `repo`). https://github.github.com/gh-aw/reference/auth-projects/

**Consequence:** the factory has to store a **classic PAT** as a secret, wherever the board-writing step runs. A classic PAT with `repo` is broad: it covers every repo the owner can access. Keep it out of agent-run steps (for example, in a separate job the model can't reach), and give it an expiry date.

### 6. Reacting to board changes: not available for user projects

- The `projects_v2_item` webhook is available only to **organization** webhooks. It is not listed for GitHub Apps or repositories. A user-owned board therefore can't trigger a workflow when someone drags a card.
  Source: https://docs.github.com/en/webhooks/webhook-events-and-payloads (`projects_v2_item` → Availability: `organization`)
- **Uncertainty:** I didn't separately check the Actions "events that trigger workflows" page. As far as I know it has no Projects v2 trigger at all. **Design rule:** the board is a *view* the factory writes to. The factory reads the source of truth from issue labels/events in each target repo, not from the board.

### 7. Ways to auto-collect from every target repo on Free

1. **A per-repo Actions workflow** on `issues: [opened, labeled]` / `pull_request: [opened]` that runs [`actions/add-to-project`](https://github.com/actions/add-to-project) with `project-url: https://github.com/users/<owner>/projects/<n>` and a classic PAT secret. The action supports `labeled` / `label-operator` filters. It only adds items and doesn't set fields. Its README covers fine-grained PATs only for *organization* projects. This fits naturally into the opt-in stub each target repo already carries.
2. **The factory sets it inline:** whenever the factory moves a ticket (picks it up, opens a PR, requests review), it calls `addProjectV2ItemById` (idempotent) and then `updateProjectV2ItemFieldValue`. The board can never be missing an item the factory touched.
3. **A scheduled sweep in the factory repo** (cron) that lists open issues/PRs across opted-in repos and adds and updates any that are missing. This catches anything that options 1 and 2 missed.
4. Use the single free built-in auto-add for one repo only (for example the factory repo itself). It doesn't scale.

Recommendation for the design: **2 + 3**. That keeps all board logic and the single PAT in the factory repo, with no per-repo secret. Add **1** only if hand-created issues need to show up immediately.

## Open uncertainties

- Plan attribution for user-owned project workflow limits (assumed to be the owner's personal plan).
- GitHub states that fine-grained PAT gaps "are not permanent" and are being closed. Recheck the limitations list before building, since a fine-grained PAT would narrow the blast radius.
- I didn't check API rate limits for frequent GraphQL updates. A solo factory running one job per repo should stay far below the 5,000 points/hour GraphQL limit, but I haven't verified that here.

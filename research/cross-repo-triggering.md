# How can a central factory repo trigger runs on, and write to, other repos for free?

Research for #5 (parent map #2). Researched on 2026-11-18 against docs.github.com and the `anthropics/claude-code-action` repo. Uncertain points are marked **[uncertain]**.

## Short answer

- **GitHub Actions never delivers one repo's issue or PR events to another repo's workflows.** A run starts in the target repo (a stub workflow), or the factory finds the work itself (dispatch or polling). The only push-style alternative is GitHub App webhooks, and those need a server you host, which breaks "free, Actions-only".
- **Recommended topology: a thin caller stub in each target repo that `uses:` a reusable workflow (`workflow_call`) in the factory repo, writing through a GitHub App token (the official Claude app, or an owner-made app).** The run, its minutes, its logs and its secrets all belong to the target repo, and the generic logic stays in the factory repo.
- **For writes, use a GitHub App rather than `GITHUB_TOKEN` or a PAT.** An app's pushes and PRs trigger CI normally, its actions show as `<app>[bot]` (not as the owner, who has to review the PR), and its tokens are short-lived and scoped per repo.
- **Constraint: a private factory repo can only serve private target repos.** If any target repo is public, the factory repo (or at least its reusable workflows) must be public.
- **A personal account has no account-wide Actions secrets.** Every target repo needs its own copy of `CLAUDE_CODE_OAUTH_TOKEN` (and of the app key, if you use your own app). Set them with `gh secret set -R`.

## The four mechanisms compared

"Target" means the target repo, "factory" means the factory repo, and "owner" means `the-kwisatz-haderach`.

| | **A. `workflow_call` (stub in target calls factory's reusable workflow)** | **B. `repository_dispatch` / `workflow_dispatch` (stub in target pokes factory)** | **C. GitHub App owned by the owner** | **D. Fine-grained PAT** |
|---|---|---|---|---|
| Role | Trigger and run topology | Trigger topology | Credential for writes (and for dispatch); webhooks optional | Credential for writes and dispatch |
| How target issue/PR events reach the factory | Natively: the stub listens to `issues`, `issue_comment`, `pull_request` in the target | The stub (or a scheduled poller) calls `POST /repos/{owner}/factory/dispatches` | Webhooks to a server **you host** (not free or Actions-only). Otherwise the app is only a token source for A or B, or for a cron poller in the factory | Not a trigger; only a token for B or for polling |
| Whose minutes are spent | Caller (target). "Billing for GitHub-hosted runners is always associated with the caller." | Factory | Wherever the workflow using it runs | Wherever the workflow using it runs |
| Where logs and run pages live | Target repo's Actions tab | Factory repo's Actions tab (public if factory is public, which **leaks private-target content**) | n/a | n/a |
| Author identity on commits, PRs, comments | `github-actions[bot]` with `GITHUB_TOKEN`; `claude[bot]` with the Claude app; `<slug>[bot]` with your own app | Whatever token the factory then uses for the target (cannot be the factory's `GITHUB_TOKEN`) | `<app-slug>[bot]` | **The owner.** The PR author is the reviewer, so automated review comments also look like yours |
| Do its pushes and PRs trigger further workflows? | With `GITHUB_TOKEN`: no, and PRs it opens get `pull_request` runs in an **approval-required** state. With an app token: yes | The dispatch itself always creates a run, even from `GITHUB_TOKEN`. Downstream writes depend on the token | Yes (only `GITHUB_TOKEN` is suppressed) | Yes |
| Permission scope | `GITHUB_TOKEN` is limited to the target repo. A called workflow can only keep or lower the caller's permissions | Dispatch needs `contents: write` on the factory (`actions: write` for `workflow_dispatch`) | Per-installation repo list, plus fine-grained permissions. Tokens can be narrowed further per run (`repositories`, `permission-*`) and expire after 1 hour | Selected repos (or all) and fine-grained permissions. Lasts until expiry (may be non-expiring). Tied to the owner |
| Setup effort | Low: one stub YAML per target, plus a factory "Access" setting if private | Medium: a stub plus a token secret per target, plus factory logic to check out and write to the target with a cross-repo token | Medium, once: register the app, install it on chosen repos, store the private key and client ID | Low: create one token and paste it into secrets. Renewal and rotation are manual |
| Secret storage on a personal account | Secrets come from the **caller** (target). Each target needs `CLAUDE_CODE_OAUTH_TOKEN`, plus your app key if you use your own app | Factory holds the model token and write credential once, but **each target holds a dispatch credential**, unless the factory polls instead | Private key is a repo secret wherever tokens are minted (each target under A, only the factory under B or polling) | Repo secret wherever it is used |
| Explicit per-repo opt-in | Stub file on the target's default branch (and app installed on that repo) | Stub plus secret in the target, or an allow-list in the factory if polling | **App installation repo list** ("Only select repositories") | PAT repo selection; edits to it are not visible from the target repo |

## Evidence

### 1. Events do not cross repos, and `GITHUB_TOKEN` cannot write elsewhere

- `issues` / `issue_comment` run "when an issue in the workflow's repository is created or modified", and only if "the workflow file exists on the default branch". The page has no mechanism for events from other repos. **[uncertain]** This is not stated as an explicit prohibition, but the docs describe no cross-repo event delivery. — https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows
- "The token's permissions are limited to the repository that contains your workflow." — https://docs.github.com/en/actions/concepts/security/github_token
- "the `GITHUB_TOKEN` can only access resources within the workflow's repository." Use a GitHub App for other repos. — https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/making-authenticated-api-requests-with-a-github-app-in-a-github-actions-workflow

### 2. The `GITHUB_TOKEN` no-retrigger rule (current wording)

- "events triggered by the `GITHUB_TOKEN` will not create a new workflow run", except that "`workflow_dispatch` and `repository_dispatch` events always create workflow runs". PRs opened, synchronized or reopened by `GITHUB_TOKEN` produce `pull_request` runs "in an **approval-required** state." To avoid this, "use a GitHub App installation access token or a personal access token instead of `GITHUB_TOKEN`". — https://docs.github.com/en/actions/concepts/security/github_token, https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow
  - **[uncertain]** The approval-required behaviour is newer than the long-standing "no runs at all" rule that many blog posts describe. Trust the docs pages above over secondary write-ups.
- Personal-account repo defaults: `GITHUB_TOKEN` is read-only for `contents` and `packages`, and "workflows are not allowed to create or approve pull requests" until **Allow GitHub Actions to create and approve pull requests** is enabled. — https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository

### 3. `workflow_call` (reusable workflows)

- "the `github` context is always associated with the caller workflow." "Billing for GitHub-hosted runners is always associated with the caller." `GITHUB_TOKEN` permissions "can be only downgraded (not elevated) by the called workflow." Limits: 10 nesting levels, and 50 unique reusable workflows per workflow file. — https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations
- Private sharing: a private repo's actions and reusable workflows can be made "Accessible from repositories owned by '<user>' user … **Access is allowed only from private repositories.**" A public target repo therefore cannot call a reusable workflow in a private factory repo. Any repo can use reusable workflows from public repositories. — https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository
- Secrets: "Secrets are not automatically passed to reusable workflows." Pass them explicitly, or use `secrets: inherit`, which the docs describe for callers "in the same organization or enterprise". **[uncertain]** The docs don't say whether `inherit` works between repos of the same personal account. Passing secrets explicitly works regardless. — https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets, https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows
- OIDC inside a reusable workflow: `repository` / `repository_owner` are the **caller's**, and `job_workflow_ref` names the factory workflow. So the Claude app's OIDC exchange (below) yields a token for the target repo, which is what we want. — https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-with-reusable-workflows

### 4. `repository_dispatch` / `workflow_dispatch`

- Runs on the default branch, and only if the workflow file exists there. `client_payload` allows at most 10 top-level properties and must be under 64 KB. `event_type` is at most 100 characters. — https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows, https://docs.github.com/en/rest/repos/repos#create-a-repository-dispatch-event
- Permissions: `POST /repos/{owner}/{repo}/dispatches` needs **Contents: write**. `POST …/actions/workflows/{id}/dispatches` needs **Actions: write**. — https://docs.github.com/en/rest/authentication/permissions-required-for-fine-grained-personal-access-tokens
- Consequence: the target's own `GITHUB_TOKEN` cannot dispatch to the factory, because that token is scoped to the target. Each target needs a stored credential (PAT or app key) with Contents: write **on the factory repo**, which is broad (it can also push code to the factory). The factory then needs a second, cross-repo credential to write back to the target.

### 5. GitHub App (owner-registered)

- Workflow use: register the app, store the client ID as a variable and the private key as a secret, install the app on the chosen repos, then mint a token with `actions/create-github-app-token`. — https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/making-authenticated-api-requests-with-a-github-app-in-a-github-actions-workflow
- `actions/create-github-app-token`: "If `owner` and `repositories` are empty, access will be scoped to only the current repository." `permission-<name>` narrows the token. Tokens expire after 1 hour and are revoked in the post step. For git commits, use `<app-slug>[bot]` with `<user-id>+<app-slug>[bot]@users.noreply.github.com`. — https://github.com/actions/create-github-app-token
- "API requests made by an app installation are attributed to the app." A token "cannot be granted permissions that the app was not granted." — https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/authenticating-as-a-github-app-installation
- Webhooks need hosting: apps "run persistently on a server or compute infrastructure that you provide". — https://docs.github.com/en/apps/creating-github-apps/about-creating-github-apps/deciding-when-to-build-a-github-app
- **Official Claude app** (`https://github.com/apps/claude`): by default `claude-code-action` exchanges an OIDC token (`id-token: write`) for a Claude-app token. Comments appear as `claude[bot]`, and git defaults to `bot_name: claude[bot]`. "Claude's GitHub app token is sandboxed to the current repository only. It cannot push to any other repositories." Passing `github_token` overrides this, for example with your own app's token. A custom app needs Contents, Issues and Pull requests set to Read & Write. — https://github.com/anthropics/claude-code-action/blob/main/docs/faq.md, https://github.com/anthropics/claude-code-action/blob/main/docs/setup.md, https://github.com/anthropics/claude-code-action/blob/main/action.yml
  - That sandboxing suits topology A, where the run is in the target repo. It **does not work for topology B**, where the run is in the factory: the token would be for the factory, not the target.
  - **[uncertain]** I found no explicit statement that `claude[bot]`'s pushes trigger CI. They should, because only `GITHUB_TOKEN` is suppressed, but verify with one test PR.
- The action only allows triggers from users with write access, and bots are disallowed unless listed in `allowed_bots`. That suits a single-owner setup. — https://github.com/anthropics/claude-code-action/blob/main/action.yml

### 6. Fine-grained PAT

- Fine-grained PATs can be limited to selected repos. "Infinite lifetimes are allowed" unless an org policy forbids them. A PAT acts with the owner's own identity and capabilities. GitHub advises using a GitHub App for long-lived integrations. — https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens
- Limitation that matters to map #2: fine-grained PATs **cannot access Projects owned by a user account**. The Projects automation guide recommends a **classic** PAT with `project` and `repo` scopes for user-owned projects. — same page, and https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/automating-projects-using-actions
  - **[uncertain]** GitHub Apps also seem unable to write to user-owned Projects (no account-level Projects permission). This comes only from secondary sources (e.g. https://dev.to/mfauveau/why-your-github-app-cant-see-your-personal-projects-4d39, https://github.github.io/gh-aw/reference/auth-projects). Confirm before designing the cross-repo board, which is likely a ticket of its own.

### 7. Secrets and minutes on a personal account

- Secrets exist at three levels: organization, repository and environment. Organization secrets need an organization. The docs mention no account-level Actions secrets for personal accounts, so plan for **per-repo secrets**. Limits: 100 repo secrets, 48 KB each. — https://docs.github.com/en/actions/concepts/security/secrets, https://docs.github.com/en/actions/reference/security/secrets, https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets
- Secrets are not passed to workflows triggered from forks, so a fork PR on a public target can't get the OAuth token. — use-secrets page above.
- Billing: "Standard GitHub-hosted runners in public repositories" are free. GitHub Free personal accounts get **$12/month of compute** for private repos, about 2,000 Linux 2-core minutes at $0.006/min. Compute is "charged to the repository owner". Without a payment method, usage stops once the included amount runs out (a natural hard cap). — https://docs.github.com/en/billing/managing-billing-for-your-products/managing-billing-for-github-actions/about-billing-for-github-actions
  - All repos have the same owner, so "whose minutes" doesn't change the pool. What matters is whether the repo **where the run executes** is public (free) or private (draws on the $12).

## Implications for the factory design (input to #7 / #8)

1. **Topology A (stub + `workflow_call`) is the natural fit.** It needs no server and no cross-repo credentials. Private-target logs stay private, and the stub file is a visible, versioned opt-in that sits next to the project's own `CLAUDE.md` and checks. The factory repo owns the generic logic, and targets pin it with `@main` or a tag.
2. **Credential for writes:** the official Claude app via OIDC needs no extra secret per repo, and installing it on a repo is a second, explicit opt-in gate. Your own app gives a custom bot name and narrower permissions, at the cost of one more secret per target. Avoid PATs for writes, because authorship becomes the owner.
3. **Factory visibility:** make it public if any target is public. That is fine, since the generic task definitions aren't secret and public repos run free. If everything is private, enable the factory's "Access" setting.
4. **Per-repo setup:** a stub workflow plus a `CLAUDE_CODE_OAUTH_TOKEN` repo secret, plus the app installation. This is scriptable with `gh secret set -R <repo>` and `gh api`.
5. **Topology B (dispatch) or a factory-side cron poller** is worth considering only if the logs or secrets must live in one place. It costs a cross-repo write credential and runs on the factory's minutes, and a public factory would publish private-target logs.

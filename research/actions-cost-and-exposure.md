# GitHub Actions: cost and exposure for a free personal account

Research for #4 (map #2). Sources read on 2026-11-18 from docs.github.com. GitHub notes that these numbers "may change", so check them again before you rely on them.

## TL;DR

- **Public repos:** standard GitHub-hosted runners are **free and unmetered**. **Private repos** draw from a monthly **$12 USD of included compute**, which is about **2,000 Linux 2-core minutes** at $0.006/min. Artifact storage is **500 MB**, shared with Packages. Cache is **10 GB per repo**.
- **At the limit:** with **no payment method on file**, usage is **blocked** when the $12 runs out. That is a hard stop at $0. With a payment method, overage is billed unless a **budget with "Stop usage when budget limit is reached"** caps it.
- **Billing for reusable workflows** always goes to the **caller**. A private target repo calling a reusable workflow in the public factory repo spends the target repo owner's private-repo quota. Here that is the same account. Hosting the workflow in a public repo does not make the run free.
- **Public repo logs** can be read by **any logged-in GitHub user**. Artifacts can be downloaded by anyone with read access, which on a public repo is everyone. A job that *runs in the public factory repo* and handles private code or prompts **can leak them into public logs**. A job that runs in the private target repo (caller) and only *uses* a reusable workflow from the factory repo keeps its logs private.
- **Limits:** a job on a GitHub-hosted runner can run at most **6 h**. `timeout-minutes` defaults to 360. GitHub Free allows **20 concurrent jobs**. A concurrency group runs **1** at a time. By default it keeps one pending run and cancels older pending ones; `queue: max` keeps up to **100** pending.

## 1. Quotas and pricing (GitHub Free, personal account)

Source: [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions), [Actions limits](https://docs.github.com/en/actions/reference/limits), [Actions runner pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing).

| Item | GitHub Free |
|---|---|
| Included compute (private repos) | **$12 USD / month**, resets each billing cycle |
| Artifact storage | **500 MB**, shared with GitHub Packages |
| Cache storage | **10 GB per repository** |
| Public repos, standard hosted runners | **Free**, does not draw from the $12 |
| Self-hosted runners | **Free**, does not draw from the $12 |
| Larger runners | Billed even in public repos. Not usable on Free without a payment method |

- The included amount is **money, not minutes**: "The included compute usage is expressed as a monetary amount, not a fixed number of minutes". The per-minute rates are Linux 2-core x64 **$0.006**, Linux 1-core (`actions_linux_slim`) **$0.002**, Linux arm64 2-core **$0.005**, Windows **$0.010**, macOS **$0.062**. $12 therefore covers about 2,000 Linux 2-core minutes, about 6,000 Linux 1-core minutes, or about 190 macOS minutes. These are my arithmetic, not quoted.
- **Each job's time is rounded up to the next whole minute** ([runner pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing)). Many short jobs therefore cost more than their wall-clock time suggests.
- Failed and re-run jobs count: "fails after 5 minutes ... re-run ... the total cost is based on 15 minutes."
- Logs and job summaries **do not** count against artifact storage.
- Charges go to the **repository owner**, not to whoever triggered the run. "Anyone with write access to a repository can run actions. Any costs ... are billed to the repository owner."
- Overage storage rates are $0.25/GB-month for artifacts and Packages, and $0.07/GB-month for cache. Cache overage is billed only if you raise the repo cache limit above 10 GB.
- The included usage is shared with **Copilot code review** and **cloud sandbox** compute on private repos. Agent sessions that run on Actions therefore compete for the same $12.
- **Pricing history:** hosted-runner rates were cut on 2026-01-01. A planned $0.002/min "platform charge" on self-hosted runners (announced 2025-12-16, due 2026-03-01) was **postponed** ([changelog](https://github.blog/changelog/2025-12-16-coming-soon-simpler-pricing-and-a-better-experience-for-github-actions/), [resources.github.com](https://resources.github.com/actions/2026-pricing-changes-for-github-actions/)). The current billing doc still says self-hosted runners are free. **Uncertain:** whether GitHub will bring that charge back.

## 2. What happens at the limit; enforcing $0

Sources: [Actions billing: "Using more than your included compute usage"](https://docs.github.com/en/billing/concepts/product-billing/github-actions#using-more-than-your-included-compute-usage), [Budgets and alerts](https://docs.github.com/en/billing/concepts/budgets-and-alerts), [Set up budgets](https://docs.github.com/en/billing/how-tos/set-up-budgets).

- **No payment method on file:** "usage is blocked once you consume the included compute usage." This is the simplest **guaranteed $0**: never add a card. Private-repo jobs stop running until the next cycle.
- **Payment method on file:** extra usage is billed. You can create an **Actions budget** with **"Stop usage when budget limit is reached"**. For metered products such as Actions, "you can set budgets to prevent usage once the budget threshold is reached". Without that checkbox, "usage **will not** be stopped", and you only get an email.
- Caveat: a budget "applies only to metered usage from the date of its creation onwards", so "you may exceed your budget in the first billing cycle" after you create it.
- Caveat: deleting a budget "may remove any limits on spending".
- Alerts: **included-usage** emails at 90% and 100% of the free allowance, which you can opt into or out of. **Budget** alerts at 75%, 90% and 100%.
- **Uncertain:** the docs no longer say whether a new personal account with a card gets a **$0 Actions budget by default**. The old "spending limit defaults to $0" wording is gone. Check under Settings > Billing > Budgets and alerts. Creating an explicit $0 stop-usage budget for Actions is cheap insurance.
- **Inferred, not stated:** public-repo usage on standard runners never draws from the quota, so it should keep running after private usage is blocked.

## 3. Who can read logs, and the risk of leaking private code or prompts

Sources: [Using workflow run logs](https://docs.github.com/en/actions/how-tos/monitor-workflows/use-workflow-run-logs), [Secrets concepts](https://docs.github.com/en/actions/concepts/security/secrets), [Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use), [Repo Actions settings: retention](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository#configuring-the-retention-period-for-checks-workflow-runs-commit-statuses-artifacts-and-logs-in-your-repository).

- Viewing, searching and downloading logs and artifacts needs **read access** to the repo. "You must be logged in to a GitHub account to view workflow run information, including for public repositories." On a **public** repo, that means **any signed-in GitHub user can read every run log and download artifacts**.
- Default retention is **90 days**. On public repos you can set 1–90 days; on private repos, 1–400 days. From 2026-10-01 retention also applies to checks, workflow runs and commit statuses ([changelog](https://github.blog/changelog/2026-07-17-actions-retention-will-cover-checks-workflow-runs-and-statuses/)). Users with write access can delete individual logs.
- **Secret redaction is best effort.** Registered secrets are masked, but "this redaction is not guaranteed". It works only on exact matches in the current job, and it breaks on structured or transformed values. Anything that is not a secret, such as **source code, diffs, prompts, model transcripts or tool output, is printed verbatim**. Use `::add-mask::` for values that are generated at run time.

**The answer depends on where the job runs:**

| Topology | Where logs live | Leak risk |
|---|---|---|
| Private target repo has a workflow that calls `owner/factory/.github/workflows/x.yml@ref` (reusable workflow) | In the **private target repo's** run | **None from logs.** Only the reusable workflow's YAML is public, and it already is |
| Workflow **in the public factory repo** checks out or reads a private target repo with a token and runs the agent there | In the **public factory repo's** run | **High.** Agent output, diffs, file contents and prompts echoed to stdout, plus any uploaded artifacts, are world-readable |
| Factory repo only dispatches (for example `gh workflow run` / `repository_dispatch` into the target repo) and logs IDs only | Agent logs in the private repo, the dispatch log in the public repo | Low, provided the dispatcher prints nothing private (repo names and issue titles may still show) |

Also: the generic prompts that live in a public factory repo are **public by definition**, whether or not they appear in logs.

## 4. Reusable workflows: billing and access

Source: [Reusing workflow configurations (reference)](https://docs.github.com/en/actions/reference/workflows-and-actions/reusing-workflow-configurations), [Reuse workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows), [Workflow syntax: secrets.inherit](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idsecretsinherit).

- "**Billing for GitHub-hosted runners is always associated with the caller.** ... The caller workflow cannot use GitHub-hosted runners from the called repository." A private caller therefore pays private-repo rates even though the called workflow is public.
- "The `github` context is always associated with the caller workflow." `actions/checkout` in the called workflow checks out the **caller** repo. The run appears in the caller repo's Actions tab.
- Access by visibility: a **private** caller can use **private and public** reusable workflows. A **public** caller can use **public** ones only. A private factory repo would need its Actions **Access** setting changed to "Accessible from repositories owned by the user", and that "Access is allowed only from private repositories".
- Limits: up to 10 levels of nesting, and at most **50 unique reusable workflows** per top-level workflow file. Permissions can only be kept or reduced down the chain.
- Secrets: the caller must pass them explicitly or use `secrets: inherit`. The docs describe `inherit` as working "within the same organization, or across organizations within the same enterprise". **Uncertain** whether that covers repos owned by the same *personal* account, so plan to pass named secrets explicitly (for example the Claude OAuth token). Secrets pass only one level down.
- Gotcha: a called workflow sees the *caller's* name in `${{ github.workflow }}`. If caller and callee use the same `concurrency.group` with `cancel-in-progress`, the caller cancels itself.

## 5. Concurrency and timeouts

Sources: [Actions limits](https://docs.github.com/en/actions/reference/limits), [Control concurrency](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency), [Workflow syntax: timeout-minutes](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax#jobsjob_idtimeout-minutes).

- **Job execution limit:** 6 h on GitHub-hosted runners and 5 days on self-hosted. `jobs.<id>.timeout-minutes` defaults to **360**. `steps[*].timeout-minutes` can be at most 360.
- **Workflow run limit:** 35 days, including waiting and approval time. Self-hosted jobs are cancelled after 24 h in the queue.
- `GITHUB_TOKEN` expires when the job ends, or after 24 h at most. Its REST rate limit is 1,000 requests/hour per repo. A PAT gets 5,000/hour.
- **Account concurrency (Free):** 20 concurrent jobs on standard runners, of which at most 5 can be macOS. This is per account, across all repos.
- **Concurrency groups:** `concurrency: { group: ... }` at workflow or job level allows at most one running member. By default (`queue: single`) a new pending run **cancels the existing pending one**. `queue: max` holds up to **100** pending runs in FIFO order (best effort), and cannot be combined with `cancel-in-progress: true`. Group names are case-insensitive, and **groups are scoped per repository** ("in the same concurrency group in the repository"). You cannot get an account-wide "one at a time" from `concurrency` alone.
- For "one run at a time per target repo", use a group such as `factory-${{ github.repository }}` in the caller with `queue: max`. The default would silently drop queued tickets.
- Other limits: matrix 256 jobs, 50 re-runs per run, 500 KB per workflow file.

## Implications for the factory design (not decisions)

1. Run agent jobs **in the private target repo** (caller) by using a reusable workflow from the public factory repo. Logs then stay private, and the cost is the shared $12 pool.
2. For a hard $0 cap, keep **no payment method on the account**. If one is ever added, create an Actions budget with stop-usage first.
3. Budget for roughly **2,000 Linux minutes/month across all private target repos**, with each job rounded up to a whole minute. Long agent sessions eat into this quickly. Public target repos are free.
4. Never run anything in the public factory repo that prints target-repo content. Treat factory-repo logs and artifacts as public.

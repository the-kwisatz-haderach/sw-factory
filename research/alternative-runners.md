# Alternative runners to GitHub-hosted Actions, at low cost

Research for [#14](https://github.com/the-kwisatz-haderach/sw-factory/issues/14), part of map [#2](https://github.com/the-kwisatz-haderach/sw-factory/issues/2). Researched 2026-11-18 against vendor pricing and docs pages and Anthropic's docs and terms. Prices and previews change fast, so re-check before building.

**Already settled elsewhere, not redone here:** Actions quotas, hard-$0 behaviour and log exposure ([#4](https://github.com/the-kwisatz-haderach/sw-factory/issues/4)); the subscription token in CI, its limits and the Consumer Terms gray zone ([#3](https://github.com/the-kwisatz-haderach/sw-factory/issues/3)); stub workflow plus reusable workflow plus GitHub App for cross-repo writes ([#5](https://github.com/the-kwisatz-haderach/sw-factory/issues/5)). Orchestrators are researched in parallel in #15. Each runner below just names the orchestrator it needs.

**Typical run** used for the cost estimates: 15-30 min, 2 vCPU, 4 GB RAM. Most of that time is spent waiting on the model.

## Short answer

- Most alternatives fail on one of the two hard constraints. **No subscription:** Claude Managed Agents needs an API key, Copilot and Codex need their own vendor plans, and Claude Code self-hosted environments need Team or Enterprise. **No hard cap:** Fly.io documents none, and Daytona's cap is undocumented.
- **Baseline: GitHub-hosted Actions stays the default.** Public repos run free. Private repos get about 2,000 min/month (#4), roughly 65-130 runs at 15-30 min each. That pool is shared across every private repo, with a hard $0 stop when no card is on file.
- **Claude Code cloud sessions with scheduled tasks** (formerly routines) is the strongest complement. Compute costs nothing extra: "there's no separate charge for the cloud VM", and runs only draw on the subscription. It is Anthropic's own surface, so the terms question goes away. It is triggered by GitHub issue/PR events or by an HTTP `/fire` call. Downsides: research preview, PRs and comments appear as the **owner's** GitHub user, events over the hourly cap are **dropped**, and there is no per-repo concurrency group.
- **An ephemeral self-hosted Actions runner** on a small VPS (Hetzner, from €5.49/month, hard-capped by the provider) removes the private-repo minute ceiling. The orchestrator stays the same: the stub workflow just says `runs-on: self-hosted`. Self-hosted minutes are free per GitHub's billing docs. Cost: you build disposability yourself (`--ephemeral` plus a fresh container) and keep the box patched.
- **MicroVM APIs** (Vercel Sandbox, E2B, Modal, Daytona) cost about $0.04-0.12 per 30-min run, and Claude Code runs there with the subscription token. But they need an orchestrator that #15 hasn't chosen yet. Only **Vercel Hobby** is free with a hard pause. E2B gives a one-time $100. Modal gives $30/month with a spend limit but needs a card.

## Comparison table

Cost per run assumes 2 vCPU / 4 GB for 30 min unless noted. "Sub token" asks two things: can Claude Code run there on the owner's subscription, and is that allowed.

| Runner | Type | Free tier / price per 15-30 min run | Hard cap? | Disposable? | Sub token: tech / terms | How a run starts (orchestrator) | Logs | Setup / upkeep |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **GitHub-hosted Actions** (baseline) | CI runner | Public: free. Private: ~2,000 min/mo shared, then $0.006/min (~$0.09-0.18/run) | Yes, $0 with no card (#4) | Yes, fresh VM per job | Yes / documented for CI, gray zone (#3) | Workflow trigger in the target's stub (Actions is the orchestrator) | Target repo's run page; private for private repos | Low |
| **Self-hosted Actions runner on a VPS** | CI runner, own machine | Actions minutes free; VPS from €5.49/mo (1 vCPU/1 GB) or €9.99/mo (1 vCPU/2 GB) | Yes, VPS bill "will never exceed its monthly price cap" | Only if you make it so (`--ephemeral` + container per job) | Yes / same as baseline | Same stub workflow, `runs-on: [self-hosted, ...]` | Target's run page (same as baseline) | Medium: image, runner registration, OS patching |
| **Claude Code cloud + scheduled tasks** | Bundled agent platform | $0 compute; counts against subscription limits | Yes; no usage credits means runs are rejected at the limit | Fresh VM per session; setup cache kept ~7 days; transcript kept | Native / squarely "ordinary use of ... native Anthropic applications" | GitHub event trigger (issue, PR, release) via Claude GitHub App, HTTP `/fire` with bearer token, cron, or `claude --cloud` | claude.ai/code, private by default (shareable as Public) | Low setup; preview API may change |
| **Vercel Sandbox (Hobby)** | MicroVM API | Free: 5 active-CPU h, 420 GB-h memory, 5,000 creations/mo; ~$0.055/run on Pro | Yes: Hobby pauses creation, "will not be charged" | Yes; 45-min max session on Hobby | Yes (CLI + `CLAUDE_CODE_OAUTH_TOKEN`) / allowed as own use of the unmodified binary, same gray zone as #3 | SDK `Sandbox.create()` from an orchestrator (#15) | Whatever the orchestrator captures; sandbox stdout is lost on teardown | Medium |
| **E2B (Hobby)** | MicroVM API | One-time $100 credit; ~$0.08/run (~1,200 runs) | Spending limits in console; blocked when credits run out with no card | Yes; 1-h max session on Hobby | Same as Vercel | SDK create from an orchestrator | Same as Vercel | Medium |
| **Modal Sandboxes (Starter)** | MicroVM API | $30/mo compute credit; ~$0.12/run at 1 core + 4 GiB | Workspace budget + spend limit; card required | Yes; default 5-min timeout, max 24 h | Same as Vercel | SDK `Sandbox.create()` from an orchestrator | Same as Vercel | Medium |
| **Daytona** | MicroVM API | $200 trial credit, "no credit card required"; ~$0.08/run | Prepaid wallet with optional auto top-up; behaviour at $0 **undocumented** | Yes with `ephemeral` / auto-delete 0 | Same as Vercel | SDK create from an orchestrator | Same as Vercel | Medium |
| **Fly Machines** | Own VPS / containers | No free tier ($1 7-day trial); ~$0.01-0.02/run | **No** spending cap documented | Yes if the machine is destroyed per run | Same as Vercel | Machines API call from an orchestrator | Fly logs, private | Medium |
| **Claude Code self-hosted environments** | Bring-your-own worker | Your machines + subscription usage | n/a | Your job (runner exits per session at `--drain-grace-sec 0`) | **Team/Enterprise only** (public beta) | Anthropic queue; runner polls | claude.ai | High; **ineligible on Pro/Max** |
| **Claude Managed Agents** | Bundled agent platform (API) | Tokens + $0.08/session-hour | Session budgets | Yes | **No: needs an API key** | API session create | Console / API | Low; **violates subscription constraint** |
| **Copilot coding agent (Claude agent via Agent HQ)** | Bundled agent platform | Copilot Pro $10/mo with 1,500 AI credits; not on Copilot Free | Not verified | Yes (runs on an Actions runner) | **No: Copilot billing, not the Claude subscription** | Assign issue to agent | GitHub | Low; **separate subscription** |
| **Codex cloud** | Bundled agent platform | ChatGPT plan | — | Yes | **No: not Claude** | Codex UI / GitHub | OpenAI | **Out of scope** |

## Per runner

### GitHub-hosted Actions (baseline)

Covered by #4 and #5; restated only for comparison. A Linux 2-core minute costs $0.006 ([GitHub runner pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing)). Private repos get about 2,000 free minutes a month, shared across the account, so 30-min implementer runs exhaust them at roughly 65 runs. That ceiling is the main reason to look for a complement.

### Self-hosted GitHub Actions runner (ephemeral) on a cheap VPS

- **Price:** GitHub lists self-hosted runner usage as usage that "remains free independently and does not reduce the included compute usage" ([GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)). The $0.002/min self-hosted platform charge announced in December 2025 was postponed and hasn't come back as of this page ([The Register, 2025-12-17](https://www.theregister.com/2025/12/17/github_charge_dev_own_hardware/)). It could return, so watch the changelog.
- **Machine:** Hetzner Regular Performance CPX02 (1 vCPU, 1 GB, 20 GB) costs €5.49/month max or €0.0088/h. CPX12 (1 vCPU, 2 GB, 40 GB) costs €9.99/month max or €0.016/h. Both prices are for HEL1 excluding VAT, and both were marked "currently unavailable" on the day checked. Hetzner states "Your server's bill will never exceed its monthly price cap" ([Hetzner Regular Performance](https://www.hetzner.com/cloud/regular-performance/)), which gives a hard cap by construction. A 1 GB box is tight for Claude Code plus a test suite; **2 GB or more is the practical floor (unverified, measure it)**. Any spare always-on machine the owner already has works too, at $0.
- **Disposability:** your job. Register the runner with `--ephemeral` (one job, then deregister) and run each job in a fresh container, or use Actions Runner Controller on Kubernetes (from the RUNNERS.md survey). Note that the `add-runners` doc page fetched here does not itself mention `--ephemeral`.
- **Security:** GitHub recommends self-hosted runners "only ... with private repositories", because PRs from forks can run code on the machine ([Adding self-hosted runners](https://docs.github.com/en/actions/how-tos/manage-runners/self-hosted-runners/add-runners)). So use it for **private targets only**, which is exactly where the minute ceiling bites.
- **Subscription token:** identical to the baseline. The stub passes `CLAUDE_CODE_OAUTH_TOKEN` to the job.
- **Orchestrator:** unchanged. It is the same stub plus reusable workflow; only `runs-on` changes, and it can be chosen per task (for example, review on hosted, implementer on self-hosted).
- **Logs:** the target repo's run page, as today.
- **Effort:** build and maintain a runner image, register the runner, patch the OS, and keep the token secret on the box. Personal accounts register runners per repo, not per account. **Unverified:** the exact per-repo registration overhead with many target repos.

### Claude Code cloud sessions + cloud scheduled tasks (bundled agent platform)

- **Price:** cloud sessions are available on Pro, Max, Ultra and Team. Each one "counts toward your plan's usage limits ... and there's no separate charge for the cloud VM" ([Claude Code in the cloud](https://code.claude.com/docs/en/claude-code-on-the-web)). Scheduled tasks "draw down subscription usage the same way interactive sessions do" ([Scheduled tasks](https://code.claude.com/docs/en/routines)).
- **Hard cap:** "Without usage credits, additional runs are rejected until your usage window resets" (same page). Keep usage credits off, as #3 already recommends. Hourly trigger limits: 100 scheduled runs per hour per account; 30 API fires or Run-now per hour per task; 100 API fires per hour per account. "None of these hourly limits has overage." GitHub webhook events have per-task and per-account hourly caps, and "Events beyond the limit are dropped until the window resets", so a burst can silently lose a trigger.
- **Machine:** a "fresh virtual machine (VM) running Ubuntu 24.04 on x86_64" per session, with 4 vCPUs, 16 GB RAM and 30 GB disk ([Cloud environments](https://code.claude.com/docs/en/cloud-environments)). The VM is larger than the hosted Actions runner.
- **Disposability:** a fresh VM and a fresh clone every session. Two things persist across runs. One is the **environment cache**: a filesystem snapshot of the setup script's output, rebuilt about every 7 days. That is a cache, which the design allows. The other is the **session transcript** on claude.ai, which can be reopened on a new VM. Neither carries code state between tickets.
- **Subscription and terms:** this is Anthropic's own surface, so it uses the subscription natively. Cloud sessions "always use your subscription credentials", and an `ANTHROPIC_API_KEY` set in the environment doesn't override them ([Authentication](https://code.claude.com/docs/en/authentication)). That removes #3's API-key-leak risk on this path. It is the clearest fit for "ordinary use of Claude Code and other native Anthropic applications" ([Legal and compliance](https://code.claude.com/docs/en/legal-and-compliance)).
- **How a run starts (orchestrator):** each task has one or more triggers:
  - a **GitHub event** on a selected repo: PR, Release or Issue, with actions such as `labeled` and filters on author, labels, draft and branch. This needs the Claude GitHub App installed on that repo.
  - an **API trigger**: `POST .../fire` with a per-task bearer token and the `experimental-cc-routine-2026-04-01` beta header, plus an optional free-text `text` that arrives labelled as untrusted.
  - a **schedule**.
  - `claude --cloud "<task>"` from any CLI signed in to the account.

  So the platform can be its own orchestrator for "issue labelled `ready-for-agent`", or an Actions stub can `curl` the `/fire` endpoint. The second option keeps the opt-in gate and the throttle in Actions and costs about 1 Actions minute per run. Each event starts a new session: "two PR updates produce two independent sessions". There is **no built-in concurrency group per repo**, so the "one run at a time per target repo" brake must live elsewhere (a label lock, or an Actions concurrency group in front of `/fire`).
- **Identity (important):** "Commits and pull requests carry your GitHub user", and auto-fix replies are "posted using your GitHub account" ([Scheduled tasks](https://code.claude.com/docs/en/routines); [Claude Code in the cloud](https://code.claude.com/docs/en/claude-code-on-the-web)). This contradicts #5's "writes go through a GitHub App, not as the owner" decision. A PR authored by the owner can't be approved by the owner on GitHub, and owner-authored commits look like human work.
- **Logs:** the session transcript at claude.ai/code. It is private by default; on Pro, Max or Ultra it can be toggled to **Public**, which is visible to any logged-in claude.ai user. It is not in the target repo.
- **Network:** default "Limited" egress allowlist with package managers allowed; GitHub goes through a proxy, and credentials never enter the VM.
- **Status:** scheduled tasks are a **research preview**: "Behavior, limits, and the API surface may change." The `/fire` endpoint is beta-header versioned.
- **Effort:** low. Install the Claude GitHub App on each opted-in repo and create a task per repo or per job, either in the web UI or with `/schedule`. Tasks belong to the individual account; the API trigger can only be created on the web.

### Claude Code self-hosted environments (bring-your-own worker): ineligible

"Self-hosted environments are in public beta on Team and Enterprise plans" ([Self-hosted environments](https://code.claude.com/docs/en/self-hosted-environments)). The owner's Max plan can't use them. If the owner ever moved to Team, this would combine Anthropic's queue and triggers with the owner's VPS, using an ephemeral runner that exits after its sessions at `--drain-grace-sec 0`. Sessions use "your organization's Claude Code usage".

### MicroVM APIs (Vercel Sandbox, E2B, Modal, Daytona)

Shared traits:

- **Orchestrator:** something must call the SDK's create function, exec Claude Code, and kill the sandbox. Options: a server or queue chosen in #15, or the Actions stub itself. If the stub stays attached while the sandbox works, it burns the same Actions minutes, which defeats the purpose in private repos. A fire-and-forget pattern also works: a ~1-min job creates the sandbox with a hard timeout and passes it a short-lived GitHub App installation token, and the sandbox pushes and opens the PR itself. That loses the Actions run page as the log, so ship logs somewhere private.
- **Subscription token:** technically the Claude Code CLI reads `CLAUDE_CODE_OAUTH_TOKEN` anywhere, and Anthropic documents it for "CI pipelines and scripts" ([Authentication](https://code.claude.com/docs/en/authentication)). On terms, Anthropic's restrictions target third-party developers who "route requests through Free, Pro, Max, or Ultra plan credentials on behalf of their users". They don't prevent "an end user signing in to the unmodified Claude Code binary with their own Claude subscription, including where a platform hosts Claude Code" ([Legal and compliance](https://code.claude.com/docs/en/legal-and-compliance)). The owner running their own token in their own sandbox is therefore the same gray zone as #3, and no worse. **Do not** use the Agent SDK with the subscription token: Anthropic directs Agent SDK builders to API keys (same page). The token has to be stored with the orchestrator or the sandbox provider's secrets.
- **Logs:** provider dashboards (private to the account) plus whatever the orchestrator captures. Nothing lands on GitHub unless you post it.

| Provider | Free tier | Price | Cap | Max run | Notes |
| --- | --- | --- | --- | --- | --- |
| Vercel Sandbox | Hobby: 5 active-CPU h, 420 GB-h memory, 5,000 creations, 20 GB transfer per month | Pro: $0.128/active-CPU h, $0.0212/GB-h | Hobby: creation "paused", "will not be charged"; Pro: Spend Management | 45 min Hobby, 24 h Pro | Waiting on the model is not billed as CPU, only as memory. At 10% CPU utilisation a 30-min 2 vCPU/4 GB run uses 0.1 CPU-h + 2 GB-h, so **~50 runs/month free (CPU-bound; estimate)**. ([Vercel Sandbox pricing](https://vercel.com/docs/vercel-sandbox/pricing)) **Unverified here:** whether Hobby's non-commercial fair-use terms apply to this use. |
| E2B | Hobby: $100 **one-time**; no card to start | $0.000014/vCPU-s, $0.0000045/GiB-s → ~$0.08 per 30 min | Spending limits in console; projects blocked when credits run out with no payment method | 1 h Hobby, 24 h Pro ($150/mo) | 10 concurrent on Hobby. ([E2B pricing](https://e2b.dev/pricing), [E2B billing](https://docs.e2b.dev/billing)) |
| Modal | Starter: $30/month compute | $0.00003942/core-s, $0.00000667/GiB-s → ~$0.12 per 30 min (1 core, 4 GiB) | Workspace budget and spend limit: "Modal stops workloads that would incur additional out-of-pocket charges" | Default 5 min, up to 24 h | Payment method required. ~250 runs/month inside the credit. ([Modal pricing](https://modal.com/pricing), [Budgets](https://modal.com/docs/guide/budgets), [Sandboxes](https://modal.com/docs/guide/sandboxes)) |
| Daytona | "$200 in free compute", "no credit card required" (**whether one-time or recurring is not stated**) | $0.0504/vCPU-h, $0.0162/GiB-h → ~$0.08 per 30 min | Prepaid wallet with optional auto top-up; **behaviour at $0 balance and any spend cap undocumented** | Not stated | Tier 1 (email only): 10 vCPU. Ephemeral sandboxes are deleted on stop. ([Daytona pricing](https://www.daytona.io/pricing), [Limits](https://www.daytona.io/docs/en/limits), [Billing](https://www.daytona.io/docs/en/billing), [Sandboxes](https://www.daytona.io/docs/en/sandboxes)) |

### Fly Machines (own containers): fails "no surprise bills"

New organisations "don't have a free tier or a monthly free usage allowance" (only a $1, 7-day trial). Machines are billed per second; shared-cpu-2x with 2 GB is $13.39 for 30 days, about $0.01 per 30 min. The pricing page documents **no spending cap** ([Fly pricing](https://docs.fly.io/about/pricing)). That makes it cheap but uncapped, so it doesn't qualify unless the orchestrator's teardown is trusted as the only guard.

### Claude Managed Agents: violates the subscription constraint

It needs "A Claude API key" and is in beta ([Managed Agents overview](https://platform.claude.com/docs/en/managed-agents/overview)). The price is tokens plus $0.08 per session-hour, with session budgets as a dollar cap ([Pricing](https://platform.claude.com/docs/en/about-claude/pricing)). Keep it only as the API-key fallback if the subscription path breaks (#3's 401 risk).

### Copilot coding agent and Codex cloud: other vendors' billing

Claude and Codex are available as coding agents through GitHub's Agent HQ, included with Copilot Pro and above ([GitHub changelog, 2026-02-26](https://github.blog/changelog/2026-02-26-claude-and-codex-now-available-for-copilot-business-pro-users/)). Copilot Free doesn't include the cloud agent. Pro costs $10/month with 1,500 AI credits ([Copilot plans](https://docs.github.com/en/copilot/get-started/plans)). Either way the model is paid through Copilot, not the Claude subscription, and **whether Copilot overage has a hard stop was not verified**. Codex cloud uses a ChatGPT plan. Both are out of scope under the standing decisions.

## Ranked shortlist for this factory

1. **GitHub-hosted Actions: keep as the default runner.** It is free for public targets and hard $0 for private ones, it reuses the settled stub topology, and the run page doubles as observability. The trade-off: the ~2,000 private minutes a month cap private-repo throughput at roughly 65-130 runs.
2. **Claude Code cloud scheduled tasks: the complement for private-repo runs once minutes get scarce, starting with automated review.** It adds $0 compute on a native surface with the cleanest terms. Trigger it from an Actions stub via `/fire` so the opt-in gate and the concurrency group stay in Actions. The trade-offs: research preview, owner-identity PRs and comments (they conflict with #5's App identity and with owner approval), dropped events over the hourly caps, and logs off GitHub.
3. **Ephemeral self-hosted Actions runner on a capped VPS (Hetzner ~€5.49-9.99/mo) or a spare machine: the complement for private implementer runs.** It removes the minute ceiling with no change to the orchestrator and has a hard monthly cap. The trade-offs: you build and maintain the disposable container image and patching, it is safe for private repos only, and GitHub could revive the self-hosted fee.
4. **Vercel Sandbox Hobby (then E2B Hobby): only if #15 picks a non-Actions orchestrator.** It is free with a hard pause, and model-wait time is nearly free. The trade-offs: it needs an orchestrator and log shipping, the 45-min max session on Hobby, roughly 50 free runs a month, and E2B's credit is one-time.

Not shortlisted: Modal (good caps, but it needs a card and an orchestrator, and adds nothing over Vercel at this scale); Daytona (cap behaviour undocumented); Fly (no cap); self-hosted environments (Team/Enterprise only); Managed Agents (API key); Copilot and Codex (separate billing).

## Open questions and unverified items

- **Hetzner:** whether 1-2 GB is enough RAM for Claude Code plus typical test suites. Also, both of the cheapest plans showed "currently unavailable" in HEL1 on the day checked.
- **Claude scheduled tasks:**
  - the exact GitHub-event hourly caps (not published).
  - whether a task's commits can use an App identity instead of the owner's.
  - session max length on Anthropic-hosted VMs (only an inactivity expiry is documented).
  - how far the 4 vCPU/16 GB VM eats into the subscription allowance compared with an Actions run (both are model-bound; expected to be similar).
- **Daytona:** whether the $200 is one-time, and what happens at $0 balance.
- **Vercel:** whether the Hobby fair-use (non-commercial) clause applies.
- **Copilot:** coding-agent overage controls, and whether it consumes Actions minutes.
- **GitHub:** the self-hosted runner fee's postponement rests on secondary reporting plus the current billing page; no GitHub changelog was found reviving it.

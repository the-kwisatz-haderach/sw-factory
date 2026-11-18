# Alternative orchestrators for factory runs

Research for [#15](https://github.com/the-kwisatz-haderach/sw-factory/issues/15), part of map [#2](https://github.com/the-kwisatz-haderach/sw-factory/issues/2). Sources were read on 2026-11-18. Prices and free allowances go stale quickly, so re-check them before committing to one.

Vocabulary follows `.claude/skills/software-factory/SKILL.md`. The **orchestrator** receives triggers, starts runs on runners, and records which runs are queued, in flight or finished. Runner choice belongs to companion ticket #14, so this file only notes which runner types each orchestrator *can start*.

## Short answer

- **Every option still needs a workflow file in each target repo if the runner is a GitHub Actions runner.** An external orchestrator starts an Actions run with `POST /repos/{owner}/{repo}/actions/workflows/{id}/dispatches`. That call needs the **Actions: write** repository permission, which a GitHub App installation token can hold ([GitHub App permissions](https://docs.github.com/en/rest/authentication/permissions-required-for-github-apps?apiVersion=2022-11-28)). The response now returns `workflow_run_id`, `run_url` and `html_url` ([workflow dispatch API](https://docs.github.com/en/rest/actions/workflows#create-a-workflow-dispatch-event)), so the orchestrator can track the run it started. So an external orchestrator doesn't remove the stub. It only moves the *decision* about when to run out of Actions.
- **What an external orchestrator adds over Actions** is an **account-wide** queue and throttle (Actions concurrency groups are per repo, see #4), a durable record of each run, and per-ticket dedup that holds across repos and event types. That matters mainly for protecting the shared Claude subscription limits (see #3).
- **#5 said GitHub App webhooks need a hosted endpoint.** A Cloudflare Worker on the Free plan is such an endpoint at $0, with a hard stop rather than a bill.
- **Recommendation:** stay with **Actions-as-orchestrator** for now. If an account-wide throttle or ledger is needed, add **Cloudflare Workers + Durable Objects (Free)** as a thin layer in front. The best managed alternatives are **Inngest Hobby** and **Trigger.dev Free**. A **tiny VPS** is the fallback when more control is needed than a free tier allows.

## Two ways to receive GitHub events

1. **GitHub App webhooks → orchestrator.** One app installed on the opted-in repos sends `issues`, `issue_comment`, `pull_request`, `workflow_run` and similar events to one URL. GitHub expects a 2XX reply "within 10 seconds", otherwise it counts the delivery as failed ([webhook best practices](https://docs.github.com/en/webhooks/using-webhooks/best-practices-for-using-webhooks)). "GitHub does not automatically redeliver failed deliveries", and manual redelivery only reaches back 3 days ([redelivering webhooks](https://docs.github.com/en/webhooks/testing-and-troubleshooting-webhooks/redelivering-webhooks)). So the receiver must reply fast, put the event on a queue, and be up almost all the time, or else run a periodic catch-up sweep (for example, listing issues that carry the ready label). `X-GitHub-Delivery` is unique per event and is the same on redelivery, so it works as a dedup key (same source).
2. **Actions stub calls out.** The target repo's stub workflow fires on the event as it does now, and its first step POSTs to the orchestrator. This needs no app webhook, but it uses one short job's minutes per event (each job is rounded up to a whole minute on private repos, see #4) and needs an orchestrator credential in each target repo's secrets.

Option 1 is cleaner: one install, no per-repo secret, and the opt-in gate stays at "app installed + stub present" (#5). Option 2 avoids running anything always-on.

## Comparison

| Orchestrator | Free tier (relevant limits) | Hard spending cap? | Receives events via | Run ledger (queued / in flight / finished) | One run per ticket | Can start runners | Solo-dev ops burden |
|---|---|---|---|---|---|---|---|
| **GitHub Actions (baseline)** | Public repos free. Private repos share $12/mo (~2,000 Linux min). 20 concurrent jobs per account (#4) | Yes: with no card, usage is blocked at $0 (#4) | Native repo events | Actions run list per repo, with no cross-repo view | `concurrency` group per repo/ticket, `queue: max` FIFO (#4). Per repo only | Actions hosted/self-hosted runners, plus anything a step can call over HTTP | None |
| **Cloudflare Workers + Durable Objects (+ Queues / Workflows)** | Workers 100k req/day, 10 ms CPU per invocation. DO 100k req/day, 5 GB SQLite. Queues 10k ops/day, 24 h retention. Workflows 3,000 steps/day, 100 concurrent instances, 3-day state retention ([pricing](https://developers.cloudflare.com/workers/platform/pricing/), [Workflows limits](https://developers.cloudflare.com/workflows/reference/limits/)) | Free plan: errors, not charges. DO "further operations of that type will fail with an error" ([DO pricing](https://developers.cloudflare.com/durable-objects/platform/pricing/)). Workers over the daily limit return Error 1027 ([limits](https://developers.cloudflare.com/workers/platform/limits/)). Paid ($5/mo) has an optional spending limit that blocks new invocations | App webhook (a Worker replies in <10 s, then enqueues) or a stub POST | You build it: a DO with SQLite rows per run and status. Workflows also keep instance state for 3 days | You build it: a single DO per ticket (or per repo) serialises access, which is a natural lock | `workflow_dispatch` (Actions), or HTTP to sandbox/VPS APIs. 50 subrequests per invocation on Free ([limits](https://developers.cloudflare.com/workers/platform/limits/)) | Low: serverless, but you write and maintain the code |
| **Inngest (Hobby)** | 50k executions/mo (each run and each step counts), 5 concurrent steps, 24 h trace history, 30-day max run length, 500k events ([pricing](https://www.inngest.com/pricing)) | Yes: "execution pauses once you hit the free quota". No card needed (same page) | App webhook → Inngest webhook/event endpoint, or stub POST (not verified: the exact GitHub webhook transform setup) | Built-in run dashboard, but only 24 h of history on Hobby | `singleton` keyed by ticket, with skip or cancel mode ([singleton](https://www.inngest.com/docs/guides/singleton)). Availability on Hobby is not stated (unverified) | Steps run in **your** app (Inngest calls your endpoint), e.g. a Cloudflare Worker or Vercel function that calls `workflow_dispatch` or a sandbox API | Low to medium: two systems (Inngest + your hosted functions) |
| **Trigger.dev (Free)** | $5/mo compute credit, $0.000025 per run, 20 concurrent runs, 10 schedules, 1-day log retention, no max run duration ([pricing](https://trigger.dev/pricing), [limits](https://trigger.dev/docs/limits)) | Partly: on Free, once the $5 is used "you must upgrade". Paid plans keep billing past credits, with alerts only and no stated hard cap (unverified) | App webhook → your endpoint → `task.trigger()`, or stub POST | Built-in run dashboard, but logs last 1 day on Free | `concurrency: { perKey: 1 }` + `concurrencyKey: ticketId` queues later runs instead of dropping them ([queue concurrency](https://trigger.dev/docs/queue-concurrency)) | Its own managed containers (it can be the runner too, billed against the $5 credit), or `workflow_dispatch` / sandbox APIs | Low: hosted. The deploy is a CLI push |
| **Upstash QStash / Workflow (Free)** | QStash 1,000 msgs/day, 15 min max HTTP response, 3-day log/DLQ retention, 10 schedules. Workflow 1,000 steps/day, 10 concurrent steps ([QStash](https://upstash.com/pricing/qstash), [Workflow](https://upstash.com/pricing/workflow)) | No stated cap. Daily limits are "soft", and runs "may fail with quota errors". Pay-as-you-go is $1 per 100k with no cap mentioned (same pages) | QStash is a delivery queue, so your endpoint still receives the webhook | Logs/DLQ for 3 days. A durable ledger needs Upstash Redis or similar | Not built-in at ticket level (unverified: QStash flow control/dedup ids may help) | Whatever your endpoint calls (`workflow_dispatch`, sandbox APIs) | Medium: a queue only, so the rest is yours |
| **Temporal Cloud** | No ongoing free tier: $150 trial credit for 90 days, card required. $50 per 1M actions on the Developer plan, plus 10% support ([pricing](https://temporal.io/pricing), [docs](https://docs.temporal.io/cloud/pricing)) | No cap described | Your webhook endpoint → starts a workflow | Excellent built-in history | Workflow ID uniqueness (ticket ID as workflow ID). Standard Temporal behaviour, not re-verified here | Your workers (which you host) call anything | High: you host workers, and there's no free tier. **Fails the no-surprise-bills rule** |
| **Self-hosted n8n on a tiny VPS** | n8n Community edition is free when self-hosted ([hosting docs](https://docs.n8n.io/hosting/)). Sustainable Use License allows internal use ([license FAQ](https://docs.n8n.io/n8n-community-license/community-license/license-faq)) | Yes by nature: a flat VPS fee | GitHub trigger node/webhook node (app webhook) | n8n execution history in its DB | Possible, but awkward in low-code (needs a DB lookup/lock node) | Same HTTP calls, plus `docker run --rm` on the same box | Medium to high: OS patching, TLS, backups, n8n upgrades |
| **Tiny VPS with own script** | Hetzner Cloud from €5.49/mo excl. VAT ([Hetzner Cloud](https://www.hetzner.com/cloud/)). Oracle Always Free gives 2 OCPU/12 GB Arm, but idle instances "may be reclaimed" and capacity errors happen ([OCI Always Free](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm)) | Yes: flat fee. Oracle is $0 | App webhook (needs TLS + uptime) | SQLite table you write | SQLite unique constraint / lock | Anything, including fresh local containers (VPS doubles as a runner, see #14) | High: an always-on server to keep alive and patched |

## Notes per option

### GitHub Actions as orchestrator (baseline)

Already settled in #4 and #5: a stub per target repo calls the factory's reusable workflow. A `concurrency` group keyed per repo or ticket gives one run at a time with a FIFO queue (`queue: max`, up to 100 pending). Its gaps:
- No **account-wide** throttle. Two target repos can each start a Claude run at the same moment, and both draw on the same 5-hour subscription window (#3).
- No single view of runs across repos. The Projects board (#6) partly covers this.
- Each event costs at least one rounded-up minute in private repos, even when the job just decides to skip.

For one owner with a few repos and "slower is fine", these gaps are tolerable. A crude account-wide throttle is possible inside Actions too (for example, a check step that counts in-progress runs across repos through the API before starting the agent). That idea was not tested here.

### Cloudflare Workers + Durable Objects (Free)

This is the cheapest way to get an always-on GitHub App webhook receiver with a stateful ledger. The suggested shape is one Worker that verifies the webhook signature, replies 2XX, and forwards to a Durable Object. The Durable Object is either one per account (a global queue: run at most N at a time) or one per ticket (a lock). It stores rows in SQLite and calls `workflow_dispatch` on the target repo with an App installation token. A `workflow_run` webhook marks the run finished. The volumes involved (tens of events a day) are far below the free limits. The Free plan fails with errors instead of billing, which meets the no-surprise-bills rule.

Caveats:
- The 10 ms CPU per invocation on Free covers JSON handling and JWT signing for App tokens. RS256 signing through WebCrypto counts toward CPU time, so watch it (unverified whether it fits in 10 ms).
- Queues on Free keep messages only 24 h. The DO's own SQLite table should be the ledger, not the queue.
- Cron Triggers allow a periodic catch-up sweep for missed deliveries.

### Inngest (Hobby)

Inngest has the strongest built-in fit for "one run per ticket" (`singleton` with skip/cancel) and declarative concurrency. Execution pauses at the quota, so it never bills on Hobby. It does not host compute, though. It calls functions you serve (for example, on Cloudflare Workers or Vercel), so in practice it is "Cloudflare + Inngest". History lasts only 24 h, so the ledger of record would still be the GitHub issue/PR state. Fifty thousand executions a month is plenty if each run is a few steps.

### Trigger.dev (Free)

Trigger.dev has the best per-ticket queueing semantics (`perKey: 1` queues the second run instead of dropping it). It can also *be* a runner, since tasks run in its containers with no maximum duration. Whether Claude Code CLI plus a repo checkout fits its machines and the $5 credit is a #14 question, and not verified here. The Free plan stops when the credit runs out. Paid plans bill overage with alerts only, so stay on Free or confirm that a hard cap exists before upgrading. Logs last 1 day.

### Upstash QStash / Workflow

QStash is a good durable delivery queue with retries and DLQ, but it is not an orchestrator on its own: no per-key locking and no long-lived ledger. Its limits are soft, and there's no stated spend cap on pay-as-you-go. It is useful only as a component, and Cloudflare Queues/DOs already cover the same need.

### Temporal Cloud

Temporal Cloud is the most capable durable-workflow engine, but it requires a card, has no ongoing free tier and no spending cap, and still needs self-hosted workers. Self-hosted Temporal needs a database and an always-on cluster. It is far too heavy for a solo factory. **Excluded.**

### Self-hosted n8n / tiny VPS

A VPS gives full control and a hard flat price, and it can double as the runner (`docker run --rm` per run, see RUNNERS.md "Own VPS or containers"). The cost is ops: TLS, uptime for webhooks (GitHub won't retry), patches and backups. n8n adds a UI and GitHub nodes, but per-ticket locking in low-code is clumsy, and n8n itself is another thing to upgrade. Oracle Always Free is $0, but reclamation of idle instances and home-region capacity errors make it unreliable for an always-on receiver.

## Ranked shortlist

1. **GitHub Actions (stay).** $0, already proven, with no extra system. Per-repo concurrency is enough while volume is low. Revisit if the subscription window gets contended across repos.
2. **Cloudflare Workers + Durable Objects (Free), as an add-on in front of Actions.** It gives a $0 hard-capped App webhook receiver, an account-wide throttle and a run ledger. You write about a few hundred lines of code, and runners stay Actions via `workflow_dispatch`.
3. **Inngest Hobby.** Managed singleton/concurrency per ticket, and it pauses at the quota. It still needs a host for its functions (pair it with #2), and history lasts only 24 h.
4. **Trigger.dev Free.** Per-key queueing, and it can also be the runner. The $5 credit and 1-day logs are tight, and there's no confirmed hard cap on paid plans.
5. **Tiny VPS (Hetzner ~€5.49/mo) with own script or n8n.** Full control, and it can be the runner too, but it carries the highest ops burden for a solo dev.

Excluded: **Temporal Cloud** (no free tier, no cap, card required), **Upstash** alone (queue only, soft limits, no stated cap), and **Oracle Always Free** as the primary host (idle reclamation).

## Unverified / open

- Whether Inngest `singleton` is available on Hobby.
- Whether Trigger.dev offers a hard spend cap on paid plans.
- Whether GitHub App JWT signing fits Cloudflare Free's 10 ms CPU budget per invocation. The installation token can be cached for its 1 h lifetime to sign rarely.
- The Upstash QStash flow-control/deduplication features were not checked in detail.
- Temporal's workflow-ID uniqueness behaviour is stated from general knowledge, not re-read.

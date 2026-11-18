# Can a Claude subscription token drive unattended Claude Code runs in GitHub Actions?

Research for #3 (parent map #2). Sources were read on 2026-11-18. Doc pages change often, so re-check any quoted version number before you rely on it.

## Short answer

**Yes, for the owner's own repos, with caveats.** Anthropic documents this exact setup as supported: run `claude setup-token`, store the result as the `CLAUDE_CODE_OAUTH_TOKEN` secret, and pass it to `anthropics/claude-code-action` as `claude_code_oauth_token`. Runs draw from the same 5-hour and weekly allowances as the owner's interactive Claude use. When an allowance runs out, the run fails with a `rate_limit` error unless it is told to wait. The token lasts one year and never refreshes. Rotating it is a manual step. Max ($100/month, 5x Pro) is the sensible starting tier for one implementer and one review run at a time.

The caveats:

1. The terms rely on "ordinary, individual usage" and allow automation only where Anthropic "explicitly permits it". This is a gray zone, not a ban (see section 1).
2. An open bug in the action causes some `setup-token` tokens to be rejected with 401 (see section 5).
3. Anthropic does not publish the allowance as a number of tokens, so how much a plan can handle has to be measured.

## 1. What the terms allow

**The docs explicitly support it.** The Claude Code GitHub Actions page lists `CLAUDE_CODE_OAUTH_TOKEN` as "an OAuth token that authenticates with your Claude subscription, available on Pro, Max, Ultra, Team, and Enterprise plans. Generate one by running `claude setup-token` locally." It also says: "If you authenticate with an OAuth token, runs use your Claude subscription instead of API billing." The quick setup (`/install-github-app`) offers to create this token for you.
- https://code.claude.com/docs/en/github-actions (sections "Manual setup", step 2, and "Manage costs")

The authentication docs describe `CLAUDE_CODE_OAUTH_TOKEN` as the credential to "Use … for CI pipelines and scripts where browser login isn't available."
- https://code.claude.com/docs/en/authentication#authentication-precedence

**Which terms apply.** Pro, Max and Ultra users fall under the **Consumer Terms**. Team, Enterprise and API users fall under the Commercial Terms.
- https://code.claude.com/docs/en/legal-and-compliance#license

**The Consumer Terms (effective Oct 8, 2025), section 3** forbid accessing the Services "through automated or non-human means, whether through a bot, script, or otherwise". There are two exceptions: access "via an Anthropic API Key" and access "where we otherwise explicitly permit it". The same terms forbid sharing account credentials "with anyone else".
- https://www.anthropic.com/legal/consumer-terms

**The legal and compliance page** adds:
- "Advertised usage limits for Pro, Max, and Ultra plans assume ordinary, individual usage of Claude Code and the Agent SDK."
- "OAuth authentication … is designed to support ordinary use of Claude Code and other native Anthropic applications."
- The ban targets developers who "route requests through Free, Pro, Max, or Ultra plan credentials **on behalf of their users**", and anyone who intermediates other people's credentials.
- "Anthropic reserves the right to take measures to enforce these restrictions and may do so without prior notice."
- https://code.claude.com/docs/en/legal-and-compliance#authentication-and-credential-use

**Interpretation (not a legal opinion):**
- The owner runs the unmodified Claude Code binary, through Anthropic's own action, with their own token, on their own repos, for their own benefit. That is the use the docs describe, and it fits the "explicitly permit" exception.
- The setup would cross a line if it served anyone else. Examples: letting other people's issues or PRs trigger runs paid for by the owner's subscription, or packaging the factory as a service for other people.
- The softer risk is volume. Allowances "assume ordinary, individual usage", so a factory running around the clock is the case most likely to draw throttling or enforcement.
- **Unverified:** I found no Anthropic statement that says outright "unattended CI on a personal Pro or Max plan is fine at any volume". Nor did I find a published threshold for "ordinary" use.

Two consequences for the factory:
- Keep the owner as the only person who can trigger runs. By default the action already rejects users without write access and bot actors, unless they are allow-listed (`allowed_non_write_users`, `allowed_bots`).
  - https://code.claude.com/docs/en/github-actions#who-can-trigger-runs
- Keep throughput modest. The map's existing "throttled, one run at a time" decision already does this.

## 2. Usage limits and what a CI run sees when it hits one

**The allowance is shared and counts in two windows at once.** "Pro and Max plans have a five-hour session limit and a weekly limit … These limits are shared across Claude and Claude Code, meaning all activity in both tools counts against the same limits." Max and Ultra also have a separate weekly limit for Fable. Ultra has no 5-hour limit for verified accounts.
- https://support.claude.com/en/articles/11145838-use-claude-code-with-your-pro-or-max-plan

So factory runs and the owner's own chat and Claude Code use draw from **one pool**. "Usage counts against the session and weekly allowances at the same time. A single burst of heavy activity … can exhaust the weekly allowance before the session window resets."
- https://code.claude.com/docs/en/errors#youve-hit-your-session-limit

**The messages a run reports** include `You've hit your session limit · resets 3:45pm`, `You've hit your weekly limit · resets Mon 12:00am`, and model-specific variants such as `You've hit your Opus limit`. "Claude Code blocks further requests until the reset time shown in the message." The session and weekly limits cover all models, so switching models doesn't help. The Opus-only and Sonnet-only limits can be avoided by switching model family.
- https://code.claude.com/docs/en/errors#youve-hit-your-session-limit

**There is a small grace period.** If a limit is hit mid-response, Claude Code may keep going briefly to finish the current step. It shows `Usage limit reached · wrapping up` while it does. On Max this can happen every time a 5-hour limit is hit. On Pro it happens at most once a week.
- support article above

**In headless mode (how the action runs Claude Code):**
- `claude -p` exits non-zero when a run fails.
- The structured result has an `error` field. Its values include `rate_limit`, `billing_error` and `authentication_failed`.
- https://code.claude.com/docs/en/headless (exit codes; result `error` field)

**In the action:**
- A rate limit shows up as an SDK `result` with `is_error: true`, and the step fails.
- Before a fix that is now on `main`, the execution file wasn't written on this failure path, so a rate limit looked the same as any other failure. The execution file is now written in a `finally` block. A workflow can parse it to tell a rate limit apart from a real failure.
- The `conclusion` output (`success`/`failure`) is available.
- https://github.com/anthropics/claude-code-action/issues/1040
- https://github.com/anthropics/claude-code-action/blob/main/action.yml (`outputs.conclusion`, `execution_file`)

**Waiting instead of failing (opt-in):**
- `CLAUDE_CODE_RETRY_WATCHDOG=1` makes Claude Code retry 429 and 529 errors indefinitely. It is documented as meant for "unattended sessions such as CI jobs".
- `CLAUDE_CODE_RETRY_WATCHDOG_MAX_USAGE_LIMIT_WAIT_MS` (v2.1.301+) caps how long a request waits for a session or weekly reset. If the reset is further away than the cap, the request "fails at once".
- `CLAUDE_CODE_RETRY_WATCHDOG_USAGE_LIMIT_RECHECK_MS` (v2.1.305+) polls for the limit being lifted early.
- The watchdog never waits out a 429 caused by a spend limit or exhausted usage credits. Those fail immediately.
- https://code.claude.com/docs/en/errors#tune-retry-behavior

For the factory, waiting inside a job uses Actions minutes, and hosted jobs stop after 6 hours. **Fail fast, then re-queue** is the cheaper loop brake. Set no watchdog, or a short `MAX_USAGE_LIMIT_WAIT_MS`. Detect `rate_limit` from the execution file, label the ticket as deferred, and let the throttle retry after the reset.

**Unverified:** I didn't test that `env:` on the `uses:` step reaches the Claude Code process the action starts. It is very likely, because the action is composite and its `action.yml` passes the environment through, but test it once.

**No visibility into the allowance from CI.** The action does not expose 5-hour or weekly usage as outputs. A feature request for this is open, and the usage endpoint it would need is undocumented. Budget-aware throttling therefore has to rely on counting runs, not on reading the remaining allowance.
- https://github.com/anthropics/claude-code-action/issues/1518

**Usage credits are a surprise-bill risk.** Pro, Max and Ultra can turn on usage credits to keep working past a limit. For Pro, Max and Ultra, `/usage` shows "your monthly spend limit when you have set one. When you haven't set a limit, the row shows `Unlimited`."
- https://code.claude.com/docs/en/costs#add-usage-credits-to-your-subscription
- https://support.claude.com/en/articles/12429409-extra-usage-for-paid-claude-plans

To satisfy the map's "no surprise bills" rule, do one of these at claude.ai › Settings › Usage:
- Keep usage credits **off**. This gives a hard stop at the allowance.
- Turn them on with an explicit **monthly spend limit**.

Also make sure no `ANTHROPIC_API_KEY` reaches the runner. An API key outranks the OAuth token, and in `-p` mode "the key is always used when present", which would silently switch the run to per-token API billing.
- https://code.claude.com/docs/en/authentication#authentication-precedence

## 3. Token lifetime and rotation

**Lifetime and limits.**
- `claude setup-token` generates "a one-year OAuth token". It opens the same browser flow as `/login`, prints the token, and saves it nowhere.
- The token "can only make model requests". It can't start Remote Control or fetch claude.ai connectors, though locally configured MCP servers still work.
- Bare mode (`--bare`) does not read it.
- https://code.claude.com/docs/en/authentication#generate-a-long-lived-token

**No automatic refresh.** If the token expires or is revoked, runs fail with `Failed to authenticate. API Error: 401 OAuth token has expired` or `Failed to authenticate: OAuth token revoked`, with error code `authentication_failed`. Claude Code "keeps sending the value you set after a request fails with a 401". The fix is to run `claude setup-token` again and update the secret.
- https://code.claude.com/docs/en/errors#oauth-token-revoked-or-expired

**Rotation is manual, about once a year:**
1. Run `claude setup-token` locally.
2. Update the secret with `gh secret set CLAUDE_CODE_OAUTH_TOKEN`.
3. Optionally revoke the old token.

**Unverified:**
- Whether there is a self-service page for revoking a single setup-token. I didn't find one documented. "Sign out everywhere" is the documented trigger for revocation.
- Whether minting a new token invalidates the old one. Reports in action issue #1614 of "four separately minted tokens" suggest several can exist at once.
- The docs give no expiry warning for env-var tokens. The 3-day `/login` renewal warning applies only to interactive claude.ai logins.

The factory should therefore record the mint date and raise a reminder ticket at about 11 months. It should also treat `authentication_failed` as "stop everything and tell the owner", not as something to retry.

**Scope across repos.** The docs recommend an API key "for a secret shared across repositories … since an OAuth token is tied to the subscription of the person who ran `claude setup-token`".
- https://code.claude.com/docs/en/github-actions#set-up-for-an-organization

That advice targets teams. With one owner the tie is exactly what we want. But repos owned by a personal account have no organization-level secrets, so the token must be:
- stored in each opted-in target repo, or
- passed from the caller with `secrets: inherit` / explicit `secrets:` into a reusable workflow in the factory repo.

Every copy has to be updated on rotation. This feeds the "opt-in mechanism" question in #2.

## 4. Which plan tier

Individual plans, from https://claude.com/pricing as of 2026-11-18:

| Plan | Price | Allowance | Notes |
| - | - | - | - |
| Free | $0 | — | No Claude Code, so not usable |
| Pro | $20/mo ($17/mo billed annually) | Baseline | 5-hour + weekly limits. Wrap-up grace at most once a week |
| Max | $100/mo | "5x Pro usage" per 5 hours and per week | Wrap-up grace at every 5-hour limit |
| Ultra | $200/mo | "10x Pro usage every week" | "No 5-hour limit" for verified accounts |

The page no longer lists a "Max 20x" tier. Ultra is the $200 tier.

Anthropic doesn't publish allowances in tokens, so it can't be calculated in advance how many runs fit in a window. For scale:
- Anthropic's enterprise figures average about $13 of API-equivalent usage per developer per active day.
  - https://code.claude.com/docs/en/costs
- One agentic implementer run with tests and a review run can each use a large share of a Pro 5-hour window.
- The factory shares the pool with the owner's own interactive use.

**Recommendation:**
- **Max ($100)** is the right starting tier for one implementer plus one review run at a time, throttled, alongside the owner's own use.
- Pro will probably hit the 5-hour limit after a few runs and starve the owner's interactive work.
- Consider **Ultra** only if weekly limits keep blocking the queue. Its benefit is mainly removing the 5-hour window, which suits a queue that runs all day.
- To keep costs predictable, use Sonnet for review runs. Reserve Opus for implementers, or use it only when needed. Set `--max-turns` and job `timeout-minutes`.
- Measure before deciding. After a week of runs, check `/usage` locally to see the weekly percentage. Its attribution covers only local sessions, so read the plan bars, not the breakdown.

## 5. Practical risks found

- **Open bug in the action: OAuth tokens rejected with 401.** Some users report that a token from `claude setup-token` gets `401 OAuth access token is invalid` in the action while the same account works locally. It has been reproduced on Max and Team plans, on action v1.0.18x, and still on CLI 2.1.268 in September 2026. A comment notes that some reports were really 429 errors showing up as 401. Test early. If this happens, the fallback is an API key with a Console workspace spend limit, which also satisfies "no surprise bills".
  - https://github.com/anthropics/claude-code-action/issues/1614
- **Recurring "instant is_error, 0 turns" failures.** These are open, with reports from August to November 2026 under both OAuth and API key auth. The factory should treat a run with zero turns and an error as an infrastructure failure and retry it later. It should not count toward the rework cap.
  - https://github.com/anthropics/claude-code-action/issues/1720
  - https://github.com/anthropics/claude-code-action/issues/2047
- **Scheduled triggers.** These are relevant if the throttle is cron-based. GitHub runs scheduled workflows only from the default branch. In public repos it disables the schedule after 60 days without activity. The action rejects a bot actor on scheduled runs unless that bot is in `allowed_bots`.
  - https://code.claude.com/docs/en/github-actions#run-on-a-schedule

## Open questions (could not verify)

1. How much of each allowance is available, in tokens or runs. Anthropic doesn't publish it, so it has to be measured.
2. Whether Anthropic considers steady, throttled, single-user CI on Max "ordinary, individual usage". The docs endorse the mechanism but don't set a volume threshold.
3. How to revoke one specific setup-token, and whether new tokens invalidate old ones.
4. Whether the limit-reached message includes a machine-readable reset time in the action's execution file. The CLI message includes the time as text (`resets 3:45pm`). If it is parseable, the throttle could schedule the retry exactly.

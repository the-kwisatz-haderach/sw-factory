#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
ctx="$here/../implementer/pr-context"

# run_ctx <json> runs pr-context on the given input.
run_ctx() { echo "$1" | "$ctx"; }

pr='"number":12,"title":"Add the thing","url":"https://github.com/o/r/pull/12"'

expect_output "a PR with a conversation comment" "$(cat <<'MD'
# PR #12: Add the thing

https://github.com/o/r/pull/12

---

**owner** commented on 2026-11-20T10:00:00Z:

Please rename it.
MD
)" run_ctx "{$pr,\"reviews\":[],\"review_comments\":[],\"comments\":[
  {\"user\":{\"login\":\"owner\"},\"created_at\":\"2026-11-20T10:00:00Z\",\"body\":\"Please rename it.\"}]}"

expect_output "reviews with a body are interleaved by time; empty ones are skipped" "$(cat <<'MD'
# PR #12: Add the thing

https://github.com/o/r/pull/12

---

**claude[bot]** reviewed (COMMENTED) on 2026-11-20T09:00:00Z:

Fails the spec: no test for the empty case.

---

**owner** commented on 2026-11-20T10:00:00Z:

Agree with the review.
MD
)" run_ctx "{$pr,\"review_comments\":[],
  \"comments\":[{\"user\":{\"login\":\"owner\"},\"created_at\":\"2026-11-20T10:00:00Z\",\"body\":\"Agree with the review.\"}],
  \"reviews\":[
    {\"user\":{\"login\":\"owner\"},\"state\":\"APPROVED\",\"submitted_at\":\"2026-11-20T11:00:00Z\",\"body\":\"\"},
    {\"user\":{\"login\":\"claude[bot]\"},\"state\":\"COMMENTED\",\"submitted_at\":\"2026-11-20T09:00:00Z\",\"body\":\"Fails the spec: no test for the empty case.\"},
    {\"user\":{\"login\":\"claude[bot]\"},\"state\":\"COMMENTED\",\"submitted_at\":\"2026-11-20T09:05:00Z\",\"body\":null}]}"

expect_output "inline comments name their file and line, outdated ones their original line" "$(cat <<'MD'
# PR #12: Add the thing

https://github.com/o/r/pull/12

---

**claude[bot]** commented on `src/a.ts` line 4 on 2026-11-20T09:00:00Z:

Off by one.

---

**owner** commented on `src/b.ts` line 9 (outdated) on 2026-11-20T09:30:00Z:

Use the glossary term.
MD
)" run_ctx "{$pr,\"reviews\":[],\"comments\":[],\"review_comments\":[
  {\"user\":{\"login\":\"owner\"},\"created_at\":\"2026-11-20T09:30:00Z\",\"path\":\"src/b.ts\",\"line\":null,\"original_line\":9,\"body\":\"Use the glossary term.\"},
  {\"user\":{\"login\":\"claude[bot]\"},\"created_at\":\"2026-11-20T09:00:00Z\",\"path\":\"src/a.ts\",\"line\":4,\"original_line\":4,\"body\":\"Off by one.\"}]}"

expect_output "a deleted user shows as ghost" "$(cat <<'MD'
# PR #12: Add the thing

https://github.com/o/r/pull/12

---

**ghost** commented on 2026-11-20T10:00:00Z:

Old note.
MD
)" run_ctx "{$pr,\"reviews\":[],\"review_comments\":[],\"comments\":[
  {\"user\":null,\"created_at\":\"2026-11-20T10:00:00Z\",\"body\":\"Old note.\"}]}"

finish

#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
pick="$here/../implementer/pick-ticket"

# Shaped like GET /repos/{owner}/{repo}/issues: newest first, PRs included.
issues='[
  {"number": 9, "title": "Newest", "created_at": "2026-11-20T10:00:00Z"},
  {"number": 7, "title": "A PR", "created_at": "2026-11-01T10:00:00Z", "pull_request": {"url": "x"}},
  {"number": 4, "title": "Oldest ticket", "created_at": "2026-11-02T10:00:00Z"},
  {"number": 6, "title": "Middle", "created_at": "2026-11-10T10:00:00Z"}
]'
expect_output "picks the oldest ticket, skipping PRs" "4" bash -c "echo '$issues' | '$pick'"
expect_output "no ready ticket prints nothing" "" bash -c "echo '[]' | '$pick'"
expect_output "only PRs prints nothing" "" bash -c "echo '[{\"number\":1,\"created_at\":\"2026-01-01T00:00:00Z\",\"pull_request\":{}}]' | '$pick'"

finish

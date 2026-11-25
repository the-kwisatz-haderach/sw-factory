#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
ticket_of="$here/../review/ticket-of"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

printf 'Closes #23\n\n## Summary\n' > "$tmp/body.md"
expect_output "reads Closes #<n> from the PR body" "23" "$ticket_of" "$tmp/body.md" agent/issue-23
expect_output "Closes wins over the branch name" "23" "$ticket_of" "$tmp/body.md" agent/issue-7

printf '## Summary\n\nSee #5 for context.\n' > "$tmp/no-closes.md"
expect_output "falls back to the agent branch's number" "7" "$ticket_of" "$tmp/no-closes.md" agent/issue-7
printf 'Discloses #9\nCloses #12.\n' > "$tmp/wordy.md"
expect_output "a word ending in 'closes' is not a Closes line" "12" "$ticket_of" "$tmp/wordy.md" agent/issue-1

expect_status "no Closes and no agent branch finds nothing" 1 "$ticket_of" "$tmp/no-closes.md" feature/x
expect_status "a missing body falls back to the branch" 0 "$ticket_of" "$tmp/absent.md" agent/issue-3

finish

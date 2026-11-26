#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
skip="$here/../review/rework-skip"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# GET repos/<r>/pulls/<n>, and `gh issue view --json number,labels`.
pr() { # <state> <head-sha>
  printf '{"number":40,"state":"%s","head":{"sha":"%s"}}' "$1" "$2" > "$tmp/pr.json"
}
ticket() { # <label>...
  jq -n '{number: 12, labels: [$ARGS.positional[] | {name: .}]}' --args "$@" > "$tmp/ticket.json"
}
run() { "$skip" h1 "$tmp/pr.json" "$tmp/ticket.json"; }

pr open h1; ticket agent:in-review
expect_output "an open PR at the reviewed head with its ticket in review goes on" "" run
expect_status "and that is a decision, not an error" 0 run

# A merged PR reads `closed` too: the merge closes the ticket, and an unmerged
# close is handback's.
pr closed h1; ticket agent:in-review
expect_output "a closed PR is left alone" \
  "PR #40 is closed; rework leaves its ticket alone." run
pr closed h2; ticket agent:needs-human
expect_output "a closed PR is the reason given, whatever else changed" \
  "PR #40 is closed; rework leaves its ticket alone." run

pr open h2; ticket agent:in-review
expect_output "a PR that moved on from the reviewed head is left to its new review" \
  "PR #40 moved on from h1; its new head gets its own review." run

pr open h1; ticket bug agent:needs-human
expect_output "a ticket a human or a run has moved on is left as it is" \
  'Ticket #12 is not `agent:in-review` (bug,agent:needs-human); left as it is.' run
pr open h1; ticket bug agent:in-review
expect_output "other labels beside agent:in-review don't matter" "" run
pr open h1; ticket agent:in-reviewed
expect_output "only the exact label counts" \
  'Ticket #12 is not `agent:in-review` (agent:in-reviewed); left as it is.' run

echo '{"message":"Not Found"}' > "$tmp/error.json"
pr open h1; ticket agent:in-review
expect_status "a PR that isn't one fails" 1 "$skip" h1 "$tmp/error.json" "$tmp/ticket.json"
expect_status "a ticket that isn't one fails" 1 "$skip" h1 "$tmp/pr.json" "$tmp/error.json"
expect_status "a missing file fails" 1 "$skip" h1 "$tmp/pr.json" "$tmp/absent.json"

finish

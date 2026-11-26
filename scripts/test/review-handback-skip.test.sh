#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
skip="$here/../review/handback-skip"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# `gh issue view --json number,state,labels`.
ticket() { # <state> <label>...
  local state="$1"; shift
  jq -n --arg state "$state" '{number: 12, state: $state, labels: [$ARGS.positional[] | {name: .}]}' \
    --args "$@" > "$tmp/ticket.json"
}
run() { "$skip" "$tmp/ticket.json"; }

ticket OPEN bug agent:in-review
expect_output "an open ticket in review is handed back" "" run
expect_status "and that is a decision, not an error" 0 run

ticket CLOSED agent:in-review
expect_output "a closed ticket is left alone" \
  'Ticket #12 is CLOSED; left as it is.' run
ticket OPEN bug agent:ready
expect_output "a ticket a human or a run has moved on is left as it is" \
  'Ticket #12 is not `agent:in-review` (bug,agent:ready); left as it is.' run
ticket OPEN agent:in-reviewed
expect_output "only the exact label counts" \
  'Ticket #12 is not `agent:in-review` (agent:in-reviewed); left as it is.' run

echo '{"message":"Not Found"}' > "$tmp/error.json"
expect_status "a ticket that isn't one fails" 1 "$skip" "$tmp/error.json"
expect_status "a missing file fails" 1 "$skip" "$tmp/absent.json"

finish

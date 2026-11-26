#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
handback="$here/../review/handback-ticket"

# The shape of a pull_request event's `pull_request` once it's closed.
pr() { # <merged> <head-ref> <head-repo> <body>
  jq -n --argjson merged "$1" --arg ref "$2" --arg repo "$3" --arg body "$4" \
    '{number: 40, state: "closed", merged: $merged, body: $body,
      head: {ref: $ref, repo: {full_name: $repo}}}'
}
run() { pr "$@" | "$handback" o/target; }

expect_output "an unmerged agent PR hands back the ticket it closes" "12" \
  run false agent/issue-12 o/target $'Closes #12\n\n## Summary'
expect_output "a merged agent PR hands back nothing" "" \
  run true agent/issue-12 o/target 'Closes #12'
expect_output "a PR from another branch hands back nothing" "" \
  run false feature/x o/target 'Closes #12'
expect_output "a fork's agent branch hands back nothing" "" \
  run false agent/issue-12 x/fork 'Closes #12'
expect_output "a deleted fork (no head repo) hands back nothing" "" \
  sh -c "echo '{\"merged\":false,\"body\":\"Closes #12\",\"head\":{\"ref\":\"agent/issue-12\",\"repo\":null}}' | '$handback' o/target"
expect_output "a body without Closes falls back to the agent branch's number" "7" \
  run false agent/issue-7 o/target 'Edited by the owner.'
expect_status "an agent PR naming no ticket fails" 1 run false agent/issue-x o/target 'No ticket here.'
expect_status "input that isn't a PR fails" 1 sh -c "echo '{\"message\":\"Not Found\"}' | '$handback' o/target"
expect_status "input that isn't JSON fails" 1 sh -c "echo 'oops' | '$handback' o/target"

finish

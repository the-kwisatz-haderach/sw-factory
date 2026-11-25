#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
plan="$here/../board/plan"

# plan <json> prints the actions compactly, one per line.
run_plan() { echo "$1" | "$plan" | jq -c '.[]'; }

expect_output "an untriaged issue off the board is added as Triage" \
  '{"action":"add","content":"I_1","status":"Triage"}' \
  run_plan '{"issues":[{"id":"I_1","labels":[]}],"items":[]}'

while IFS='|' read -r label status; do
  expect_output "$label maps to $status" \
    "{\"action\":\"add\",\"content\":\"I_1\",\"status\":\"$status\"}" \
    run_plan "{\"issues\":[{\"id\":\"I_1\",\"labels\":[\"bug\",\"$label\"]}],\"items\":[]}"
done <<'MAP'
agent:ready|Ready
agent:in-progress|In progress
agent:in-review|In review
agent:needs-human|Needs human
agent:failed|Failed
MAP

expect_output "an issue on the board with the right Status needs nothing" "" \
  run_plan '{"issues":[{"id":"I_1","labels":["agent:ready"]}],"items":[{"id":"PVTI_1","content":"I_1","state":"OPEN","status":"Ready"}]}'

expect_output "an issue on the board with a stale Status is set" \
  '{"action":"set","item":"PVTI_1","status":"In progress"}' \
  run_plan '{"issues":[{"id":"I_1","labels":["agent:in-progress"]}],"items":[{"id":"PVTI_1","content":"I_1","state":"OPEN","status":"Ready"}]}'

expect_output "an issue on the board with no Status yet is set" \
  '{"action":"set","item":"PVTI_1","status":"Triage"}' \
  run_plan '{"issues":[{"id":"I_1","labels":[]}],"items":[{"id":"PVTI_1","content":"I_1","state":"OPEN","status":null}]}'

expect_output "a closed ticket on the board moves to Done" \
  '{"action":"set","item":"PVTI_2","status":"Done"}' \
  run_plan '{"issues":[],"items":[{"id":"PVTI_2","content":"I_2","state":"CLOSED","status":"In review"}]}'

expect_output "a closed ticket already Done needs nothing" "" \
  run_plan '{"issues":[],"items":[{"id":"PVTI_2","content":"I_2","state":"CLOSED","status":"Done"}]}'

expect_output "an open item the sweep did not fetch is left alone" "" \
  run_plan '{"issues":[],"items":[{"id":"PVTI_3","content":"I_3","state":"OPEN","status":"Ready"},{"id":"PVTI_4","content":null,"state":null,"status":null}]}'

finish

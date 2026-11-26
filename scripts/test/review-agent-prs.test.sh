#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
agent_prs="$here/../review/agent-prs"

# The shape of GET repos/<r>/pulls (and, wrapped in an array, pulls/<n>).
pr() { # <number> <state> <head-ref> <head-repo> <head-sha>
  printf '{"number":%s,"state":"%s","head":{"ref":"%s","sha":"%s","repo":{"full_name":"%s"}},"base":{"ref":"main","sha":"b%s"}}' \
    "$1" "$2" "$3" "$5" "$4" "$1"
}
run() { echo "[$1]" | "$agent_prs" o/target; }

tab="$(printf '\t')"
expect_output "prints an open agent PR as number, head SHA, head ref, base ref, base SHA" \
  "4${tab}h4${tab}agent/issue-4${tab}main${tab}b4" \
  run "$(pr 4 open agent/issue-4 o/target h4)"
expect_output "keeps only the agent PRs, in input order" \
  "$(printf '9\th9\tagent/issue-2\tmain\tb9\n3\th3\tagent/issue-8\tmain\tb3')" \
  run "$(pr 9 open agent/issue-2 o/target h9),$(pr 5 open feature/x o/target h5),$(pr 3 open agent/issue-8 o/target h3)"
expect_output "a closed PR is not reviewed" "" run "$(pr 4 closed agent/issue-4 o/target h4)"
expect_output "a fork's agent branch is not reviewed" "" run "$(pr 4 open agent/issue-4 x/fork h4)"
expect_output "a deleted fork (no head repo) is not reviewed" "" \
  sh -c "echo '[{\"number\":4,\"state\":\"open\",\"head\":{\"ref\":\"agent/issue-4\",\"sha\":\"h4\",\"repo\":null},\"base\":{\"ref\":\"main\",\"sha\":\"b\"}}]' | '$agent_prs' o/target"
expect_output "a branch merely containing agent/issue- is not an agent branch" "" \
  run "$(pr 4 open x/agent/issue-4 o/target h4)"
expect_output "no open PRs prints nothing" "" run ""
expect_status "input that isn't a PR array fails" 1 sh -c "echo '{\"message\":\"Not Found\"}' | '$agent_prs' o/target"

finish

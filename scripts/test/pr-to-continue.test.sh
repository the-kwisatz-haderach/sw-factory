#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
pr_to_continue="$here/../implementer/pr-to-continue"

# Shaped like `gh pr list --head <branch> --state open --json number,isCrossRepository`.
expect_output "an open PR from this repo is continued" "12" \
  bash -c "echo '[{\"number\":12,\"isCrossRepository\":false}]' | '$pr_to_continue'"
expect_output "no open PR prints nothing" "" \
  bash -c "echo '[]' | '$pr_to_continue'"
expect_output "a fork's PR with the same branch name is ignored" "" \
  bash -c "echo '[{\"number\":15,\"isCrossRepository\":true}]' | '$pr_to_continue'"
expect_output "the repo's own PR wins over a fork's" "12" \
  bash -c "echo '[{\"number\":15,\"isCrossRepository\":true},{\"number\":12,\"isCrossRepository\":false}]' | '$pr_to_continue'"

finish

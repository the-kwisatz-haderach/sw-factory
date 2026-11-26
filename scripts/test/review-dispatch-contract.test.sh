#!/usr/bin/env bash
# The review backstop dispatches the stub with only a `pr` input, and the stub
# calls both tasks on every dispatch. The implementer takes a dispatch with no
# ticket as chaining, so without its `!github.event.inputs.pr` a backstop
# review would also claim a ticket, silently. This pins both sides of that.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
workflows="$here/../../.github/workflows"

# A job's block: from its key to the next job's.
job() { awk -v key="  $2:" '/^  [a-z-]+:$/ { in_job = ($0 == key) } in_job' "$workflows/$1"; }
implement="$(job implementer.yml implement)"
backstop="$(job review.yml backstop)"
review="$(job review.yml review)"

expect_status "the backstop dispatches with the \`pr\` input" 0 \
  grep -qF -- '-f "inputs[pr]=$number"' <<< "$backstop"
expect_status "the review job takes a dispatch with \`pr\` and no ticket" 0 \
  grep -qF '&& github.event.inputs.pr' <<< "$review"
expect_output "the implementer's gate and its concurrency group both refuse a \`pr\` dispatch" 2 \
  sh -c 'grep -cF "!github.event.inputs.pr"' <<< "$implement"

finish

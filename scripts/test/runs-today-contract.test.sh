#!/usr/bin/env bash
# runs-today counts the implementer's runs by two names in implementer.yml: the
# job (`implement`, which the jobs API reports as "<stub job> / implement") and
# its "Claim the ticket" step. The runs-today tests pin the script to those
# literals; this pins the workflow. A rename on either side would make the
# count read 0 and lift the daily cap without any error.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
workflow="$here/../../.github/workflows/implementer.yml"

# The `implement` job's block: from its key to the next job's.
job="$(awk '/^  [a-z-]+:$/ { in_job = ($0 == "  implement:") } in_job' "$workflow")"

expect_status "implementer.yml has an \`implement\` job" 0 test -n "$job"
expect_status "the \`implement\` job keeps its id as its name (no \`name:\`)" 1 \
  grep -qE '^    name:' <<< "$job"
expect_status "the \`implement\` job has a \"Claim the ticket\" step" 0 \
  grep -qx '      - name: Claim the ticket' <<< "$job"

finish

#!/usr/bin/env bash
# The review backstop dispatches the stub with only a `pr` input, and the stub
# calls both tasks on every dispatch. The implementer takes a dispatch with no
# ticket as chaining, so without its `!github.event.inputs.pr` a backstop
# review would also claim a ticket, silently. Rework dispatches with all three
# inputs, which the implementer must take and the review must not. This pins
# both sides of each, and the stub template's inputs. Review's rework counts
# rounds from the owners on its allowlist, standing in for the implementer's,
# so the two defaults must match. Handback acts on a PR close, which reaches it
# only if the stub forwards `closed`, and which must not share the review's
# group, where it would cancel a running review.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
workflows="$here/../../.github/workflows"

# A job's block: from its key to the next job's.
job() { awk -v key="  $2:" '/^  [a-z-]+:$/ { in_job = ($0 == key) } in_job' "$workflows/$1"; }
implement="$(job implementer.yml implement)"
backstop="$(job review.yml backstop)"
review="$(job review.yml review)"
rework="$(job review.yml rework)"
handback="$(job review.yml handback)"
stub="$here/../../templates/factory.yml"

expect_status "the backstop dispatches with the \`pr\` input" 0 \
  grep -qF -- '-f "inputs[pr]=$number"' <<< "$backstop"
expect_status "the review job takes a dispatch with \`pr\` and no ticket" 0 \
  grep -qF '&& github.event.inputs.pr' <<< "$review"
expect_output "the implementer's gate and its concurrency group both refuse a \`pr\` dispatch" 2 \
  sh -c 'grep -cF "!github.event.inputs.pr"' <<< "$implement"
expect_status "rework dispatches with ticket, PR and round" 0 \
  grep -qF -- '-f "inputs[ticket]=$TICKET" -f "inputs[pr]=$PR_NUMBER" -f "inputs[round]=$count"' <<< "$rework"
# The gate spreads a clause over lines and the group keeps it on one: compare
# with the whitespace collapsed.
expect_output "the implementer's gate and its concurrency group both take a rework dispatch" 2 \
  sh -c 'tr -s " \n" "  " | grep -oF "github.event.inputs.ticket && github.event.inputs.pr && github.event.inputs.round" | wc -l | tr -d " "' \
  <<< "$implement"
expect_status "the review job refuses a dispatch with a ticket" 0 \
  grep -qF '&& !github.event.inputs.ticket' <<< "$review"
for input in ticket pr round; do
  expect_status "the stub template declares the \`$input\` input" 0 \
    grep -qE "^      $input:$" "$stub"
done
expect_status "handback acts on a PR close" 0 \
  grep -qF "github.event.action == 'closed'" <<< "$handback"
expect_status "the stub template forwards PR closes" 0 \
  grep -qE '^    types: \[([a-z_]+, )*closed(, [a-z_]+)*\]$' \
  <<< "$(awk '/^  pull_request:$/ { getline; print }' "$stub")"
expect_status "a PR close gets a review group of its own run" 0 \
  grep -qF "review-\${{ (github.event.action != 'closed' && github.event.pull_request.number)" <<< "$review"

# The first `default:` after the `allowlist` input's key.
default() { awk '/^      allowlist:$/ { in_input = 1 } in_input && /^        default:/ { print; exit }' "$workflows/$1"; }
expect_status "both tasks default to the same allowlist" 0 \
  sh -c '[ -n "$1" ] && [ "$1" = "$2" ]' _ "$(default implementer.yml)" "$(default review.yml)"

finish

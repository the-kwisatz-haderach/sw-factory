#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
should_chain="$here/../implementer/should-chain"

# Arguments: route, runs claimed today before this one, the cap, the oldest
# ready ticket left (empty for none). Cap 4: this run is the 1st to the 4th.
expect_status "done, room under the cap and a ticket left chains" 0 "$should_chain" "done" 0 4 12
expect_status "needs-human chains" 0 "$should_chain" needs-human 2 4 12
expect_status "a changed ## Checks hand-back chains" 0 "$should_chain" checks-changed 2 4 12
expect_status "the 4th run of the day doesn't chain" 1 "$should_chain" "done" 3 4 12
expect_status "no ready ticket left doesn't chain" 1 "$should_chain" "done" 0 4 ""
expect_status "an unknown route doesn't chain" 1 "$should_chain" failed 0 4 12
expect_output "says why it didn't chain" "no: this run reached the daily cap of 4" "$should_chain" "done" 3 4 12

finish

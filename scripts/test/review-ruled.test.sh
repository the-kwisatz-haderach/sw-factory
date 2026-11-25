#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
ruled="$here/../review/ruled"

# The shape of GET repos/<r>/commits/<sha>/status: the latest status per context.
status() { printf '{"state":"x","statuses":[%s]}' "$1"; }
ci='{"context":"ci/test","state":"failure"}'

expect_status "a success verdict is ruled" 0 sh -c "echo '$(status "$ci,{\"context\":\"factory/review\",\"state\":\"success\"}")' | '$ruled'"
expect_status "a failure verdict is ruled" 0 sh -c "echo '$(status "{\"context\":\"factory/review\",\"state\":\"failure\"}")' | '$ruled'"
expect_status "an error status is not ruled" 1 sh -c "echo '$(status "{\"context\":\"factory/review\",\"state\":\"error\"}")' | '$ruled'"
expect_status "a pending status is not ruled" 1 sh -c "echo '$(status "{\"context\":\"factory/review\",\"state\":\"pending\"}")' | '$ruled'"
expect_status "no factory/review status is not ruled" 1 sh -c "echo '$(status "$ci")' | '$ruled'"
expect_status "another context's failure is not a verdict" 1 sh -c "echo '$(status "{\"context\":\"factory/review-x\",\"state\":\"failure\"}")' | '$ruled'"
expect_output "prints the verdict it found" "failure" sh -c "echo '$(status "{\"context\":\"factory/review\",\"state\":\"failure\"}")' | '$ruled'"

finish

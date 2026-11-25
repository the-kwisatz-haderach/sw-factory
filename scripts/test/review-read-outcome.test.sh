#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
read_outcome="$here/../review/read-outcome"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

echo '{"outcome": "pass", "reason": "Does what #23 asks; two nits."}' > "$tmp/pass.json"
expect_output "pass reads as pass" "pass" "$read_outcome" "$tmp/pass.json" "$tmp/d1.txt"
expect_output "pass describes the status" "Passed: Does what #23 asks; two nits." cat "$tmp/d1.txt"

echo '{"outcome": "pass"}' > "$tmp/bare-pass.json"
expect_output "a pass needs no reason" "pass" "$read_outcome" "$tmp/bare-pass.json" "$tmp/d2.txt"
expect_output "a bare pass still describes the status" "Passed" cat "$tmp/d2.txt"

echo '{"outcome": "fail", "reason": "Evidence shows no test run."}' > "$tmp/fail.json"
expect_output "fail reads as fail" "fail" "$read_outcome" "$tmp/fail.json" "$tmp/d3.txt"
expect_output "fail describes the status with its reason" "Failed: Evidence shows no test run." cat "$tmp/d3.txt"

long="$(printf 'x%.0s' $(seq 1 300))"
echo "{\"outcome\": \"fail\", \"reason\": \"$long\"}" > "$tmp/long.json"
"$read_outcome" "$tmp/long.json" "$tmp/d4.txt" >/dev/null 2>&1
expect_output "the description fits GitHub's 140-character limit" "140" sh -c "printf %s \"\$(cat '$tmp/d4.txt')\" | wc -m | tr -d ' '"

echo '{"outcome": "fail", "reason": " "}' > "$tmp/silent.json"
expect_status "a fail without a reason fails the run" 1 "$read_outcome" "$tmp/silent.json" "$tmp/d5.txt"
echo '{"outcome": "done"}' > "$tmp/unknown.json"
expect_status "an implementer outcome is not a verdict" 1 "$read_outcome" "$tmp/unknown.json" "$tmp/d6.txt"
echo 'nope' > "$tmp/garbled.json"
expect_status "an unreadable outcome file fails the run" 1 "$read_outcome" "$tmp/garbled.json" "$tmp/d7.txt"
expect_status "a missing outcome file fails the run" 1 "$read_outcome" "$tmp/absent.json" "$tmp/d8.txt"

finish

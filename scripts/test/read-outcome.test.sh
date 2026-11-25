#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
read_outcome="$here/../implementer/read-outcome"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

echo '{"outcome": "done"}' > "$tmp/done.json"
expect_output "done reads as done" "done" "$read_outcome" "$tmp/done.json" "$tmp/c1.md"

echo '{"outcome": "needs-human", "comment": "Should the cap be 4 or 5? I recommend 4."}' > "$tmp/nh.json"
expect_output "needs-human reads as needs-human" "needs-human" "$read_outcome" "$tmp/nh.json" "$tmp/c2.md"
expect_output "needs-human writes the agent's comment" "Should the cap be 4 or 5? I recommend 4." cat "$tmp/c2.md"

expect_status "a missing outcome file fails the run" 1 "$read_outcome" "$tmp/absent.json" "$tmp/c3.md"
echo 'not json' > "$tmp/garbled.json"
expect_status "an unreadable outcome file fails the run" 1 "$read_outcome" "$tmp/garbled.json" "$tmp/c4.md"
echo '{"outcome": "maybe"}' > "$tmp/unknown.json"
expect_status "an unknown outcome fails the run" 1 "$read_outcome" "$tmp/unknown.json" "$tmp/c5.md"
echo '{"outcome": "needs-human", "comment": "  "}' > "$tmp/silent.json"
expect_status "needs-human without a comment fails the run" 1 "$read_outcome" "$tmp/silent.json" "$tmp/c6.md"

finish

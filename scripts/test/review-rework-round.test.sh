#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
rework_round="$here/../review/rework-round"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# The shapes of GET repos/<r>/issues/<n>/events and of the statuses of every
# PR commit (GET repos/<r>/commits/<sha>/statuses, concatenated).
events() { printf '[%s]' "$1" > "$tmp/events.json"; }
statuses() { printf '[%s]' "$1" > "$tmp/statuses.json"; }
labeled() { printf '{"event":"labeled","label":{"name":"%s"},"actor":{"login":"%s"},"created_at":"%s"}' "$1" "$2" "$3"; }
review() { printf '{"context":"factory/review","state":"%s","created_at":"%s"}' "$1" "$2"; }
run() { "$rework_round" "the-owner,claude[bot]" 2 "$tmp/events.json" "$tmp/statuses.json"; }

events "$(labeled agent:ready the-owner 2026-11-01T10:00:00Z)"
statuses "$(review failure 2026-11-01T11:00:00Z)"
expect_output "the first fail since the owner's agent:ready is rework round 1" "rework 1" run

f1="$(review failure 2026-11-01T11:00:00Z)" f2="$(review failure 2026-11-01T12:00:00Z)" f3="$(review failure 2026-11-01T13:00:00Z)"
statuses "$f1,$f2"
expect_output "the second fail is rework round 2" "rework 2" run
statuses "$f1,$f2,$f3"
expect_output "the third fail goes to a human instead" "needs-human 3" run

events "$(labeled agent:ready the-owner 2026-11-01T10:00:00Z),$(labeled agent:ready 'github-actions[bot]' 2026-11-01T11:01:00Z),$(labeled agent:ready 'github-actions[bot]' 2026-11-01T12:01:00Z)"
expect_output "the workflow's own agent:ready doesn't reset the count" "needs-human 3" run

events "$(labeled agent:ready the-owner 2026-11-01T10:00:00Z),$(labeled agent:ready the-owner 2026-11-01T12:30:00Z)"
expect_output "the owner re-adding agent:ready resets it" "rework 1" run

events "$(labeled agent:ready 'claude[bot]' 2026-11-01T12:30:00Z),$(labeled agent:ready someone-else 2026-11-01T12:30:00Z),$(labeled agent:in-review the-owner 2026-11-01T12:30:00Z)"
expect_output "only an allowlisted human adding agent:ready resets it" "needs-human 3" run

events ""
statuses "$f1,$(review error 2026-11-01T12:00:00Z),$(review success 2026-11-01T12:10:00Z),{\"context\":\"ci/test\",\"state\":\"failure\",\"created_at\":\"2026-11-01T12:20:00Z\"}"
expect_output "only factory/review failures count" "rework 1" run

finish

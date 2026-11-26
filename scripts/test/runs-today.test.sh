#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
runs_today="$here/../implementer/runs-today"

# Shaped like the `jobs` of GET /repos/{owner}/{repo}/actions/runs/{id}/jobs,
# gathered across runs. A job a stub calls is named "<stub job> / <job>".
claimed='{"name": "implementer / implement", "steps": [
  {"name": "Pick the oldest ready ticket", "conclusion": "success", "started_at": "2026-11-26T08:00:01Z"},
  {"name": "Claim the ticket", "conclusion": "success", "started_at": "2026-11-26T08:00:05Z"}]}'
expect_output "one implementer job that claimed today counts" "1" \
  bash -c "echo '[$claimed]' | '$runs_today' 2026-11-26"

# No ticket to pick, or a pre-flight hand-back: the claim step is skipped.
unclaimed='{"name": "implementer / implement", "steps": [
  {"name": "Pick the oldest ready ticket", "conclusion": "success", "started_at": "2026-11-26T09:00:01Z"},
  {"name": "Claim the ticket", "conclusion": "skipped", "started_at": "2026-11-26T09:00:05Z"}]}'
expect_output "a run that claimed nothing doesn't count" "1" \
  bash -c "echo '[$claimed, $unclaimed]' | '$runs_today' 2026-11-26"
failed='{"name": "implementer / implement", "steps": [
  {"name": "Claim the ticket", "conclusion": "failure", "started_at": "2026-11-26T09:30:05Z"}]}'
expect_output "a failed claim doesn't count" "1" \
  bash -c "echo '[$claimed, $failed]' | '$runs_today' 2026-11-26"

# 23:59 UTC yesterday: a different day, though already today at UTC+1.
yesterday='{"name": "implementer / implement", "steps": [
  {"name": "Claim the ticket", "conclusion": "success", "started_at": "2026-11-25T23:59:30Z"}]}'
expect_output "a claim on the previous UTC day doesn't count" "1" \
  bash -c "echo '[$claimed, $yesterday]' | '$runs_today' 2026-11-26"

# Another job of the same stub run that happens to share the step name.
other='{"name": "review / review", "steps": [
  {"name": "Claim the ticket", "conclusion": "success", "started_at": "2026-11-26T10:00:05Z"}]}'
expect_output "only the implementer job counts" "1" \
  bash -c "echo '[$claimed, $other]' | '$runs_today' 2026-11-26"
renamed='{"name": "factory-implementer / implement", "steps": [
  {"name": "Claim the ticket", "conclusion": "success", "started_at": "2026-11-26T11:00:05Z"}]}'
expect_output "the stub's job name doesn't matter" "2" \
  bash -c "echo '[$claimed, $renamed]' | '$runs_today' 2026-11-26"
expect_output "no runs today counts zero" "0" bash -c "echo '[]' | '$runs_today' 2026-11-26"

finish

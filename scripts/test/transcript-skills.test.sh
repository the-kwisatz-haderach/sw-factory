#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
transcript_skills="$here/../transcript-skills"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# The shape of claude-code-action's execution file: a JSON array of SDK
# messages, tool calls as `tool_use` blocks in assistant messages.
cat > "$tmp/run.json" <<'JSON'
[
  {"type": "system", "subtype": "init", "skills": ["factory:tdd", "tdd"]},
  {"type": "assistant", "message": {"content": [
    {"type": "text", "text": "Reading the ticket."},
    {"type": "tool_use", "name": "Bash", "input": {"command": "cat .factory-run/ticket.md"}}
  ]}},
  {"type": "assistant", "message": {"content": [
    {"type": "tool_use", "name": "Skill", "input": {"skill": "factory:diagnosing-bugs"}}
  ]}},
  {"type": "assistant", "parent_tool_use_id": "x", "message": {"content": [
    {"type": "tool_use", "name": "Skill", "input": {"skill": "tdd", "args": "the NaN guard"}}
  ]}},
  {"type": "assistant", "message": {"content": [
    {"type": "tool_use", "name": "Skill", "input": {"skill": "factory:diagnosing-bugs"}}
  ]}},
  {"type": "result", "num_turns": 9}
]
JSON
expect_output "lists each skill called, once, in call order" \
  "$(printf '%s\n' factory:diagnosing-bugs tdd)" "$transcript_skills" "$tmp/run.json"

echo '[{"type": "result", "num_turns": 1}]' > "$tmp/none.json"
expect_output "a run that called no skill prints nothing" "" "$transcript_skills" "$tmp/none.json"
expect_status "a run that called no skill succeeds" 0 "$transcript_skills" "$tmp/none.json"

expect_status "a missing transcript fails" 1 "$transcript_skills" "$tmp/absent.json"
echo 'not json' > "$tmp/garbled.json"
expect_status "an unreadable transcript fails" 1 "$transcript_skills" "$tmp/garbled.json"

finish

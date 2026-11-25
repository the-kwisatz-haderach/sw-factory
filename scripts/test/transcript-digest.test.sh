#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
digest="$here/../transcript-digest"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/run.json" <<'JSON'
[
  {"type": "system", "subtype": "init", "model": "claude-sonnet-5-5"},
  {"type": "assistant", "message": {"content": [
    {"type": "tool_use", "name": "Skill", "input": {"skill": "factory:tdd"}},
    {"type": "tool_use", "name": "Bash", "input": {"command": "npm test"}},
    {"type": "tool_use", "name": "Bash", "input": {"command": "git commit -m x"}}
  ]}},
  {"type": "result", "subtype": "success", "num_turns": 14, "duration_ms": 20679,
   "total_cost_usd": 0.1263157,
   "permission_denials": [{"tool_name": "Bash", "tool_input": {"command": "git push"}}]}
]
JSON
expected="$(printf '%s\n' \
  'Model: claude-sonnet-5-5' \
  'Result: success, 14 turns, 20.7 s, $0.13' \
  'Tool calls: Bash 2, Skill 1' \
  'Skills: factory:tdd' \
  'Permission denials: Bash 1')"
expect_output "digests a run: model, result, tools, skills, denials" "$expected" "$digest" "$tmp/run.json"

echo '[{"type": "system", "subtype": "init"}]' > "$tmp/cut.json"
expected="$(printf '%s\n' 'Model: unknown' 'Result: none (the run ended without one)' 'Tool calls: none' 'Skills: none' 'Permission denials: none')"
expect_output "a run cut short says so" "$expected" "$digest" "$tmp/cut.json"

expect_status "a missing transcript fails" 1 "$digest" "$tmp/absent.json"

finish

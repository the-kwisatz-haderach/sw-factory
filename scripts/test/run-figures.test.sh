#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
figures="$here/../run-figures"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/run.json" <<'JSON'
[
  {"type": "system", "subtype": "init", "model": "claude-sonnet-5-5"},
  {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Bash", "input": {}}]}},
  {"type": "result", "subtype": "success", "num_turns": 14, "duration_ms": 20679,
   "total_cost_usd": 0.1263157,
   "usage": {"input_tokens": 1234, "output_tokens": 5678,
             "cache_read_input_tokens": 1234567, "cache_creation_input_tokens": 89012}}
]
JSON
expected="$(printf '%s\n' \
  '- **Turns:** 14 (`success`) in 20.7 s' \
  '- **Tokens:** 1,234 input, 5,678 output, 1,234,567 cache read, 89,012 cache write' \
  '- **Cost:** $0.13')"
expect_output "reads turns, duration, tokens and cost from the result" "$expected" "$figures" "$tmp/run.json"

cat > "$tmp/long.json" <<'JSON'
[{"type": "result", "subtype": "error_max_turns", "num_turns": 80, "duration_ms": 1843000,
  "total_cost_usd": 4.5, "usage": {"input_tokens": 0, "output_tokens": 999}}]
JSON
expected="$(printf '%s\n' \
  '- **Turns:** 80 (`error_max_turns`) in 30 min 43 s' \
  '- **Tokens:** 0 input, 999 output, 0 cache read, 0 cache write' \
  '- **Cost:** $4.50')"
expect_output "a long run reads in minutes, and missing counts as 0" "$expected" "$figures" "$tmp/long.json"

echo '[{"type": "system", "subtype": "init"}]' > "$tmp/cut.json"
expect_output "a run cut short before its result says so" \
  "- **Turns, tokens and cost:** not recorded (the agent ended without a result, e.g. on a timeout)" \
  "$figures" "$tmp/cut.json"

expect_output "a missing transcript says so" "- **Turns, tokens and cost:** no transcript" "$figures" "$tmp/absent.json"
expect_status "a missing transcript doesn't fail" 0 "$figures" "$tmp/absent.json"
echo '{"not": "an array"}' > "$tmp/odd.json"
expect_output "a file that isn't an execution file reads as no transcript" \
  "- **Turns, tokens and cost:** no transcript" "$figures" "$tmp/odd.json"

finish

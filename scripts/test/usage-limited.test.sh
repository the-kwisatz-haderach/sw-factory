#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
usage_limited="$here/../usage-limited"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# claude-code-action's execution file: a JSON array of the run's SDK messages.
# The agent's last own message carries the error the run ended on.
cat > "$tmp/limited.json" <<'JSON'
[
  {"type": "system", "subtype": "init", "session_id": "s1"},
  {"type": "assistant", "parent_tool_use_id": null, "session_id": "s1",
   "message": {"role": "assistant", "content": [{"type": "text", "text": "Reading the ticket."}]}},
  {"type": "rate_limit_event", "rate_limit_info": {"status": "rejected", "rateLimitType": "five_hour", "resetsAt": 1795000000}, "session_id": "s1"},
  {"type": "assistant", "parent_tool_use_id": null, "error": "rate_limit", "session_id": "s1",
   "message": {"role": "assistant", "content": [{"type": "text", "text": "You've hit your limit"}]}},
  {"type": "result", "subtype": "success", "is_error": true, "result": "You've hit your limit", "session_id": "s1"}
]
JSON
expect_status "a run that ended on a rate_limit is usage-limited" 0 "$usage_limited" "$tmp/limited.json"

# A 429 the SDK retried (an api_retry system message) is not how the run ended.
cat > "$tmp/retried.json" <<'JSON'
[
  {"type": "system", "subtype": "api_retry", "attempt": 1, "max_retries": 10, "retry_delay_ms": 500, "error_status": 429, "error": "rate_limit"},
  {"type": "assistant", "parent_tool_use_id": null,
   "message": {"content": [{"type": "text", "text": "Done."}]}},
  {"type": "result", "subtype": "success", "is_error": false}
]
JSON
expect_status "a retried 429 the run got past is not" 1 "$usage_limited" "$tmp/retried.json"

# A sub-agent's limit, last in the file, is not the agent's own ending.
cat > "$tmp/subagent.json" <<'JSON'
[
  {"type": "assistant", "parent_tool_use_id": null,
   "message": {"content": [{"type": "tool_use", "name": "Agent"}]}},
  {"type": "assistant", "parent_tool_use_id": "toolu_1", "error": "rate_limit",
   "message": {"content": [{"type": "text", "text": "You've hit your limit"}]}}
]
JSON
expect_status "a sub-agent's rate_limit is not" 1 "$usage_limited" "$tmp/subagent.json"

cat > "$tmp/other.json" <<'JSON'
[
  {"type": "assistant", "parent_tool_use_id": null, "message": {"content": [{"type": "tool_use", "name": "Bash"}]}},
  {"type": "user", "message": {"content": [{"type": "tool_result", "content": "grep: \"error\": \"rate_limit\""}]}},
  {"type": "assistant", "parent_tool_use_id": null, "error": "authentication_failed", "message": {"content": []}},
  {"type": "result", "subtype": "error_during_execution", "is_error": true}
]
JSON
expect_status "another error, or the phrase in tool output, is not" 1 "$usage_limited" "$tmp/other.json"

expect_status "a missing execution file is not" 1 "$usage_limited" "$tmp/absent.json"
echo 'truncated [' > "$tmp/garbled.json"
expect_status "an unreadable execution file is not" 1 "$usage_limited" "$tmp/garbled.json"

finish

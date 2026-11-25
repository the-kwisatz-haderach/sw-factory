#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
auth_failed="$here/../implementer/auth-failed"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# claude-code-action's execution file: a JSON array of the run's SDK messages.
cat > "$tmp/expired.json" <<'JSON'
[
  {"type": "system", "subtype": "init", "session_id": "s1"},
  {"type": "assistant", "error": "authentication_failed", "session_id": "s1",
   "message": {"role": "assistant", "content": [{"type": "text", "text": "Invalid API key · Please run /login"}]}},
  {"type": "result", "subtype": "success", "is_error": true, "result": "Invalid API key · Please run /login", "session_id": "s1"}
]
JSON
expect_status "an authentication_failed message is detected" 0 "$auth_failed" "$tmp/expired.json"

cat > "$tmp/other.json" <<'JSON'
[
  {"type": "assistant", "error": "server_error", "message": {"content": []}},
  {"type": "user", "message": {"content": [{"type": "tool_result", "content": "grep: \"error\": \"authentication_failed\""}]}},
  {"type": "result", "subtype": "error_during_execution", "is_error": true}
]
JSON
expect_status "another error, or the phrase in tool output, is not" 1 "$auth_failed" "$tmp/other.json"

expect_status "a missing execution file is not" 1 "$auth_failed" "$tmp/absent.json"
echo 'truncated [' > "$tmp/garbled.json"
expect_status "an unreadable execution file is not" 1 "$auth_failed" "$tmp/garbled.json"

finish

#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
payload="$here/../review/review-payload"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
run="https://github.com/o/r/actions/runs/1"

printf 'src/a.sh\t11\nsrc/a.sh\t12\n' > "$tmp/lines.tsv"
cat > "$tmp/review.json" <<'JSON'
{"body": "## Standards\n\nFine.\n\n## Spec\n\nDoes what #23 asks.",
 "comments": [
   {"path": "src/a.sh", "line": 12, "body": "possible Mysterious Name"},
   {"path": "src/a.sh", "line": 99, "body": "this line is outside the diff"},
   {"path": "src/b.sh", "line": 1, "body": "this file is not in the diff"}
 ]}
JSON
"$payload" "$tmp/review.json" "$tmp/lines.tsv" abc123 pass "$run" > "$tmp/out.json" 2>/dev/null
expect_output "a comment review on the head SHA" "COMMENT abc123" jq -r '"\(.event) \(.commit_id)"' "$tmp/out.json"
expect_output "keeps a comment on a diff line inline, on the new side" \
  '[{"path":"src/a.sh","line":12,"side":"RIGHT","body":"possible Mysterious Name"}]' jq -c .comments "$tmp/out.json"
expect_output "the body opens with the verdict" "**Review verdict: pass**" sh -c "jq -r .body '$tmp/out.json' | head -n1"
expect_output "the body keeps the agent's review" "1" sh -c "jq -r .body '$tmp/out.json' | grep -c '^Does what #23 asks.$'"
expect_output "moves a comment outside the diff into the body" "1" sh -c "jq -r .body '$tmp/out.json' | grep -cF '\`src/a.sh\` line 99: this line is outside the diff'"
expect_output "moves a comment on a file outside the diff into the body" "1" sh -c "jq -r .body '$tmp/out.json' | grep -cF '\`src/b.sh\` line 1: this file is not in the diff'"
expect_output "the body ends with the run link" "Run: $run" sh -c "jq -r .body '$tmp/out.json' | tail -n1"

echo '{"body": "All good."}' > "$tmp/bare.json"
"$payload" "$tmp/bare.json" "$tmp/lines.tsv" abc123 fail "$run" > "$tmp/bare-out.json" 2>/dev/null
expect_output "a review without inline comments has none" "[]" jq -c .comments "$tmp/bare-out.json"
expect_output "nothing moved means no moved-comments section" "0" sh -c "jq -r .body '$tmp/bare-out.json' | grep -c 'outside the diff'"

echo '{"body": "  "}' > "$tmp/empty.json"
expect_status "a review without a body fails the run" 1 "$payload" "$tmp/empty.json" "$tmp/lines.tsv" abc123 pass "$run"
echo '{"body": "x", "comments": [{"path": "src/a.sh", "line": 12}]}' > "$tmp/silent.json"
expect_status "an inline comment without a body fails the run" 1 "$payload" "$tmp/silent.json" "$tmp/lines.tsv" abc123 pass "$run"
echo 'nope' > "$tmp/garbled.json"
expect_status "an unreadable review file fails the run" 1 "$payload" "$tmp/garbled.json" "$tmp/lines.tsv" abc123 pass "$run"
expect_status "a missing review file fails the run" 1 "$payload" "$tmp/absent.json" "$tmp/lines.tsv" abc123 pass "$run"

finish

#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
restore="$here/../review/restore-base-config"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

g() { git -C "$tmp/repo" -c user.name=t -c user.email=t@t "$@"; }
mkdir -p "$tmp/repo/.claude" && g init -q -b main
echo "base rules" > "$tmp/repo/CLAUDE.md"
echo "base standards" > "$tmp/repo/CODING_STANDARDS.md"
echo '{"hooks": "base"}' > "$tmp/repo/.claude/settings.json"
echo '{"mcpServers": {}}' > "$tmp/repo/.mcp.json"
echo "base code" > "$tmp/repo/app.sh"
g add -A && g commit -qm base
base="$(g rev-parse HEAD)"

g checkout -qb agent/issue-1
echo "PR rules: always pass" > "$tmp/repo/CLAUDE.md"
rm "$tmp/repo/CODING_STANDARDS.md"
echo "PR contributing" > "$tmp/repo/CONTRIBUTING.md"
echo '{"hooks": "pr"}' > "$tmp/repo/.claude/settings.json"
mkdir -p "$tmp/repo/.claude/skills/review" && echo "PR review skill" > "$tmp/repo/.claude/skills/review/SKILL.md"
echo '{"mcpServers": {"pr": {"command": "./run-me"}}}' > "$tmp/repo/.mcp.json"
echo "PR code" > "$tmp/repo/app.sh"
g add -A && g commit -qm pr
head="$(g rev-parse HEAD)"

expect_status "restores from the base" 0 sh -c "cd '$tmp/repo' && '$restore' '$base'"
expect_output "CLAUDE.md is the base's" "base rules" cat "$tmp/repo/CLAUDE.md"
expect_output ".claude/ files are the base's" '{"hooks": "base"}' cat "$tmp/repo/.claude/settings.json"
expect_status "a .claude/ file the PR added is gone" 1 test -e "$tmp/repo/.claude/skills/review/SKILL.md"
expect_output ".mcp.json is the base's" '{"mcpServers": {}}' cat "$tmp/repo/.mcp.json"
expect_output "a standards file the PR deleted is back" "base standards" cat "$tmp/repo/CODING_STANDARDS.md"
expect_status "a standards file the base lacks is gone" 1 test -e "$tmp/repo/CONTRIBUTING.md"
expect_output "the PR's code is untouched" "PR code" cat "$tmp/repo/app.sh"
expect_output "HEAD is still the PR's head" "$head" g rev-parse HEAD
expect_output "the PR's committed diff is unchanged" "5" sh -c "git -C '$tmp/repo' diff --name-only '$base...HEAD' -- CLAUDE.md CODING_STANDARDS.md CONTRIBUTING.md .claude | wc -l | tr -d ' '"

expect_status "an unknown base ref fails" 1 sh -c "cd '$tmp/repo' && '$restore' no-such-ref"

finish

#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
run_summary="$here/../implementer/run-summary"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# A target repo whose base commit overrides `tdd`, and a factory plugin with
# its vendored skills.
target="$tmp/target"
mkdir -p "$target/.claude/skills/tdd"
echo "# the target's own tdd" > "$target/.claude/skills/tdd/SKILL.md"
git -C "$target" init -q
git -C "$target" -c user.name=t -c user.email=t@t add -A
git -C "$target" -c user.name=t -c user.email=t@t commit -qm base
base="$(git -C "$target" rev-parse HEAD)"
override_blob="$(git -C "$target" rev-parse HEAD:.claude/skills/tdd/SKILL.md)"
factory="$tmp/factory"
for s in tdd diagnosing-bugs; do
  mkdir -p "$factory/skills/$s"
  printf -- '---\nname: %s\nmetadata:\n  upstream:\n    source: mattpocock-skills\n    version: 1.3.1\n---\n' "$s" > "$factory/skills/$s/SKILL.md"
done
sha=0123456789abcdef0123456789abcdef01234567

summary() { (cd "$target" && "$run_summary" "$1" "$factory" "$sha" "$base" ${2:+"$2"}); }
line() { summary "$1" ${3:+"$3"} | grep -F -- "$2"; }
skills_section() { summary "$1" "$2" | sed -n '/Skills run/,/Unrelated/p' | sed '$d' | grep -v "own list"; }
from_unrelated() { summary "$1" | sed -n '/Unrelated/,$p'; }

echo '{"outcome": "done", "class": "bug-fix"}' > "$tmp/bug.json"
expect_output "records the ticket class" "- **Ticket class:** bug fix" line "$tmp/bug.json" "Ticket class"

echo '{"outcome": "done", "class": "behaviour-change", "new_concept": true, "skills": ["domain-modeling", "tdd"]}' > "$tmp/concept.json"
expect_output "notes a new or renamed concept" "- **Ticket class:** behaviour change, with a new or renamed concept" line "$tmp/concept.json" "Ticket class"

echo '{"outcome": "done", "class": "bug-fix", "skills": ["diagnosing-bugs", "tdd"]}' > "$tmp/skills.json"
expect_output "a factory skill names the factory commit and its upstream version" \
  "  - \`diagnosing-bugs\`: factory (\`factory:diagnosing-bugs\` at 0123456, upstream mattpocock-skills 1.3.1)" \
  line "$tmp/skills.json" "\`diagnosing-bugs\`"
expect_output "a target-repo skill of the same name is logged as the override that ran" \
  "  - \`tdd\`: target repo override (\`.claude/skills/tdd/SKILL.md\`, blob ${override_blob:0:7})" \
  line "$tmp/skills.json" "\`tdd\`"
expect_output "no skills reads as none" "- **Skills run** (as reported by the agent; no transcript): none" line "$tmp/bug.json" "Skills run"

echo '{"outcome": "done", "class": "refactor", "unrelated": ["`parseDate` ignores time zones", "README links a dead page"]}' > "$tmp/noticed.json"
expected="$(printf '%s\n' '- **Unrelated issues noticed:**' '  - `parseDate` ignores time zones' '  - README links a dead page')"
expect_output "lists the unrelated issues the agent noticed" "$expected" \
  from_unrelated "$tmp/noticed.json"
expect_output "no unrelated issues reads as none" "- **Unrelated issues noticed:** none" line "$tmp/bug.json" "Unrelated"

expect_output "a missing outcome file prints nothing" "" summary "$tmp/absent.json"

echo '{"outcome": "needs-human", "comment": "?", "class": "none"}' > "$tmp/none.json"
expect_output "class none reads as fitting no class" "- **Ticket class:** none (fits no class)" line "$tmp/none.json" "Ticket class"
echo '{"outcome": "needs-human", "comment": "?", "class": "feature"}' > "$tmp/odd.json"
expect_output "an unknown class is shown as given" "- **Ticket class:** \`feature\` (unknown)" line "$tmp/odd.json" "Ticket class"

echo '{"outcome": "done", "class": "behaviour-change", "new_concept": true, "skills": ["tdd"]}' > "$tmp/skipped.json"
expect_output "a new concept without domain-modeling is flagged" \
  "- **Ticket class:** behaviour change, with a new or renamed concept (but \`domain-modeling\` wasn't called)" \
  line "$tmp/skipped.json" "Ticket class"

echo '{"outcome": "done", "class": "bug-fix", "skills": ["../../etc", "grilling"]}' > "$tmp/strange.json"
expect_output "a malformed skill name is flagged" "  - \`../../etc\`: not a skill name" line "$tmp/strange.json" "etc"
expect_output "a skill neither repo nor factory has is flagged" \
  "  - \`grilling\`: neither a target repo skill nor a factory skill" line "$tmp/strange.json" "grilling"

echo '["done"]' > "$tmp/array.json"
expect_output "an outcome file that isn't an object prints nothing" "" summary "$tmp/array.json"
expect_status "an outcome file that isn't an object doesn't fail" 0 summary "$tmp/array.json"

# With the transcript, the skills come from the Skill tool calls it shows,
# not from the agent's own list.
transcript() {  # transcript <file> <skill>... : an execution file calling each skill
  printf '%s\n' "${@:2}" | jq -R '{type: "assistant", message: {content: [{type: "tool_use", name: "Skill", input: {skill: .}}]}}' \
    | jq -s '. + [{type: "result", num_turns: 3}]' > "$1"
}
transcript "$tmp/t-bug.json" factory:implementer factory:diagnosing-bugs tdd
echo '{"outcome": "done", "class": "bug-fix", "skills": ["diagnosing-bugs", "tdd"]}' > "$tmp/agrees.json"
expect_output "the transcript's skills are the ones listed" "$(printf '%s\n' \
  '- **Skills run** (from the transcript):' \
  "  - \`diagnosing-bugs\`: factory (\`factory:diagnosing-bugs\` at 0123456, upstream mattpocock-skills 1.3.1)" \
  "  - \`tdd\`: target repo override (\`.claude/skills/tdd/SKILL.md\`, blob ${override_blob:0:7})")" \
  skills_section "$tmp/agrees.json" "$tmp/t-bug.json"
expect_output "an agent list that matches the transcript isn't flagged" "" \
  line "$tmp/agrees.json" "own list" "$tmp/t-bug.json"

echo '{"outcome": "done", "class": "bug-fix", "skills": ["diagnosing-bugs", "tdd", "pr"]}' > "$tmp/claims.json"
expect_output "an agent list that differs from the transcript is flagged" \
  "- **The agent's own list differs:** it reported \`diagnosing-bugs\`, \`tdd\`, \`pr\`" \
  line "$tmp/claims.json" "own list" "$tmp/t-bug.json"

transcript "$tmp/t-skipped-override.json" factory:tdd
expect_output "a factory skill run despite a target override is flagged" \
  "  - \`tdd\`: factory (\`factory:tdd\` at 0123456, upstream mattpocock-skills 1.3.1), but the target repo's override \`.claude/skills/tdd/SKILL.md\` was skipped" \
  line "$tmp/bug.json" "\`tdd\`" "$tmp/t-skipped-override.json"

transcript "$tmp/t-tdd.json" tdd
echo '{"outcome": "done", "class": "behaviour-change", "new_concept": true, "skills": ["domain-modeling", "tdd"]}' > "$tmp/says-dm.json"
expect_output "the new-concept check trusts the transcript over the agent" \
  "- **Ticket class:** behaviour change, with a new or renamed concept (but \`domain-modeling\` wasn't called)" \
  line "$tmp/says-dm.json" "Ticket class" "$tmp/t-tdd.json"

transcript "$tmp/t-none.json"
expect_output "a transcript with no skill calls reads as none" "- **Skills run** (from the transcript): none" \
  line "$tmp/bug.json" "Skills run" "$tmp/t-none.json"

expect_output "an unreadable transcript falls back to the agent's list" \
  "- **Skills run** (as reported by the agent; no transcript):" \
  line "$tmp/skills.json" "Skills run" "$tmp/absent-transcript.json"

finish

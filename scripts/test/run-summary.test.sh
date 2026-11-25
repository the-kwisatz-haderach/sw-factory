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

summary() { (cd "$target" && "$run_summary" "$1" "$factory" "$sha" "$base"); }
line() { summary "$1" | grep -F -- "$2"; }
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
expect_output "no skills reads as none" "- **Skills run:** none" line "$tmp/bug.json" "Skills run"

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

finish

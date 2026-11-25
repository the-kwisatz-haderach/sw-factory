#!/usr/bin/env bash
# The class list is data for the scripts and prose for the agent; this keeps
# the two in step.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
classes="$here/../implementer/ticket-classes"
skill="$here/../../skills/implementer/SKILL.md"

while IFS=$'\t' read -r class label; do
  [ -n "$label" ] || fail "ticket-classes: '$class' has no label"
  expect_status "the implementer skill's class table lists \`$class\`" 0 \
    grep -qE "^\| .* \| \`$class\` \|" "$skill"
done < <(grep -v '^#' "$classes")

# Every class in the skill's table, except `none`, is in the file.
while read -r class; do
  expect_status "ticket-classes lists the skill's \`$class\`" 0 \
    grep -qx -- "$class" <(grep -v '^#' "$classes" | cut -f1)
done < <(grep -oE "^\| [^|]+ \| \`[a-z-]+\` \|" "$skill" | sed -E 's/.*`([a-z-]+)`.*/\1/' | grep -vx none)

finish

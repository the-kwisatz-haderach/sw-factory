#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
check="$here/../implementer/check-pr-body"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/good.md" <<'MD'
Closes #23

## Summary

sketch

## Evidence

- before/after

## Merge Danger

**Door:** two-way
MD
expect_status "a complete body passes" 0 "$check" "$tmp/good.md" 23

sed 's/^Closes #23$/Fixes the thing/' "$tmp/good.md" > "$tmp/no-closes.md"
expect_status "a body without Closes #<n> fails" 1 "$check" "$tmp/no-closes.md" 23

expect_status "Closes for another ticket fails" 1 "$check" "$tmp/good.md" 2
sed 's/^Closes #23$/Closes #230/' "$tmp/good.md" > "$tmp/prefix.md"
expect_status "Closes #230 does not satisfy ticket 23" 1 "$check" "$tmp/prefix.md" 23

for heading in "Summary" "Evidence" "Merge Danger"; do
  grep -v "^## ${heading}$" "$tmp/good.md" > "$tmp/no-heading.md"
  expect_status "a body without ## ${heading} fails" 1 "$check" "$tmp/no-heading.md" 23
done
sed 's/^## Evidence$/Evidence is below./' "$tmp/good.md" > "$tmp/prose.md"
expect_status "Evidence mentioned in prose is not a heading" 1 "$check" "$tmp/prose.md" 23

expect_status "a missing file fails" 1 "$check" "$tmp/absent.md" 23

finish

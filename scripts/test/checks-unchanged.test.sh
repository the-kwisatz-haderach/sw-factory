#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
check="$here/../implementer/checks-unchanged"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/base.md" <<'MD'
# Project

Intro.

## Checks

```bash
npm run lint
npm test
```

## Conventions

Use tabs.
MD

expect_status "an untouched CLAUDE.md passes" 0 "$check" "$tmp/base.md" "$tmp/base.md"

sed 's/^Use tabs.$/Use spaces./' "$tmp/base.md" > "$tmp/elsewhere.md"
expect_status "a change outside ## Checks passes" 0 "$check" "$tmp/base.md" "$tmp/elsewhere.md"

grep -v '^npm test$' "$tmp/base.md" > "$tmp/dropped.md"
expect_status "a dropped check command fails" 1 "$check" "$tmp/base.md" "$tmp/dropped.md"

cat > "$tmp/fenced.md" <<'MD'
## Checks

```bash
## the slow ones last
npm run lint
npm test
```

### Notes

Run them all.

## Conventions
MD
sed 's/^npm test$/npm test -- --bail/' "$tmp/fenced.md" > "$tmp/fenced-changed.md"
expect_status "a fenced ## comment does not end the section" 1 "$check" "$tmp/fenced.md" "$tmp/fenced-changed.md"
sed 's/^Run them all.$/Run some./' "$tmp/fenced.md" > "$tmp/sub-changed.md"
expect_status "a ### subsection belongs to the section" 1 "$check" "$tmp/fenced.md" "$tmp/sub-changed.md"

expect_status "a deleted CLAUDE.md fails" 1 "$check" "$tmp/base.md" "$tmp/absent.md"

finish

#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
section="$here/../implementer/checks-section"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/with.md" <<'MD'
# Project

## Checks

```bash
npm test
```

## Conventions
MD
expect_output "prints the section up to the next heading" "## Checks

\`\`\`bash
npm test
\`\`\`" "$section" "$tmp/with.md"

cat > "$tmp/without.md" <<'MD'
# Project

## Conventions

Use tabs.
MD
expect_status "a CLAUDE.md without ## Checks fails" 1 "$section" "$tmp/without.md"
expect_status "a missing CLAUDE.md fails" 1 "$section" "$tmp/absent.md"

cat > "$tmp/fenced.md" <<'MD'
# Project

```markdown
## Checks
npm test
```
MD
expect_status "a ## Checks inside a code fence does not count" 1 "$section" "$tmp/fenced.md"

printf '# Project\n\n### Checks\n\nnpm test\n' > "$tmp/h3.md"
expect_status "a ### Checks heading does not count" 1 "$section" "$tmp/h3.md"

finish

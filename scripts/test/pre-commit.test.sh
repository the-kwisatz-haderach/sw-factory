#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
hook="$here/../../.githooks/pre-commit"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# A repo with the real hook, whose checks do what the script tests do: build
# a scratch repo of their own and commit to it.
repo="$tmp/repo"
git init -q "$repo"
# In the repo's config, not `-c` per command: the hook's own commit needs it.
git -C "$repo" config user.email t@example.com
git -C "$repo" config user.name t
mkdir -p "$repo/.githooks" "$repo/scripts"
cp "$hook" "$repo/.githooks/pre-commit"
cat > "$repo/scripts/check" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
scratch="$(mktemp -d)"
git init -q "$scratch"
echo probe > "$scratch/probe.md"
git -C "$scratch" add probe.md
rm -rf "$scratch"
EOF
chmod +x "$repo/scripts/check"
echo one > "$repo/tracked.md"
git -C "$repo" add -A
git -C "$repo" commit -qm init --no-verify
git -C "$repo" config core.hooksPath .githooks

echo two >> "$repo/tracked.md"
own_files="$(printf '.githooks/pre-commit\nscripts/check\ntracked.md')"
expect_status "commit -a succeeds when the checks run git in a repo of their own" 0 \
  git -C "$repo" commit -qam change
expect_output "the commit holds only the repo's own files" \
  "$own_files" \
  git -C "$repo" ls-tree -r --name-only HEAD
expect_output "the index holds only the repo's own files" \
  "$own_files" \
  git -C "$repo" ls-files

finish

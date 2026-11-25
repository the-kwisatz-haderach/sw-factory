#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
check="$here/../check-conventions"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# script <path> <content>: an executable file under the fixture root.
script() { mkdir -p "$(dirname "$tmp/$1")"; printf '%s\n' "$2" > "$tmp/$1"; chmod +x "$tmp/$1"; }
good_script='#!/usr/bin/env bash
# Usage: tool <arg>
set -euo pipefail
echo hi'
good_test='#!/usr/bin/env bash
. "$here/lib.sh"
finish'
script scripts/task/tool "$good_script"
script scripts/test/tool.test.sh "$good_test"
printf 'data\n' > "$tmp/scripts/task/table"
expect_status "a tree that follows the conventions passes" 0 "$check" "$tmp"

script scripts/task/no-usage '#!/usr/bin/env bash
set -euo pipefail'
expect_output "a script without a usage header is named" \
  "scripts/task/no-usage: no '# Usage:' line in its header" "$check" "$tmp"
rm "$tmp/scripts/task/no-usage"

script scripts/task/lax '#!/usr/bin/env bash
# Usage: lax
set -e'
expect_output "a script without strict mode is named" \
  "scripts/task/lax: no 'set -euo pipefail'" "$check" "$tmp"
rm "$tmp/scripts/task/lax"

script scripts/task/inert "$good_script"; chmod -x "$tmp/scripts/task/inert"
expect_output "a script that isn't executable is named" \
  "scripts/task/inert: has a shebang but isn't executable" "$check" "$tmp"
rm "$tmp/scripts/task/inert"

chmod +x "$tmp/scripts/task/table"
expect_output "an executable data file is named" \
  "scripts/task/table: executable but has no shebang" "$check" "$tmp"
chmod -x "$tmp/scripts/task/table"

script scripts/test/quiet.test.sh "$good_test"; chmod -x "$tmp/scripts/test/quiet.test.sh"
expect_output "a test file that isn't executable is named" \
  "scripts/test/quiet.test.sh: has a shebang but isn't executable" "$check" "$tmp"
rm "$tmp/scripts/test/quiet.test.sh"

script scripts/test/bare.test.sh '#!/usr/bin/env bash
echo ok'
expect_output "a test file that skips lib.sh and finish is named" \
  "$(printf '%s\n' "scripts/test/bare.test.sh: doesn't source lib.sh" "scripts/test/bare.test.sh: doesn't end with 'finish'")" \
  "$check" "$tmp"
expect_status "any violation fails" 1 "$check" "$tmp"

finish

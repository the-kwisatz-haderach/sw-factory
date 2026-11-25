#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
. "$here/lib.sh"
diff_lines="$here/../review/diff-lines"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/change.diff" <<'DIFF'
diff --git a/src/a.sh b/src/a.sh
index 1111111..2222222 100644
--- a/src/a.sh
+++ b/src/a.sh
@@ -10,3 +10,4 @@ fn() {
 keep ten
-gone
+new eleven
+new twelve
 keep thirteen
\ No newline at end of file
@@ -40,2 +41,2 @@
-old
+forty-one
 forty-two
diff --git a/docs/new.md b/docs/new.md
new file mode 100644
--- /dev/null
+++ b/docs/new.md
@@ -0,0 +1,2 @@
+one
+++ two, not a header
diff --git a/old.txt b/old.txt
deleted file mode 100644
--- a/old.txt
+++ /dev/null
@@ -1 +0,0 @@
-bye
DIFF
want="$(printf '%s\n' \
  $'src/a.sh\t10' $'src/a.sh\t11' $'src/a.sh\t12' $'src/a.sh\t13' \
  $'src/a.sh\t41' $'src/a.sh\t42' \
  $'docs/new.md\t1' $'docs/new.md\t2')"
expect_output "lists added and context lines on the new side, per file" "$want" sh -c "'$diff_lines' < '$tmp/change.diff'"
# git ends a `+++` header with a tab when the path holds a space.
printf 'diff --git a/my notes.md b/my notes.md\n--- a/my notes.md\n+++ b/my notes.md\t\n@@ -1 +1 @@\n-a\n+b\n' > "$tmp/space.diff"
expect_output "a path with a space is read whole" $'my notes.md\t1' sh -c "'$diff_lines' < '$tmp/space.diff'"
expect_output "an empty diff lists nothing" "" sh -c "'$diff_lines' < /dev/null"

finish

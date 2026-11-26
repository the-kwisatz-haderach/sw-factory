# shellcheck shell=bash
# Minimal assertions for the factory's bash tests.
# A test runs git only in scratch repos of its own. Git's per-invocation
# variables, inherited from a hook (GIT_INDEX_FILE for `commit -a`) or any
# caller, would point those commands at the caller's repo instead (#40).
# shellcheck disable=SC2046  # one variable name per word
unset $(git rev-parse --local-env-vars)
failures=0
pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; failures=$((failures + 1)); }
# expect_status <name> <expected-exit-code> <command...>
expect_status() {
  local name="$1" want="$2"; shift 2
  local out; out="$("$@" 2>&1)"; local got=$?
  if [ "$got" -eq "$want" ]; then pass "$name"; else fail "$name (exit $got, want $want): $out"; fi
}
# expect_output <name> <expected-stdout> <command...>
expect_output() {
  local name="$1" want="$2"; shift 2
  local got; got="$("$@" 2>/dev/null)"
  if [ "$got" = "$want" ]; then pass "$name"; else fail "$name (got '$got', want '$want')"; fi
}
finish() { [ "$failures" -eq 0 ]; }

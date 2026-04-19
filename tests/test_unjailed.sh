#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."
source tests/lib.sh

UNJAILED="bin/unjailed"

# ---- bin/unjailed wrapper ----

test_case "unjailed with no args prints usage and exits 2"
out=$(bash "$UNJAILED" 2>&1; echo "exit=$?")
assert_contains "$out" "usage: unjailed" "must print usage on zero args"
assert_contains "$out" "exit=2" "must exit 2 on zero args"

test_case "unjailed execs argv with UNJAILED=1 in env"
# Use env(1) as the child so we can read its environment.
out=$(env -u UNJAILED bash "$UNJAILED" env | grep '^UNJAILED=' || true)
assert_eq "UNJAILED=1" "$out" "UNJAILED=1 must be exported to the child"

test_case "unjailed preserves argv quoting to the child"
# Pass an argument with a space; child should see it as a single arg.
out=$(bash "$UNJAILED" python3 -c 'import sys; print("|".join(sys.argv[1:]))' "a b" "c")
assert_eq "a b|c" "$out" "argv must survive intact (no shell re-splitting)"

summary

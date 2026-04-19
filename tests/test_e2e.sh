#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."
source tests/lib.sh

tmp_home=$(make_tmp)
tmp_prefix=$(make_tmp)
trap 'rm -rf "$tmp_home" "$tmp_prefix"' EXIT

test_case "install then run a pipeline through jailed-python"
HOME="$tmp_home" PREFIX="$tmp_prefix" bash install.sh >/dev/null
out=$(echo '<a href=hello>' | "$tmp_prefix/bin/jailed-python" -c '
import sys, re
html = sys.stdin.read()
m = re.search(r"href=(\S+?)>", html)
print(m.group(1) if m else "none")
')
assert_eq "hello" "$out" "end-to-end pipeline works"

test_case "installed hook correctly fires on python3 tool-input"
hook="$tmp_home/.claude/hooks/python-nudge.sh"
out=$(printf '%s' '{"tool_input":{"command":"python3 -c \"print(1)\""}}' | "$hook")
assert_contains "$out" '"permissionDecision": "ask"' "hook asks on python3"

test_case "installed hook stays silent on jailed-python tool-input"
out=$(printf '%s' '{"tool_input":{"command":"jailed-python -c \"print(1)\""}}' | "$hook")
assert_eq "" "$out" "hook silent on jailed-python"

test_case "settings.json has both allow rules and hook registration"
settings=$(cat "$tmp_home/.claude/settings.json")
assert_contains "$settings" '"Bash(jailed-python:*)"' "jailed-python allow"
assert_contains "$settings" '"Bash(jailed-python3:*)"' "jailed-python3 allow"
assert_contains "$settings" "python-nudge.sh" "hook command"

test_case "second install keeps things stable"
HOME="$tmp_home" PREFIX="$tmp_prefix" bash install.sh >/dev/null
allow_count=$(jq '[.permissions.allow[] | select(. == "Bash(jailed-python:*)")] | length' \
              "$tmp_home/.claude/settings.json")
assert_eq "1" "$allow_count" "still no duplicate allow"

summary

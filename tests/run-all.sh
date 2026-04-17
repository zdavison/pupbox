#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."

failed=0
for t in tests/test_*.sh; do
  echo "=== $t ==="
  bash "$t" || failed=$((failed+1))
  echo
done

if (( failed > 0 )); then
  echo "$failed test file(s) failed."
  exit 1
fi
echo "All test files passed."

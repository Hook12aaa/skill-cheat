#!/usr/bin/env bash
set -euo pipefail

# Invariant: any non-zero exit from a test must fail the suite.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
export CLAUDE_PLUGIN_ROOT="$ROOT"

fail=0
pass=0
failed_tests=()

while IFS= read -r -d '' test_file; do
  if bash "$test_file"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    failed_tests+=("$test_file")
  fi
done < <(find "$HERE" -type f -name 'test-*.sh' -print0 | sort -z)

echo "----"
echo "Passed: $pass"
echo "Failed: $fail"

if (( fail > 0 )); then
  printf 'FAILED:\n'
  printf '  %s\n' "${failed_tests[@]}"
  exit 1
fi

echo "ALL TESTS PASSED"

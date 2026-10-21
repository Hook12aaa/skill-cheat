#!/usr/bin/env bash
set -euo pipefail
script="skills/skill-stress-test/scripts/connect-plugin.sh"
fixture_clean="tests/qa-harness/fixtures/clean-plugin"
fixture_drift="tests/qa-harness/fixtures/drift-plugin"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: $label" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    exit 1
  fi
}

manifest="$(bash "$script" --plugin "$fixture_clean")"
assert_eq "clean: plugin_name" "clean-plugin" "$(printf '%s' "$manifest" | jq -r '.target.plugin_name')"
assert_eq "clean: skills count" "1" "$(printf '%s' "$manifest" | jq -r '.target.skills | length')"
assert_eq "clean: first skill" "sample-clean" "$(printf '%s' "$manifest" | jq -r '.target.skills[0]')"

manifest="$(bash "$script" --plugin "$fixture_drift")"
assert_eq "drift: plugin_name" "drift-plugin" "$(printf '%s' "$manifest" | jq -r '.target.plugin_name')"

set +e
bash "$script" --plugin "$tmp" 2>/dev/null
ec=$?
set -e
assert_eq "missing manifest exits non-zero" "1" "$ec"

set +e
bash "$script" 2>/dev/null
ec=$?
set -e
if [[ "$ec" == "0" ]]; then
  echo "FAIL: cwd auto-detect without manifest should exit non-zero" >&2
  exit 1
fi

cd "$fixture_clean"
manifest="$(bash "$(git -C "$OLDPWD" rev-parse --show-toplevel)/skills/skill-stress-test/scripts/connect-plugin.sh")"
cd "$OLDPWD"
assert_eq "auto-detect: plugin_name" "clean-plugin" "$(printf '%s' "$manifest" | jq -r '.target.plugin_name')"

echo "PASS: connect-plugin"

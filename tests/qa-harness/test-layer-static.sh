#!/usr/bin/env bash
set -euo pipefail
script="skills/skill-stress-test/scripts/layer-static.sh"
fixture_clean="tests/qa-harness/fixtures/clean-plugin"
fixture_drift="tests/qa-harness/fixtures/drift-plugin"

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: $label" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    exit 1
  fi
}

result="$(bash "$script" --target "$fixture_clean")"
assert_eq "clean: verdict"  "ACCEPT"     "$(printf '%s' "$result" | jq -r '.verdict')"
assert_eq "clean: per_skill count" "1"   "$(printf '%s' "$result" | jq -r '.per_skill | length')"
assert_eq "clean: first skill"  "sample-clean" "$(printf '%s' "$result" | jq -r '.per_skill[0].skill')"
assert_eq "clean: first verdict" "ACCEPT" "$(printf '%s' "$result" | jq -r '.per_skill[0].verdict')"

result="$(bash "$script" --target "$fixture_drift")"
assert_eq "drift: verdict" "REJECT_CRITICAL" "$(printf '%s' "$result" | jq -r '.verdict')"
assert_eq "drift: per_skill count" "1"      "$(printf '%s' "$result" | jq -r '.per_skill | length')"
assert_eq "drift: first skill" "sample-drift" "$(printf '%s' "$result" | jq -r '.per_skill[0].skill')"

echo "PASS: layer-static"

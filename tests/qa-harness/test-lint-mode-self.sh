#!/usr/bin/env bash
set -euo pipefail
lint="skills/skill-voice-review/scripts/lint.sh"
fixture="tests/qa-harness/fixtures/clean-plugin/skills/sample-clean/SKILL.md"

result="$(bash "$lint" --mode self "$fixture")"
verdict="$(printf '%s' "$result" | jq -r '.verdict')"
[[ "$verdict" == "ACCEPT" ]] \
  || { echo "FAIL: self mode on clean fixture should ACCEPT, got $verdict" >&2; exit 1; }

passed="$(printf '%s' "$result" | jq -r '.summary.passed')"
[[ "$passed" -ge 19 ]] \
  || { echo "FAIL: self mode should run at least 19 rules, got passed=$passed" >&2; exit 1; }

result_default="$(bash "$lint" "$fixture")"
verdict_default="$(printf '%s' "$result_default" | jq -r '.verdict')"
[[ "$verdict_default" == "$verdict" ]] \
  || { echo "FAIL: default mode should equal --mode self, got default=$verdict_default vs self=$verdict" >&2; exit 1; }

echo "PASS: lint --mode self"

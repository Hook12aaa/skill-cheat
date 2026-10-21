#!/usr/bin/env bash
set -euo pipefail
lint="skills/skill-voice-review/scripts/lint.sh"
fixture="tests/qa-harness/fixtures/clean-plugin/skills/sample-clean/SKILL.md"

result_self="$(bash "$lint" --mode self "$fixture")"
result_cross="$(bash "$lint" --mode cross-plugin "$fixture")"

ran_self="$(printf '%s' "$result_self" | jq -r '.summary.passed + .summary.critical + .summary.important + .summary.minor')"
ran_cross="$(printf '%s' "$result_cross" | jq -r '.summary.passed + .summary.critical + .summary.important + .summary.minor')"

[[ "$ran_self" -gt "$ran_cross" ]] \
  || { echo "FAIL: cross-plugin should run fewer rules than self (self=$ran_self cross=$ran_cross)" >&2; exit 1; }

diff="$((ran_self - ran_cross))"
[[ "$diff" == "1" ]] \
  || { echo "FAIL: cross-plugin should filter exactly 1 in-scope plugin-policy rule (LINT-016); LINT-001 is plugin-root-scoped and only runs under --plugin-root-only. got diff=$diff" >&2; exit 1; }

has_lint001="$(printf '%s' "$result_cross" | jq -r '[.findings[]?.rule // empty] | map(select(. == "LINT-001")) | length')"
[[ "$has_lint001" == "0" ]] \
  || { echo "FAIL: cross-plugin emitted LINT-001 findings (count=$has_lint001)" >&2; exit 1; }

echo "PASS: lint --mode cross-plugin"

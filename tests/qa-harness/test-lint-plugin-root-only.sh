#!/usr/bin/env bash
set -euo pipefail
lint="skills/skill-voice-review/scripts/lint.sh"
fixture="tests/qa-harness/fixtures/clean-plugin"

result="$(bash "$lint" --plugin-root-only --mode self --target "$fixture")"

verdict="$(printf '%s' "$result" | jq -r '.verdict')"
[[ "$verdict" == "ACCEPT" || "$verdict" == "ACCEPT_WITH_MINOR" || "$verdict" == "REJECT_IMPORTANT" || "$verdict" == "REJECT_CRITICAL" ]] \
  || { echo "FAIL: --plugin-root-only verdict invalid: $verdict" >&2; exit 1; }

skill_body_findings="$(printf '%s' "$result" | jq -r '[.findings[]?.rule] | map(select(. != "LINT-001" and . != "LINT-016")) | length')"
[[ "$skill_body_findings" == "0" ]] \
  || { echo "FAIL: --plugin-root-only emitted skill-body findings ($skill_body_findings)" >&2; exit 1; }

result_cross="$(bash "$lint" --plugin-root-only --mode cross-plugin --target "$fixture")"
has_lint001_cross="$(printf '%s' "$result_cross" | jq -r '[.findings[]?.rule] | map(select(. == "LINT-001")) | length')"
[[ "$has_lint001_cross" == "0" ]] \
  || { echo "FAIL: --plugin-root-only + cross-plugin should filter LINT-001 (got $has_lint001_cross findings)" >&2; exit 1; }

echo "PASS: lint --plugin-root-only"

#!/usr/bin/env bash
set -euo pipefail
script="skills/skill-stress-test/scripts/layer-static.sh"
fixture="tests/qa-harness/fixtures/cross-plugin-clean-plugin"

result="$(bash "$script" --target "$fixture")"

verdict="$(printf '%s' "$result" | jq -r '.verdict')"
[[ "$verdict" == "ACCEPT" ]] \
  || { echo "FAIL: cross-plugin-clean fixture expected ACCEPT, got $verdict" >&2; exit 1; }

plugin_findings_count="$(printf '%s' "$result" | jq -r '.plugin_findings | length')"
[[ "$plugin_findings_count" == "0" ]] \
  || { echo "FAIL: expected 0 plugin_findings (cross-plugin filters LINT-001), got $plugin_findings_count" >&2; exit 1; }

per_skill_count="$(printf '%s' "$result" | jq -r '.per_skill | length')"
[[ "$per_skill_count" == "1" ]] \
  || { echo "FAIL: expected 1 per_skill entry, got $per_skill_count" >&2; exit 1; }

first_verdict="$(printf '%s' "$result" | jq -r '.per_skill[0].verdict')"
[[ "$first_verdict" == "ACCEPT" ]] \
  || { echo "FAIL: per_skill[0].verdict expected ACCEPT, got $first_verdict" >&2; exit 1; }

echo "PASS: layer-static cross-plugin clean (F-23)"

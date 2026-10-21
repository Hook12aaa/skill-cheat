#!/usr/bin/env bash
set -euo pipefail
script="skills/skill-stress-test/scripts/layer-static.sh"
fixture="tests/qa-harness/fixtures/multi-skill-noise-plugin"

result="$(bash "$script" --target "$fixture")"

per_skill_count="$(printf '%s' "$result" | jq -r '.per_skill | length')"
[[ "$per_skill_count" == "3" ]] \
  || { echo "FAIL: expected 3 per_skill entries, got $per_skill_count" >&2; exit 1; }

plugin_findings_count="$(printf '%s' "$result" | jq -r '.plugin_findings | length')"
[[ "$plugin_findings_count" == "0" ]] \
  || { echo "FAIL: cross-plugin mode should filter LINT-001; got $plugin_findings_count plugin_findings" >&2; exit 1; }

skill_findings_with_lint001="$(printf '%s' "$result" | jq -r '[.per_skill[].findings[]?.rule // empty] | map(select(. == "LINT-001")) | length')"
[[ "$skill_findings_with_lint001" == "0" ]] \
  || { echo "FAIL: per_skill should not contain LINT-001 (got $skill_findings_with_lint001)" >&2; exit 1; }

verdict="$(printf '%s' "$result" | jq -r '.verdict')"
[[ "$verdict" == "ACCEPT" ]] \
  || { echo "FAIL: expected ACCEPT (all skills clean, no plugin findings in cross-plugin mode), got $verdict" >&2; exit 1; }

echo "PASS: layer-static plugin findings dedup"

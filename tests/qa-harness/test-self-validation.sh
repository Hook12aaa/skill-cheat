#!/usr/bin/env bash
set -euo pipefail
script="skills/skill-stress-test/scripts/qa-orchestrator.js"

cleanup() { rm -rf .skill-cheat-qa; }
trap cleanup EXIT
cleanup

out="$(env -u CLAUDE_PLUGIN_ROOT node "$script" --plugin .)"
echo "$out" | grep -qE '^VERDICT: (VALIDATION_CLEAN|PLUGIN_DRIFT)$' \
  || { echo "FAIL: self-validation produced unexpected verdict: $out" >&2; exit 1; }

run_count="$(find .skill-cheat-qa/runs -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
[[ "$run_count" == "1" ]] \
  || { echo "FAIL: expected 1 run dir, got $run_count" >&2; exit 1; }

report_path="$(find .skill-cheat-qa/runs -name report.json | head -1)"
jq -e '.layers.static.per_skill | length >= 6' "$report_path" > /dev/null \
  || { echo "FAIL: expected at least 6 enumerated skills, got $(jq '.layers.static.per_skill | length' "$report_path")" >&2; exit 1; }

echo "PASS: self-validation"

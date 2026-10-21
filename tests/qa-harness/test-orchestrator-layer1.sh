#!/usr/bin/env bash
set -euo pipefail
script="skills/skill-stress-test/scripts/qa-orchestrator.js"
fixture_clean="tests/qa-harness/fixtures/clean-plugin"
fixture_drift="tests/qa-harness/fixtures/drift-plugin"

cleanup() {
  rm -rf "${fixture_clean}/.skill-cheat-qa" "${fixture_drift}/.skill-cheat-qa"
}
trap cleanup EXIT
cleanup

out="$(node "$script" --plugin "$fixture_clean")"
echo "$out" | grep -q '^VERDICT: VALIDATION_CLEAN$' \
  || { echo "FAIL: clean fixture verdict was: $out" >&2; exit 1; }

[[ -d "${fixture_clean}/.skill-cheat-qa/runs" ]] \
  || { echo "FAIL: .skill-cheat-qa/runs directory was not created" >&2; exit 1; }

run_count="$(find "${fixture_clean}/.skill-cheat-qa/runs" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
[[ "$run_count" == "1" ]] \
  || { echo "FAIL: expected exactly 1 run directory, got $run_count" >&2; exit 1; }

report_path="$(find "${fixture_clean}/.skill-cheat-qa/runs" -name report.json | head -1)"
[[ -f "$report_path" ]] || { echo "FAIL: report.json not written" >&2; exit 1; }

jq -e '.verdict == "VALIDATION_CLEAN"' "$report_path" > /dev/null \
  || { echo "FAIL: report.verdict mismatch" >&2; exit 1; }

out="$(node "$script" --plugin "$fixture_drift")"
echo "$out" | grep -q '^VERDICT: PLUGIN_DRIFT$' \
  || { echo "FAIL: drift fixture verdict was: $out" >&2; exit 1; }

set +e
out="$(node "$script" --plugin /nonexistent/path 2>&1)"
ec=$?
set -e
[[ "$ec" != "0" ]] \
  || { echo "FAIL: missing target should exit non-zero" >&2; exit 1; }
echo "$out" | grep -q 'BLOCKED_NO_TARGET' \
  || { echo "FAIL: missing target should mention BLOCKED_NO_TARGET" >&2; exit 1; }

echo "PASS: qa-orchestrator (layer 1)"

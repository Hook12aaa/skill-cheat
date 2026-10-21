#!/usr/bin/env bash
set -euo pipefail
script="skills/skill-stress-test/scripts/qa-orchestrator.js"
fixture_clean="tests/qa-harness/fixtures/clean-plugin"

cleanup() {
  rm -rf "${fixture_clean}/.skill-cheat-qa"
}
trap cleanup EXIT
cleanup

# F-04: orchestrator must refuse to audit the harness root when --plugin == CLAUDE_PLUGIN_ROOT
ROOT="$(pwd)"
set +e
out="$(CLAUDE_PLUGIN_ROOT="$ROOT" node "$script" --plugin "$ROOT" 2>&1)"
ec=$?
set -e
[[ "$ec" != "0" ]] \
  || { echo "FAIL: orchestrator should refuse to audit harness root (exit=$ec)" >&2; echo "$out" >&2; exit 1; }
echo "$out" | grep -q "refusing to audit the harness root" \
  || { echo "FAIL: orchestrator must emit 'refusing to audit the harness root' message" >&2; echo "$out" >&2; exit 1; }
echo "$out" | grep -q "^VERDICT: BLOCKED_NO_TARGET$" \
  || { echo "FAIL: orchestrator must print VERDICT: BLOCKED_NO_TARGET" >&2; echo "$out" >&2; exit 1; }

# F-04: a different --plugin path with CLAUDE_PLUGIN_ROOT set must NOT trigger the refusal
set +e
out="$(CLAUDE_PLUGIN_ROOT="$ROOT" node "$script" --plugin "$fixture_clean" 2>&1)"
ec=$?
set -e
[[ "$ec" == "0" ]] \
  || { echo "FAIL: clean fixture audit unexpectedly exited $ec" >&2; echo "$out" >&2; exit 1; }
echo "$out" | grep -q '^VERDICT: VALIDATION_CLEAN$' \
  || { echo "FAIL: clean fixture audit should produce VALIDATION_CLEAN" >&2; echo "$out" >&2; exit 1; }

cleanup

# F-06: 8 parallel runs against the same fixture must produce 8 distinct run dirs
pids=()
for i in 1 2 3 4 5 6 7 8; do
  node "$script" --plugin "$fixture_clean" >/dev/null 2>&1 &
  pids+=($!)
done
fail_parallel=0
for p in "${pids[@]}"; do
  if ! wait "$p"; then
    fail_parallel=$((fail_parallel + 1))
  fi
done
[[ "$fail_parallel" == "0" ]] \
  || { echo "FAIL: $fail_parallel parallel runs failed" >&2; exit 1; }

run_count="$(find "${fixture_clean}/.skill-cheat-qa/runs" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
[[ "$run_count" == "8" ]] \
  || { echo "FAIL: expected 8 distinct run dirs, got $run_count" >&2; exit 1; }

# F-06: each run_id must end with a hex suffix; no two runs share an id
ids="$(find "${fixture_clean}/.skill-cheat-qa/runs" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)"
unique_ids="$(echo "$ids" | sort -u | wc -l | tr -d ' ')"
[[ "$unique_ids" == "8" ]] \
  || { echo "FAIL: run_ids collided (unique=$unique_ids)" >&2; echo "$ids" >&2; exit 1; }
echo "$ids" | grep -qvE '\-[0-9a-f]{8}$' \
  && { echo "FAIL: run_id missing 8-hex suffix" >&2; echo "$ids" >&2; exit 1; }

echo "PASS: qa-orchestrator edge cases"

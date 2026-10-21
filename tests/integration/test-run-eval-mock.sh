#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN="${HERE}/skills/skill-voice-review/scripts/run-eval.js"
FIX_HIT="${HERE}/tests/integration/fixtures/mock-stream-triggered.jsonl"
FIX_MISS="${HERE}/tests/integration/fixtures/mock-stream-no-trigger.jsonl"

# Invariant: triggered stream → triggered=true, durationMs=4200, totalTokens=12345.
out="$(node "$RUN" --skill-path /fake --query 'do the thing' --skill-name my-skill --mock-stream-file "$FIX_HIT")"
[[ "$(printf '%s' "$out" | jq -r '.triggered')" == "true" ]] || { echo "FAIL: hit.triggered"; exit 1; }
[[ "$(printf '%s' "$out" | jq -r '.durationMs')" == "4200" ]] || { echo "FAIL: hit.durationMs"; exit 1; }
[[ "$(printf '%s' "$out" | jq -r '.totalTokens')" == "12345" ]] || { echo "FAIL: hit.totalTokens"; exit 1; }
[[ "$(printf '%s' "$out" | jq -r '.mock')" == "true" ]] || { echo "FAIL: hit.mock"; exit 1; }

# Invariant: non-triggered stream → triggered=false.
out="$(node "$RUN" --skill-path /fake --query 'unrelated' --skill-name my-skill --mock-stream-file "$FIX_MISS")"
[[ "$(printf '%s' "$out" | jq -r '.triggered')" == "false" ]] || { echo "FAIL: miss.triggered"; exit 1; }
[[ "$(printf '%s' "$out" | jq -r '.durationMs')" == "1100" ]] || { echo "FAIL: miss.durationMs"; exit 1; }

echo "PASS: run-eval mock"

#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINT="${HERE}/skills/skill-voice-review/scripts/lint.sh"
FIXTURE="${HERE}/tests/lint/fixtures/good/minimal.md"

report="$(bash "$LINT" "$FIXTURE")"

if ! printf '%s' "$report" | jq -e '.verdict' >/dev/null; then
  echo "FAIL: report has no .verdict"
  echo "$report"
  exit 1
fi

if ! printf '%s' "$report" | jq -e '.summary' >/dev/null; then
  echo "FAIL: report has no .summary"
  exit 1
fi

if ! printf '%s' "$report" | jq -e '.findings' >/dev/null; then
  echo "FAIL: report has no .findings array"
  exit 1
fi

echo "PASS: lint skeleton"

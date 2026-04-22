#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINT="${HERE}/skills/skill-voice-review/scripts/lint.sh"
FIXTURE_DIR="${HERE}/tests/lint/fixtures/extends"

# Case 1: skill-without-token should trigger CUSTOM-001 → REJECT_CRITICAL
report="$(bash "$LINT" "${FIXTURE_DIR}/skill-without-token.md" 2>/dev/null || true)"
verdict="$(printf '%s' "$report" | jq -r '.verdict')"
if [[ "$verdict" != "REJECT_CRITICAL" ]]; then
  echo "FAIL: extends did not apply; verdict=$verdict"
  printf '%s\n' "$report" | jq .; exit 1
fi
if ! printf '%s' "$report" | jq -e '.findings | map(.ruleId == "CUSTOM-001") | any' >/dev/null; then
  echo "FAIL: CUSTOM-001 not in findings"
  exit 1
fi

# Case 2: skill-with-token should pass (ACCEPT)
report="$(bash "$LINT" "${FIXTURE_DIR}/skill-with-token.md")"
verdict="$(printf '%s' "$report" | jq -r '.verdict')"
if [[ "$verdict" != "ACCEPT" ]]; then
  echo "FAIL: skill-with-token expected ACCEPT; got $verdict"
  printf '%s\n' "$report" | jq .; exit 1
fi

echo "PASS: lint extends"

#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINT="${HERE}/skills/skill-voice-review/scripts/lint.sh"

# Good fixture → ACCEPT, exit 0
report="$(bash "$LINT" "${HERE}/tests/lint/fixtures/good/minimal.md")"
verdict="$(printf '%s' "$report" | jq -r '.verdict')"
if [[ "$verdict" != "ACCEPT" ]]; then
  echo "FAIL: good fixture verdict=$verdict (want ACCEPT)"
  printf '%s\n' "$report" | jq .
  exit 1
fi

# Summary shape check
for key in critical important minor passed; do
  if ! printf '%s' "$report" | jq -e ".summary.$key" >/dev/null; then
    echo "FAIL: good fixture summary missing key '$key'"
    exit 1
  fi
done

# Each bad fixture → REJECT_CRITICAL, its rule-id in findings
for fixture in "${HERE}/tests/lint/fixtures/bad/LINT-"*".md"; do
  rule_id="$(basename "$fixture" .md)"

  # LINT-001 (find-extensions) requires a disallowed file in scope at run time.
  # Scope resolves to tests/lint/ for these fixtures, so we create a temporary
  # decoy .py file in the bad/ directory only while running this fixture.
  decoy=""
  if [[ "$rule_id" == "LINT-001" ]]; then
    decoy="${HERE}/tests/lint/fixtures/bad/LINT-001.py"
    printf '# decoy disallowed-extension file for LINT-001 fixture coverage\n' > "$decoy"
  fi

  report="$(bash "$LINT" "$fixture" 2>/dev/null || true)"

  if [[ -n "$decoy" ]]; then
    rm -f "$decoy"
  fi

  verdict="$(printf '%s' "$report" | jq -r '.verdict')"
  if [[ "$verdict" != "REJECT_CRITICAL" ]]; then
    echo "FAIL: $rule_id verdict=$verdict (want REJECT_CRITICAL)"
    printf '%s\n' "$report" | jq .
    exit 1
  fi
  hit="$(printf '%s' "$report" | jq -r --arg id "$rule_id" '.findings | map(select(.ruleId == $id)) | length')"
  if [[ "$hit" -lt 1 ]]; then
    echo "FAIL: $rule_id fixture did not trigger $rule_id in findings"
    printf '%s\n' "$report" | jq .
    exit 1
  fi
done

echo "PASS: lint end-to-end"

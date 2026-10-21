#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINT="${HERE}/skills/skill-voice-review/scripts/lint.sh"
RULES="${HERE}/skills/skill-voice-review/references/lint-rules.json"
FIXTURES="${HERE}/tests/lint/fixtures/bad"

fail=0
while IFS= read -r rule_id; do
  fixture="${FIXTURES}/${rule_id}.md"
  if [[ ! -f "$fixture" ]]; then
    echo "COVERAGE-FAIL: no bad fixture for $rule_id"
    fail=1
    continue
  fi

  if [[ "$rule_id" == "LINT-001" ]]; then
    decoy="${FIXTURES}/LINT-001.py"
    trap 'rm -f "$decoy"' RETURN
    printf '# decoy disallowed-extension file for LINT-001\n' > "$decoy"
    report="$(bash "$LINT" --plugin-root-only --target "$FIXTURES" 2>/dev/null || true)"
    rm -f "$decoy"
  else
    report="$(bash "$LINT" "$fixture" 2>/dev/null || true)"
  fi

  if ! printf '%s' "$report" | jq -e --arg id "$rule_id" '.findings | map(.ruleId == $id) | any' >/dev/null; then
    echo "COVERAGE-FAIL: fixture ${rule_id}.md does not trigger $rule_id"
    fail=1
  fi
done < <(jq -r '.rules[].id' "$RULES")

(( fail == 0 )) || exit 1
echo "PASS: rule coverage"

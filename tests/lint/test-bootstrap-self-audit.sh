#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINT="${HERE}/skills/skill-voice-review/scripts/lint.sh"

PIPELINE_SKILLS=(
  "using-skill-cheat"
  "skill-scope"
  "skill-design"
  "skill-author"
  "skill-voice-review"
  "receiving-voice-review"
  "skill-scaffold"
)

fail=0
for skill in "${PIPELINE_SKILLS[@]}"; do
  path="${HERE}/skills/${skill}/SKILL.md"
  if [[ ! -f "$path" ]]; then
    echo "SELF-AUDIT-FAIL: ${skill}/SKILL.md does not exist"
    fail=1
    continue
  fi
  report="$(bash "$LINT" "$path" 2>/dev/null || true)"
  verdict="$(printf '%s' "$report" | jq -r '.verdict')"
  if [[ "$verdict" != "ACCEPT" && "$verdict" != "ACCEPT_WITH_MINOR" ]]; then
    critical="$(printf '%s' "$report" | jq '.summary.critical')"
    echo "SELF-AUDIT-FAIL: ${skill} verdict=$verdict (critical=$critical)"
    printf '%s\n' "$report" | jq '.findings | map({ruleId, message, location})'
    fail=1
  fi
done

(( fail == 0 )) || exit 1
echo "PASS: bootstrap self-audit"

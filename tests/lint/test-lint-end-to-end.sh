#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LINT="${HERE}/skills/skill-voice-review/scripts/lint.sh"
RULES="${HERE}/skills/skill-voice-review/references/lint-rules.json"

# Invariant: good fixture produces ACCEPT.
report="$(bash "$LINT" "${HERE}/tests/lint/fixtures/good/minimal.md")"
verdict="$(printf '%s' "$report" | jq -r '.verdict')"
if [[ "$verdict" != "ACCEPT" ]]; then
  echo "FAIL: good fixture verdict=$verdict (want ACCEPT)"
  printf '%s\n' "$report" | jq .
  exit 1
fi

# Invariant: summary contains critical, important, minor, passed counters.
for key in critical important minor passed; do
  if ! printf '%s' "$report" | jq -e ".summary.$key" >/dev/null; then
    echo "FAIL: good fixture summary missing key '$key'"
    exit 1
  fi
done

# Invariant per bad fixture: verdict matches rule severity — CRITICAL→REJECT_CRITICAL, IMPORTANT→REJECT_IMPORTANT, MINOR→ACCEPT_WITH_MINOR; fixture ruleId appears in findings.
for fixture in "${HERE}/tests/lint/fixtures/bad/LINT-"*".md"; do
  rule_id="$(basename "$fixture" .md)"

  severity="$(jq -r --arg id "$rule_id" '.rules[] | select(.id == $id) | .severity' "$RULES")"
  case "$severity" in
    CRITICAL)  want_verdict="REJECT_CRITICAL" ;;
    IMPORTANT) want_verdict="REJECT_IMPORTANT" ;;
    MINOR)     want_verdict="ACCEPT_WITH_MINOR" ;;
    *)         echo "FAIL: $rule_id has unknown severity '$severity'"; exit 1 ;;
  esac

  # Invariant: LINT-001 (find-extensions) requires a disallowed-extension file present in plugin scope at run time; inject a decoy for the duration of this fixture only.
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
  if [[ "$verdict" != "$want_verdict" ]]; then
    echo "FAIL: $rule_id severity=$severity verdict=$verdict (want $want_verdict)"
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

#!/usr/bin/env bash
set -euo pipefail

# Invariant: lint.sh emits a single JSON object to stdout with keys {skill, designSha, runId, summary, findings, verdict}.
# Invariant: non-zero exit on schema violation, lint engine errors, or REJECT_CRITICAL verdict. Exit 0 on ACCEPT / ACCEPT_WITH_MINOR.

if [[ $# -lt 1 ]]; then
  echo "usage: lint.sh <path-to-SKILL.md>" >&2
  exit 64
fi

SKILL_PATH="$1"
[[ -f "$SKILL_PATH" ]] || { echo "lint: file not found: $SKILL_PATH" >&2; exit 66; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REF="$(cd "${HERE}/../references" && pwd)"
RULES_FILE="${REF}/lint-rules.json"

if [[ ! -f "$RULES_FILE" ]]; then
  RULES_JSON='{"schemaVersion":"1.0","rules":[]}'
else
  RULES_JSON="$(cat "$RULES_FILE")"
fi

findings_json='[]'
critical=0
important=0
minor=0
passed=0

dispatch_detector() {
  passed=$((passed + 1))
}

count="$(printf '%s' "$RULES_JSON" | jq '.rules | length')"
for (( i=0; i<count; i++ )); do
  rule="$(printf '%s' "$RULES_JSON" | jq -c ".rules[$i]")"
  dispatch_detector "$rule"
done

if (( critical > 0 )); then verdict="REJECT_CRITICAL"
elif (( important > 0 )); then verdict="REJECT_IMPORTANT"
elif (( minor > 0 )); then verdict="ACCEPT_WITH_MINOR"
else verdict="ACCEPT"
fi

jq -n \
  --arg skill "$SKILL_PATH" \
  --arg runId "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson summary "{\"critical\":$critical,\"important\":$important,\"minor\":$minor,\"passed\":$passed}" \
  --argjson findings "$findings_json" \
  --arg verdict "$verdict" \
  '{skill:$skill, designSha:null, runId:$runId, summary:$summary, findings:$findings, verdict:$verdict}'

case "$verdict" in
  REJECT_CRITICAL|REJECT_IMPORTANT) exit 1 ;;
  *) exit 0 ;;
esac

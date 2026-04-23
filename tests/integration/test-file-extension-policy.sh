#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RULES="${HERE}/skills/skill-voice-review/references/lint-rules.json"

# Invariant: LINT-001 allowlist includes every extension required by Plans 4-6.
REQUIRED=(".md" ".js" ".sh" ".json" ".cjs" ".html" ".css" ".woff2")
allowlist="$(jq -r '.rules[] | select(.id == "LINT-001") | .detector.allowlist | join(" ")' "$RULES")"
fail=0
for ext in "${REQUIRED[@]}"; do
  if ! printf '%s\n' "$allowlist" | grep -qw -- "$ext"; then
    echo "FAIL: LINT-001 allowlist missing $ext (have: $allowlist)"
    fail=1
  fi
done
(( fail == 0 )) || exit 1
echo "PASS: file-extension policy"

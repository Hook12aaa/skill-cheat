#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LINT_JS="${HERE}/skills/skill-voice-review/scripts/lint.js"

cfg='{"left-section":"checklist","right-section":"step-details","left-pattern":"^\\d+\\.\\s","right-pattern":"^###\\s+\\d+\\."}'

# Canonical minimal: checklist has "1.", step details has "### 1." — should match.
out="$(node "$LINT_JS" --detector cross-reference --skill "${HERE}/tests/lint/fixtures/good/minimal.md" --config "$cfg")"
if ! printf '%s' "$out" | jq -e '.findings | length == 0' >/dev/null; then
  echo "FAIL: canonical minimal should pass cross-reference: $out"; exit 1
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat > "${TMP}/mismatched.md" <<'EOF'
## Checklist
1. First
2. Second

## Step Details
### 1. First
Only one detail.
EOF
out="$(node "$LINT_JS" --detector cross-reference --skill "${TMP}/mismatched.md" --config "$cfg")"
if ! printf '%s' "$out" | jq -e '.findings | length >= 1' >/dev/null; then
  echo "FAIL: mismatched numbers not flagged: $out"; exit 1
fi

echo "PASS: cross-reference"

#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${HERE}/skills/skill-voice-review/scripts/lint.sh" --source-only

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/has.md" <<'EOF'
## Anti-Pattern
"this one is fine"
EOF
findings="$(detect_grep_required "$TMP/has.md" '{"pattern":"## Anti-Pattern"}')"
if ! printf '%s' "$findings" | jq -e 'length == 0' >/dev/null; then
  echo "FAIL: false positive when required pattern present"
  echo "$findings"; exit 1
fi

cat > "$TMP/missing.md" <<'EOF'
## Other
no anti pattern here
EOF
findings="$(detect_grep_required "$TMP/missing.md" '{"pattern":"## Anti-Pattern"}')"
if ! printf '%s' "$findings" | jq -e 'length == 1' >/dev/null; then
  echo "FAIL: did not flag missing required pattern"
  echo "$findings"; exit 1
fi

echo "PASS: grep-required"

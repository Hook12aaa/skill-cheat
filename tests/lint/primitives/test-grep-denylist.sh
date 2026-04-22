#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${HERE}/skills/skill-voice-review/scripts/lint.sh" --source-only

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/skill.md" <<'EOF'
# demo
This may or may not work.
Consider the alternative.
EOF

denylist='{"entries":["may","consider"]}'
findings="$(detect_grep_denylist "$TMP/skill.md" "$denylist")"
count="$(printf '%s' "$findings" | jq 'length')"
if [[ "$count" -lt 2 ]]; then
  echo "FAIL: expected ≥2 findings; got $count"
  echo "$findings"; exit 1
fi

cat > "$TMP/clean.md" <<'EOF'
# demo
Do X. Do Y.
EOF
findings="$(detect_grep_denylist "$TMP/clean.md" "$denylist")"
if ! printf '%s' "$findings" | jq -e 'length == 0' >/dev/null; then
  echo "FAIL: false positives on clean input"
  echo "$findings"; exit 1
fi

echo "PASS: grep-denylist"

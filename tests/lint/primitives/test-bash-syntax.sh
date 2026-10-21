#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${HERE}/skills/skill-voice-review/scripts/lint.sh" --source-only

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

cat > "${TMP}/good.md" <<'EOF'
## The Bottom Line

```bash
echo "VERDICT: READY"
```
EOF

cfg='{"section":"the-bottom-line"}'
findings="$(detect_bash_syntax "${TMP}/good.md" "$cfg")"
if ! printf '%s' "$findings" | jq -e 'length == 0' >/dev/null; then
  echo "FAIL: clean bash flagged: $findings"; exit 1
fi

cat > "${TMP}/broken.md" <<'EOF'
## The Bottom Line

```bash
if echo "oops" fi
```
EOF

findings="$(detect_bash_syntax "${TMP}/broken.md" "$cfg")"
if ! printf '%s' "$findings" | jq -e 'length == 1' >/dev/null; then
  echo "FAIL: broken bash not flagged"
  echo "$findings"; exit 1
fi

cat > "${TMP}/no-fence.md" <<'EOF'
## The Bottom Line

No fenced block here.
EOF

findings="$(detect_bash_syntax "${TMP}/no-fence.md" "$cfg")"
if ! printf '%s' "$findings" | jq -e 'length == 0' >/dev/null; then
  echo "FAIL: no-fence case should produce no findings (silent), got: $findings"; exit 1
fi

echo "PASS: bash-syntax"

#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${HERE}/skills/skill-voice-review/scripts/lint.sh" --source-only

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

cat > "${TMP}/good.md" <<'EOF'
## Process Flow

```dot
digraph g {
    a [shape=box];
    b [shape=doublecircle];
    a -> b;
}
```
EOF

cfg='{"section":"process-flow"}'
findings="$(detect_dot_parse "${TMP}/good.md" "$cfg")"
if ! printf '%s' "$findings" | jq -e 'length == 0' >/dev/null; then
  echo "FAIL: good dot flagged: $findings"; exit 1
fi

cat > "${TMP}/broken.md" <<'EOF'
## Process Flow

```dot
digraph broken { a -> ; }
```
EOF

findings="$(detect_dot_parse "${TMP}/broken.md" "$cfg")"
if ! printf '%s' "$findings" | jq -e 'length == 1' >/dev/null; then
  echo "FAIL: broken dot not flagged: $findings"; exit 1
fi

cat > "${TMP}/no-fence.md" <<'EOF'
## Process Flow

No dot block here.
EOF

findings="$(detect_dot_parse "${TMP}/no-fence.md" "$cfg")"
if ! printf '%s' "$findings" | jq -e 'length == 0' >/dev/null; then
  echo "FAIL: no-fence should not flag: $findings"; exit 1
fi

echo "PASS: dot-parse"

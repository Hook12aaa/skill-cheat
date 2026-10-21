#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="${HERE}/skills/skill-design/scripts/integrity-hash.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

cat > "${TMP}/good.md" <<'EOF'
# Some design

Prose outside the block.

<!-- integrity-block:start -->
## Skill Name
demo

## Triggers
- Slash command: /demo
<!-- integrity-block:end -->

More prose after.
EOF

bash "$SCRIPT" "${TMP}/good.md" >/dev/null

sidecar="${TMP}/good.md.sha256"
[[ -f "$sidecar" ]] || { echo "FAIL: sidecar not created"; exit 1; }

recorded="$(awk '{print $1}' "$sidecar")"
[[ "$recorded" =~ ^[0-9a-f]{64}$ ]] || { echo "FAIL: digest is not 64 hex chars"; echo "$recorded"; exit 1; }

basename_in_sidecar="$(awk '{print $2}' "$sidecar")"
[[ "$basename_in_sidecar" == "good.md" ]] || { echo "FAIL: sidecar does not name basename; got '$basename_in_sidecar'"; exit 1; }

recomputed="$(
  awk '
    /<!-- integrity-block:start -->/ { emit=1; next }
    /<!-- integrity-block:end -->/   { emit=0; next }
    emit { print }
  ' "${TMP}/good.md" | openssl dgst -sha256 | awk '{print $NF}'
)"
[[ "$recomputed" == "$recorded" ]] || { echo "FAIL: sidecar digest does not match recomputed digest"; exit 1; }

cat > "${TMP}/no-start.md" <<'EOF'
# Missing start
<!-- integrity-block:end -->
EOF
if bash "$SCRIPT" "${TMP}/no-start.md" 2>/dev/null; then
  echo "FAIL: accepted file with no start marker"; exit 1
fi

cat > "${TMP}/no-end.md" <<'EOF'
# Missing end
<!-- integrity-block:start -->
stuff
EOF
if bash "$SCRIPT" "${TMP}/no-end.md" 2>/dev/null; then
  echo "FAIL: accepted file with no end marker"; exit 1
fi

cat > "${TMP}/duplicate.md" <<'EOF'
<!-- integrity-block:start -->
one
<!-- integrity-block:end -->
<!-- integrity-block:start -->
two
<!-- integrity-block:end -->
EOF
if bash "$SCRIPT" "${TMP}/duplicate.md" 2>/dev/null; then
  echo "FAIL: accepted file with duplicated markers"; exit 1
fi

echo "PASS: integrity-hash"

#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LINT_JS="${HERE}/skills/skill-voice-review/scripts/lint.js"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

cat > "${TMP}/good.md" <<'EOF'
---
name: demo
description: Trigger /demo. Verdicts are READY, REJECT.
---

# demo
EOF

cfg='{"required-fields":["name","description"],"description-contains-trigger":true,"description-contains-verdict":true}'
out="$(node "$LINT_JS" --detector yaml-frontmatter --skill "${TMP}/good.md" --config "$cfg")"
if ! printf '%s' "$out" | jq -e '.findings | length == 0' >/dev/null; then
  echo "FAIL: good frontmatter flagged: $out"; exit 1
fi

cat > "${TMP}/no-verdict.md" <<'EOF'
---
name: demo
description: Trigger /demo. Use when testing.
---

# demo
EOF
out="$(node "$LINT_JS" --detector yaml-frontmatter --skill "${TMP}/no-verdict.md" --config "$cfg")"
if ! printf '%s' "$out" | jq -e '.findings | length == 1' >/dev/null; then
  echo "FAIL: no-verdict expected 1 finding: $out"; exit 1
fi

cat > "${TMP}/no-description.md" <<'EOF'
---
name: demo
---

# demo
EOF
out="$(node "$LINT_JS" --detector yaml-frontmatter --skill "${TMP}/no-description.md" --config "$cfg")"
if ! printf '%s' "$out" | jq -e '.findings | length >= 1' >/dev/null; then
  echo "FAIL: missing description not flagged: $out"; exit 1
fi

cat > "${TMP}/no-frontmatter.md" <<'EOF'
# demo

Just a body.
EOF
out="$(node "$LINT_JS" --detector yaml-frontmatter --skill "${TMP}/no-frontmatter.md" --config "$cfg")"
if ! printf '%s' "$out" | jq -e '.findings | length >= 1' >/dev/null; then
  echo "FAIL: missing frontmatter not flagged: $out"; exit 1
fi

cat > "${TMP}/false-short-caps.md" <<'EOF'
---
name: demo
description: Trigger /demo. Use SET or GET for testing.
---

# demo
EOF
out="$(node "$LINT_JS" --detector yaml-frontmatter --skill "${TMP}/false-short-caps.md" --config "$cfg")"
if ! printf '%s' "$out" | jq -e '.findings | length == 1' >/dev/null; then
  echo "FAIL: SET/GET should not qualify as verdict tokens (expected 1 finding: no verdict)"
  echo "$out"; exit 1
fi

echo "PASS: yaml-frontmatter"

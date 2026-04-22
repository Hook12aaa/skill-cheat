#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LINT_JS="${HERE}/skills/skill-voice-review/scripts/lint.js"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

cfg='{"max-sentences":2,"forbidden-tokens":["because","since","in order to"]}'

# Good: 2 sentences, no forbidden tokens.
cat > "${TMP}/good.md" <<'EOF'
<HARD-GATE>
Do NOT proceed without scope. STOP and invoke /skill-scope.
</HARD-GATE>
EOF
out="$(node "$LINT_JS" --detector hard-gate-span --skill "${TMP}/good.md" --config "$cfg")"
if ! printf '%s' "$out" | jq -e '.findings | length == 0' >/dev/null; then
  echo "FAIL: good hard-gate flagged: $out"; exit 1
fi

# Bad: too many sentences.
cat > "${TMP}/three-sentences.md" <<'EOF'
<HARD-GATE>
Do NOT proceed without scope. STOP and invoke /skill-scope. Then confirm nothing else is pending.
</HARD-GATE>
EOF
out="$(node "$LINT_JS" --detector hard-gate-span --skill "${TMP}/three-sentences.md" --config "$cfg")"
if ! printf '%s' "$out" | jq -e '.findings | length == 1' >/dev/null; then
  echo "FAIL: 3-sentence gate not flagged: $out"; exit 1
fi

# Bad: forbidden "because".
cat > "${TMP}/because.md" <<'EOF'
<HARD-GATE>
Do NOT proceed without scope because the scope lock is load-bearing.
</HARD-GATE>
EOF
out="$(node "$LINT_JS" --detector hard-gate-span --skill "${TMP}/because.md" --config "$cfg")"
if ! printf '%s' "$out" | jq -e '.findings | length >= 1' >/dev/null; then
  echo "FAIL: because not flagged: $out"; exit 1
fi

# Combined: sentences + forbidden token → expect 2 findings.
cat > "${TMP}/both.md" <<'EOF'
<HARD-GATE>
Do NOT proceed without scope because the scope lock is load-bearing. STOP and invoke /skill-scope. The design cannot proceed without it.
</HARD-GATE>
EOF
out="$(node "$LINT_JS" --detector hard-gate-span --skill "${TMP}/both.md" --config "$cfg")"
count="$(printf '%s' "$out" | jq '.findings | length')"
if [[ "$count" -lt 2 ]]; then
  echo "FAIL: combined case expected >=2 findings, got $count"
  echo "$out"; exit 1
fi

echo "PASS: hard-gate-span"

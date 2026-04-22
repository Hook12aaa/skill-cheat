#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LINT_JS="${HERE}/skills/skill-voice-review/scripts/lint.js"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Good fixture — use the canonical minimal fixture.
cfg='{"expected-order":["<HARD-GATE>","Anti-Pattern","Core Principle","Process Flow","Checklist","Step Details","Gate Functions","Rationalization Table","Red Flags","Key Principles","The Bottom Line"]}'
out="$(node "$LINT_JS" --detector section-order --skill "${HERE}/tests/lint/fixtures/good/minimal.md" --config "$cfg")"
if ! printf '%s' "$out" | jq -e '.findings | length == 0' >/dev/null; then
  echo "FAIL: canonical minimal should pass section-order: $out"; exit 1
fi

# Bad: swap two sections.
cat > "${TMP}/swapped.md" <<'EOF'
---
name: demo
description: Trigger /demo. Verdicts READY.
---

# demo

<HARD-GATE>
Do NOT proceed without scope.
</HARD-GATE>

## Anti-Pattern
"x"

## Core Principle
Y.

## Process Flow
```dot
digraph g { a -> b; }
```

## Checklist
1. Do thing

## Step Details
### 1. Do thing
Details.

## Rationalization Table
| a | b |
|---|---|
| x | y |

## Gate Functions
- BEFORE x: "y?"

## Red Flags
- "z"

## Key Principles
- **K.** V.

## The Bottom Line
```bash
echo "VERDICT: READY"
```
EOF
out="$(node "$LINT_JS" --detector section-order --skill "${TMP}/swapped.md" --config "$cfg")"
if ! printf '%s' "$out" | jq -e '.findings | length >= 1' >/dev/null; then
  echo "FAIL: swapped order not flagged: $out"; exit 1
fi

echo "PASS: section-order"

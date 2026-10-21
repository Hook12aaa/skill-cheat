#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "${HERE}/hooks/lib/emit-context.sh"

actual="$(emit_context "hello world")"
expected='{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"hello world"}}'

if [[ "$actual" != "$expected" ]]; then
  echo "FAIL: emit_context plain text"
  diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") || true
  exit 1
fi

tricky='line with "quotes" and \backslash'
actual="$(emit_context "$tricky")"
if ! printf '%s' "$actual" | jq -e . >/dev/null; then
  echo "FAIL: emit_context output is not valid JSON for tricky input"
  echo "$actual"
  exit 1
fi
extracted="$(printf '%s' "$actual" | jq -r '.hookSpecificOutput.additionalContext')"
if [[ "$extracted" != "$tricky" ]]; then
  echo "FAIL: tricky input not preserved through JSON round-trip"
  echo "  sent:     $tricky"
  echo "  got:      $extracted"
  exit 1
fi

echo "PASS: emit-context"

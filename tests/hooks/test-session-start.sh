#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export CLAUDE_PLUGIN_ROOT="$HERE"

out="$(bash "${HERE}/hooks/session-start" </dev/null)"

if ! printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null; then
  echo "FAIL: session-start did not emit JSON with additionalContext"
  echo "$out"
  exit 1
fi

content="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext')"

if [[ "$content" != *"using-skill-cheat"* ]]; then
  echo "FAIL: bootstrap content not injected"
  exit 1
fi

echo "PASS: session-start"

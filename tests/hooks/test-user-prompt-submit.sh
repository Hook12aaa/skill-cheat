#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export CLAUDE_PLUGIN_ROOT="$HERE"

payload='{"prompt":"I want to author a skill for frontend debugging"}'
out="$(printf '%s' "$payload" | bash "${HERE}/hooks/user-prompt-submit")"

if ! printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null; then
  echo "FAIL: did not emit JSON on matching prompt"
  echo "$out"; exit 1
fi

content="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext')"
if [[ "$content" != *"/skill-scope"* ]]; then
  echo "FAIL: reminder does not name /skill-scope"; exit 1
fi

payload='{"prompt":"help me debug this python error"}'
out="$(printf '%s' "$payload" | bash "${HERE}/hooks/user-prompt-submit")"
if [[ -n "$out" ]]; then
  echo "FAIL: non-empty output on no-match prompt"
  echo "$out"; exit 1
fi

out="$(printf 'not json at all' | bash "${HERE}/hooks/user-prompt-submit")"
if [[ -n "$out" ]]; then
  echo "FAIL: non-empty output on malformed input"
  echo "$out"; exit 1
fi

echo "PASS: user-prompt-submit"

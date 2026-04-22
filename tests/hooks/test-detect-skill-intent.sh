#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "${HERE}/hooks/lib/detect-skill-intent.sh"

KEYWORDS=("author a skill" "build a skill" "new plugin")

if ! detect_skill_intent "Let me author a skill for X" "${KEYWORDS[@]}"; then
  echo "FAIL: exact-keyword match missed"; exit 1
fi

if ! detect_skill_intent "I want to BUILD A SKILL now" "${KEYWORDS[@]}"; then
  echo "FAIL: case-insensitive match missed"; exit 1
fi

if detect_skill_intent "debug the auth flow" "${KEYWORDS[@]}"; then
  echo "FAIL: false positive on unrelated prompt"; exit 1
fi

if detect_skill_intent "" "${KEYWORDS[@]}"; then
  echo "FAIL: false positive on empty input"; exit 1
fi

if detect_skill_intent "author a skill"; then
  echo "FAIL: matched with empty keyword list"; exit 1
fi

echo "PASS: detect-skill-intent"

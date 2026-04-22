#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

for cmd in skill-scope skill-design skill-author skill-voice-review skill-scaffold; do
  [[ -f "${HERE}/commands/${cmd}.md" ]] || { echo "FAIL: commands/${cmd}.md missing"; exit 1; }
done

for skill in using-skill-cheat skill-scope skill-design skill-author skill-voice-review receiving-voice-review skill-scaffold; do
  [[ -f "${HERE}/skills/${skill}/SKILL.md" ]] || { echo "FAIL: skills/${skill}/SKILL.md missing"; exit 1; }
done

[[ -f "${HERE}/agents/voice-reviewer.md" ]] || { echo "FAIL: agents/voice-reviewer.md missing"; exit 1; }

for ref in skills/skill-voice-review/references/lint-rules.json \
           skills/skill-voice-review/references/canonical-anatomy.md \
           skills/skill-author/references/canonical-anatomy.md \
           skills/skill-design/references/integrity-block.md \
           skills/skill-scaffold/references/plugin-skeleton.md; do
  [[ -f "${HERE}/${ref}" ]] || { echo "FAIL: ${ref} missing"; exit 1; }
done

if ! diff -q "${HERE}/skills/skill-author/references/canonical-anatomy.md" \
              "${HERE}/skills/skill-voice-review/references/canonical-anatomy.md" >/dev/null; then
  echo "FAIL: canonical-anatomy.md copies are not byte-identical"
  exit 1
fi

echo "PASS: pipeline shape"

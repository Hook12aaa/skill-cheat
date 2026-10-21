#!/usr/bin/env bash

SKILL_CHEAT_TRIGGER_KEYWORDS=(
  "author a skill"
  "build a skill"
  "new skill"
  "scaffold a skill"
  "make a skill"
  "write a skill"
  "author a plugin"
  "new plugin"
  "skill-cheat"
)

SKILL_CHEAT_WORK_DIR="docs/skill-cheat/skills-in-progress"

if [[ -f "${CLAUDE_PROJECT_DIR:-.}/.skill-cheat.sh" ]]; then
  # shellcheck source=/dev/null
  source "${CLAUDE_PROJECT_DIR:-.}/.skill-cheat.sh"
fi

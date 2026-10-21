# Hook Templates

Template bodies for `hooks/session-start`, `hooks/user-prompt-submit`, `hooks/hooks.json`. The scaffold stage parameterizes and emits these.

## `hooks/hooks.json` template

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/session-start\"",
            "async": false
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/user-prompt-submit\"",
            "async": false
          }
        ]
      }
    ]
  }
}
```

Drop the `UserPromptSubmit` block if scope declared no keyword triggers.

## `hooks/session-start` template

```bash
#!/usr/bin/env bash
set -euo pipefail

BOOTSTRAP="${CLAUDE_PLUGIN_ROOT}/skills/using-<PLUGIN_NAME>/SKILL.md"
[[ -f "$BOOTSTRAP" ]] || exit 0

source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/emit-context.sh"

emit_context "$(cat "$BOOTSTRAP")"
```

Replace `<PLUGIN_NAME>` with the scope-declared plugin name.

## `hooks/user-prompt-submit` template (only when keywords declared)

```bash
#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

source "${CLAUDE_PLUGIN_ROOT}/config.sh"
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/emit-context.sh"
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/detect-skill-intent.sh"

payload="$(cat)"
prompt="$(printf '%s' "$payload" | jq -r '.prompt // empty' 2>/dev/null || true)"
[[ -z "$prompt" ]] && exit 0

if detect_skill_intent "$prompt" "${<PLUGIN_UPPER>_TRIGGER_KEYWORDS[@]}"; then
  emit_context "<PLUGIN_NAME> INTENT DETECTED. Invoke /<primary-command> before any other action."
fi
```

Replace `<PLUGIN_UPPER>` with uppercase-snake-case plugin name, `<PLUGIN_NAME>` with display name, `<primary-command>` with the first slash command in scope.

## `config.sh` template

```bash
#!/usr/bin/env bash

<PLUGIN_UPPER>_TRIGGER_KEYWORDS=(
  "<keyword 1>"
  "<keyword 2>"
)

if [[ -f "${CLAUDE_PROJECT_DIR:-.}/.<plugin-name>.sh" ]]; then
  source "${CLAUDE_PROJECT_DIR:-.}/.<plugin-name>.sh"
fi
```

## Rule

Every template above is a STARTING POINT. The scaffold emits these then adapts to scope-declared specifics. Do NOT emit templates without substituting placeholders.

## Rationalization Table

| You think... | Reality |
|---|---|
| "`set -euo pipefail` is noisy; I'll skip it and catch errors manually." | Keep `set -euo pipefail` on every hook script. An unbound variable or silent pipe failure emits malformed JSON and Claude stamps the turn with a hook error. |
| "A non-zero exit from the normal path is harmless — Claude ignores stdout anyway." | Never exit non-zero on the happy path. Exit 2 blocks the turn and exit 0 is the only code where `hookSpecificOutput` is parsed. |
| "I'll hardcode `/Users/me/plugins/foo` so the path is unambiguous during local testing." | Always resolve paths through `${CLAUDE_PLUGIN_ROOT}`. Baked absolute paths break every install outside your machine and the hook fails before emitting JSON. |

## Red Flags

- "I don't need `set -euo pipefail` here."
- "Exiting 1 on the normal path is fine."
- "I'll hardcode the absolute path for now."
- "I'll log the raw prompt into additionalContext so I can debug later."

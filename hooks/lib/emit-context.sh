#!/usr/bin/env bash

emit_context() {
  local text="$1"
  # Invariant: stdout must be a single valid JSON object with additionalContext set.
  jq -nc --arg t "$text" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $t}}'
}

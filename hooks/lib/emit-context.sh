#!/usr/bin/env bash

emit_context() {
  local event="$1"
  local text="$2"
  jq -nc --arg e "$event" --arg t "$text" \
    '{hookSpecificOutput: {hookEventName: $e, additionalContext: $t}}'
}

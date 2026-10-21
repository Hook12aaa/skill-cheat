#!/usr/bin/env bash

detect_skill_intent() {
  local prompt="$1"; shift || true
  [[ -z "$prompt" ]] && return 1
  (( "$#" == 0 )) && return 1
  local lower_prompt
  lower_prompt="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"
  local kw lower_kw
  for kw in "$@"; do
    lower_kw="$(printf '%s' "$kw" | tr '[:upper:]' '[:lower:]')"
    if [[ "$lower_prompt" == *"$lower_kw"* ]]; then
      return 0
    fi
  done
  return 1
}

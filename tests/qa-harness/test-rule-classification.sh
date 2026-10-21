#!/usr/bin/env bash
set -euo pipefail
rules="skills/skill-voice-review/references/lint-rules.json"

missing="$(jq -r '.rules[] | select(.kind == null) | .id' "$rules")"
if [[ -n "$missing" ]]; then
  echo "FAIL: rules without a kind field:" >&2
  echo "$missing" >&2
  exit 1
fi

invalid="$(jq -r '.rules[] | select(.kind != "skill-shape" and .kind != "plugin-policy") | .id + " kind=" + .kind' "$rules")"
if [[ -n "$invalid" ]]; then
  echo "FAIL: rules with invalid kind (must be skill-shape or plugin-policy):" >&2
  echo "$invalid" >&2
  exit 1
fi

skill_shape_count="$(jq '[.rules[] | select(.kind == "skill-shape")] | length' "$rules")"
plugin_policy_count="$(jq '[.rules[] | select(.kind == "plugin-policy")] | length' "$rules")"
total="$(jq '.rules | length' "$rules")"
[[ "$((skill_shape_count + plugin_policy_count))" == "$total" ]] \
  || { echo "FAIL: classification count mismatch" >&2; exit 1; }

echo "PASS: rule classification ($skill_shape_count skill-shape, $plugin_policy_count plugin-policy)"

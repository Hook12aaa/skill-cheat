#!/usr/bin/env bash
set -euo pipefail

# Invariant: emits a normalized manifest JSON to stdout on success; exit 1 on missing target.
# Invariant: --plugin <path> takes precedence over cwd auto-detection.

PLUGIN_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --plugin) PLUGIN_PATH="$2"; shift 2 ;;
    *) echo "connect-plugin: unknown arg $1" >&2; exit 64 ;;
  esac
done

if [[ -z "$PLUGIN_PATH" ]]; then
  if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]] && [[ "$PWD" == "$CLAUDE_PLUGIN_ROOT" ]]; then
    echo "connect-plugin: refusing to auto-detect the harness root as a target; pass --plugin <path>" >&2
    exit 1
  fi
  PLUGIN_PATH="$PWD"
fi

if [[ ! -d "$PLUGIN_PATH" ]]; then
  echo "connect-plugin: plugin path is not a directory: $PLUGIN_PATH" >&2
  exit 1
fi

manifest_file="${PLUGIN_PATH}/.claude-plugin/plugin.json"
if [[ ! -f "$manifest_file" ]]; then
  echo "connect-plugin: missing .claude-plugin/plugin.json under $PLUGIN_PATH" >&2
  exit 1
fi

plugin_name="$(jq -r '.name // ""' "$manifest_file")"
plugin_version="$(jq -r '.version // ""' "$manifest_file")"
if [[ -z "$plugin_name" ]]; then
  echo "connect-plugin: plugin.json missing .name" >&2
  exit 1
fi

skills_dir="${PLUGIN_PATH}/skills"
skills_json='[]'
if [[ -d "$skills_dir" ]]; then
  skills_json="$(find "$skills_dir" -mindepth 2 -maxdepth 2 -name SKILL.md ! -type l \
    | sed -E 's#.*/skills/([^/]+)/SKILL.md#\1#' \
    | sort \
    | jq -R -s 'split("\n") | map(select(length > 0))')"
fi

git_sha=""
if git -C "$PLUGIN_PATH" rev-parse HEAD >/dev/null 2>&1; then
  git_sha="$(git -C "$PLUGIN_PATH" rev-parse HEAD)"
fi

run_id_hex="$(openssl rand -hex 4)"

jq -n \
  --arg path "$PLUGIN_PATH" \
  --arg name "$plugin_name" \
  --arg version "$plugin_version" \
  --arg sha "$git_sha" \
  --argjson skills "$skills_json" \
  --arg hex "$run_id_hex" \
  '{target: {path: $path, plugin_name: $name, plugin_version: $version, git_sha: $sha, skills: $skills}, harness_version: "0.1.0", run_id: ((now | strftime("%Y-%m-%dT%H-%M-%SZ")) + "-" + $hex), started_at: (now | todateiso8601)}'

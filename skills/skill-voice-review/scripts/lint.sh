#!/usr/bin/env bash
set -euo pipefail

# Invariant: lint.sh emits a single JSON object to stdout with keys {skill, designSha, runId, summary, findings, verdict}.
# Invariant: non-zero exit on schema violation, lint engine errors, or REJECT_CRITICAL verdict. Exit 0 on ACCEPT / ACCEPT_WITH_MINOR.
# Invariant: when invoked with --source-only, lint.sh only defines functions and does not execute main logic.
if [[ "${1:-}" == "--source-only" ]]; then
  _LINT_SOURCE_ONLY=1
  shift
fi

# Invariant: --mode {self|cross-plugin} controls rule filtering. Default self runs every rule.
# Invariant: cross-plugin skips rules whose kind == "plugin-policy" before dispatch.
# Invariant: --plugin-root-only runs ONLY rules with detector.scope == "plugin-root" against --target <plugin-root>.
# Invariant: without --plugin-root-only, rules with detector.scope == "plugin-root" are skipped (pre-pass owns them).
LINT_MODE="self"
PLUGIN_ROOT_ONLY=0
TARGET_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      LINT_MODE="$2"
      shift 2
      ;;
    --plugin-root-only)
      PLUGIN_ROOT_ONLY=1
      shift
      ;;
    --target)
      TARGET_PATH="$2"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

case "$LINT_MODE" in
  self|cross-plugin) ;;
  *) echo "lint.sh: --mode must be 'self' or 'cross-plugin', got '$LINT_MODE'" >&2; exit 64 ;;
esac

if [[ "$PLUGIN_ROOT_ONLY" == "1" && -z "$TARGET_PATH" ]]; then
  echo "lint.sh: --plugin-root-only requires --target <plugin-root>" >&2
  exit 64
fi

# detect_find_extensions <dir> <json-allowlist-array> → findings JSON array on stdout
detect_find_extensions() {
  local dir="$1"
  local allowlist_json="$2"
  local allow_args=()
  local ext
  while IFS= read -r ext; do
    allow_args+=( -o -name "*$ext" )
  done < <(printf '%s' "$allowlist_json" | jq -r '.[]')
  if (( ${#allow_args[@]} == 0 )); then
    echo '[]'; return
  fi
  allow_args=("${allow_args[@]:1}")
  local violations
  violations="$(find "$dir" -type f \( ! \( "${allow_args[@]}" \) \) -print 2>/dev/null || true)"
  if [[ -z "$violations" ]]; then
    echo '[]'; return
  fi
  printf '%s\n' "$violations" | jq -R -s 'split("\n") | map(select(length > 0)) | map({location: {path: .}, message: "disallowed file extension", excerpt: null})'
}

# detect_grep_denylist <skill-path> <denylist-json-object> [field=entries] → findings JSON array
# Invariant: reads the named array (entries or warnings) from the denylist; no per-finding severity — dispatcher tags from rule-level severity.
detect_grep_denylist() {
  local skill="$1"
  local denylist="$2"
  local field="${3:-entries}"
  local patterns
  patterns="$(printf '%s' "$denylist" | jq -r --arg f "$field" '(.[$f] // []) | .[]')"
  local findings='[]'
  [[ -z "$patterns" ]] && { echo "$findings"; return; }
  local word line_num line_content
  while IFS= read -r word; do
    while IFS=: read -r line_num line_content; do
      [[ -z "$line_num" ]] && continue
      findings="$(printf '%s' "$findings" | jq --arg word "$word" --arg ln "$line_num" --arg ex "$line_content" \
        '. + [{location:{line:($ln|tonumber)}, message:("denylist hit: "+$word), excerpt:$ex}]')"
    done < <(grep -niw -E "\\b${word}\\b" "$skill" 2>/dev/null || true)
  done <<< "$patterns"
  echo "$findings"
}

# detect_grep_required <skill-path> <config-json> → findings JSON array
detect_grep_required() {
  local skill="$1"
  local cfg="$2"
  local pattern
  pattern="$(printf '%s' "$cfg" | jq -r '.pattern')"
  if grep -qF -- "$pattern" "$skill"; then
    echo '[]'
  else
    jq -n --arg p "$pattern" '[{location:null, message:("required pattern missing: "+$p), excerpt:null}]'
  fi
}

# extract_section <skill-path> <section-name> → section body on stdout
extract_section() {
  local skill="$1"
  local name="$2"
  awk -v target="$name" '
    BEGIN {
      emit=0
      gsub(/^the-/, "", target)
    }
    /^## / {
      hdr=tolower($0)
      gsub(/^## /, "", hdr)
      gsub(/^the /, "", hdr)
      gsub(/[^a-z0-9]+/, "-", hdr)
      sub(/^-/, "", hdr); sub(/-$/, "", hdr)
      if (hdr == target) { emit=1; next }
      if (emit) exit
    }
    /<\/HARD-GATE>/ { if (target == "hard-gate-blocks" && emit) { emit=0; next } }
    /<HARD-GATE>/   { if (target == "hard-gate-blocks") { emit=1; next } }
    emit { print }
  ' "$skill"
}

# detect_regex_line <skill-path> <config-json> → findings JSON array on stdout
detect_regex_line() {
  local skill="$1"
  local cfg="$2"
  local section must_match must_not_match first_must
  section="$(printf '%s' "$cfg" | jq -r '.section')"
  must_match="$(printf '%s' "$cfg" | jq -r '.["must-match"] // empty')"
  must_not_match="$(printf '%s' "$cfg" | jq -r '.["must-not-match"] // empty')"
  first_must="$(printf '%s' "$cfg" | jq -r '.["first-sentence-must-match"] // empty')"

  local body
  body="$(extract_section "$skill" "$section")"
  [[ -z "$body" ]] && echo '[]' && return

  local findings='[]'
  local line_num=0 line
  while IFS= read -r line; do
    line_num=$((line_num + 1))
    if [[ -n "$must_match" && -n "$line" ]]; then
      if ! printf '%s' "$line" | grep -qE -- "$must_match"; then
        findings="$(printf '%s' "$findings" | jq --arg ln "$line_num" --arg ex "$line" --arg s "$section" \
          '. + [{location:{line:($ln|tonumber)}, message:("regex-line must-match failed in "+$s), excerpt:$ex}]')"
      fi
    fi
    if [[ -n "$must_not_match" && -n "$line" ]]; then
      if printf '%s' "$line" | grep -qE -- "$must_not_match"; then
        findings="$(printf '%s' "$findings" | jq --arg ln "$line_num" --arg ex "$line" --arg s "$section" \
          '. + [{location:{line:($ln|tonumber)}, message:("regex-line must-not-match hit in "+$s), excerpt:$ex}]')"
      fi
    fi
  done <<< "$body"

  if [[ -n "$first_must" ]]; then
    local first_sentence
    first_sentence="$(printf '%s' "$body" | awk '/^[^-[:space:]]/ {print; exit}')"
    if [[ -n "$first_sentence" ]] && ! printf '%s' "$first_sentence" | grep -qE -- "$first_must"; then
      findings="$(printf '%s' "$findings" | jq --arg ex "$first_sentence" --arg s "$section" \
        '. + [{location:null, message:("first-sentence-must-match failed in "+$s), excerpt:$ex}]')"
    fi
  fi

  echo "$findings"
}

# detect_bash_syntax <skill-path> <config-json> → findings JSON array on stdout
detect_bash_syntax() {
  local skill="$1"
  local cfg="$2"
  local section
  section="$(printf '%s' "$cfg" | jq -r '.section')"

  local body
  body="$(extract_section "$skill" "$section")"
  [[ -z "$body" ]] && echo '[]' && return

  local fence
  fence="$(printf '%s\n' "$body" | awk '/^```(bash|sh)/ {f=1; next} /^```/ {if(f){exit}} f {print}')"
  [[ -z "$fence" ]] && echo '[]' && return

  local stderr_out
  if stderr_out="$(printf '%s\n' "$fence" | bash -n 2>&1)"; then
    echo '[]'
  else
    jq -n --arg err "$stderr_out" --arg s "$section" \
      '[{location:null, message:("bash-syntax error in "+$s), excerpt:$err}]'
  fi
}

# detect_dot_parse <skill-path> <config-json> → findings JSON array on stdout
detect_dot_parse() {
  local skill="$1"
  local cfg="$2"
  local section
  section="$(printf '%s' "$cfg" | jq -r '.section')"

  local body
  body="$(extract_section "$skill" "$section")"
  [[ -z "$body" ]] && echo '[]' && return

  local fence
  fence="$(printf '%s\n' "$body" | awk '/^```dot/ {f=1; next} /^```/ {if(f){exit}} f {print}')"
  [[ -z "$fence" ]] && echo '[]' && return

  local stderr_out
  if stderr_out="$(printf '%s\n' "$fence" | dot -Tcanon 2>&1 >/dev/null)"; then
    echo '[]'
  else
    jq -n --arg err "$stderr_out" --arg s "$section" \
      '[{location:null, message:("dot-parse failed in "+$s), excerpt:$err}]'
  fi
}

if [[ -z "${_LINT_SOURCE_ONLY:-}" ]]; then

if [[ "$PLUGIN_ROOT_ONLY" == "1" ]]; then
  [[ -d "$TARGET_PATH" ]] || { echo "lint: target dir not found: $TARGET_PATH" >&2; exit 66; }
  SKILL_PATH=""
else
  if [[ $# -lt 1 ]]; then
    echo "usage: lint.sh <path-to-SKILL.md>" >&2
    exit 64
  fi
  SKILL_PATH="$1"
  [[ -f "$SKILL_PATH" ]] || { echo "lint: file not found: $SKILL_PATH" >&2; exit 66; }
fi

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REF="$(cd "${HERE}/../references" && pwd)"
RULES_FILE="${REF}/lint-rules.json"

# resolve_manifest → merged-rules-json on stdout
resolve_manifest() {
  local base_manifest="${REF}/lint-rules.json"

  if [[ ! -f "$base_manifest" ]]; then
    echo '{"schemaVersion":"1.0","rules":[]}'
    return
  fi

  if [[ "$PLUGIN_ROOT_ONLY" == "1" || -z "$SKILL_PATH" ]]; then
    cat "$base_manifest"
    return
  fi

  local skill_dir
  skill_dir="$(dirname "$SKILL_PATH")"
  local local_manifest="${skill_dir}/lint.json"

  if [[ ! -f "$local_manifest" ]]; then
    cat "$base_manifest"
    return
  fi

  local extends_val
  extends_val="$(jq -r '.extends // empty' "$local_manifest")"
  if [[ "$extends_val" == "skill-cheat:baseline" ]]; then
    jq -s '
      .[0].rules as $base
      | .[1].rules as $local
      | (.[1].disable // []) as $disabled
      | (.[1].rules // [] | map(.id)) as $local_ids
      | ($base | map(select(.id as $id | ($local_ids | index($id)) | not))
               | map(select(.id as $id | ($disabled | index($id)) | not))) as $kept
      | { schemaVersion: .[0].schemaVersion, rules: ($kept + $local) }
    ' "$base_manifest" "$local_manifest"
  else
    cat "$local_manifest"
  fi
}

RULES_JSON="$(resolve_manifest)"

findings_json='[]'
critical=0
important=0
minor=0
passed=0

dispatch_detector() {
  local rule="$1"
  local rule_id dtype severity cfg
  rule_id="$(printf '%s' "$rule" | jq -r '.id')"
  dtype="$(printf '%s' "$rule" | jq -r '.detector.type')"
  severity="$(printf '%s' "$rule" | jq -r '.severity')"
  cfg="$(printf '%s' "$rule" | jq -c '.detector')"

  local raw='[]'

  case "$dtype" in
    find-extensions)
      local scope
      scope="$(printf '%s' "$cfg" | jq -r '.scope // "plugin-root"')"
      if [[ "$scope" == "plugin-root" ]]; then
        local plugin_root
        if [[ "$PLUGIN_ROOT_ONLY" == "1" ]]; then
          plugin_root="$TARGET_PATH"
        else
          plugin_root="$(dirname "$(dirname "$(dirname "$SKILL_PATH")")")"
        fi
        local allowlist
        allowlist="$(printf '%s' "$cfg" | jq -c '.allowlist')"
        raw="$(detect_find_extensions "$plugin_root" "$allowlist")"
      fi
      ;;
    grep-denylist)
      local denylist field
      field="$(printf '%s' "$cfg" | jq -r '.field // "entries"')"
      if printf '%s' "$cfg" | jq -e '.source' >/dev/null; then
        local src
        src="$(printf '%s' "$cfg" | jq -r '.source')"
        denylist="$(cat "${REF}/../${src}")"
      else
        denylist="$(printf '%s' "$cfg" | jq -c '{entries: .["inline-entries"]}')"
      fi
      raw="$(detect_grep_denylist "$SKILL_PATH" "$denylist" "$field")"
      ;;
    grep-required)
      raw="$(detect_grep_required "$SKILL_PATH" "$cfg")"
      ;;
    regex-line)
      raw="$(detect_regex_line "$SKILL_PATH" "$cfg")"
      ;;
    bash-syntax)
      raw="$(detect_bash_syntax "$SKILL_PATH" "$cfg")"
      ;;
    dot-parse)
      raw="$(detect_dot_parse "$SKILL_PATH" "$cfg")"
      ;;
    yaml-frontmatter|section-order|cross-reference|hard-gate-span|rationalization-table-cells)
      local js_out
      js_out="$(node "${HERE}/lint.js" --detector "$dtype" --skill "$SKILL_PATH" --config "$cfg" 2>/dev/null)"
      raw="$(printf '%s' "$js_out" | jq -c '.findings // []')"
      ;;
  esac

  local count
  count="$(printf '%s' "$raw" | jq 'length')"
  if [[ "$count" == "0" ]]; then
    passed=$((passed + 1))
    return
  fi

  case "$severity" in
    CRITICAL)  critical=$((critical + count)) ;;
    IMPORTANT) important=$((important + count)) ;;
    MINOR)     minor=$((minor + count)) ;;
  esac

  local tagged
  tagged="$(printf '%s' "$raw" | jq --arg id "$rule_id" --arg sev "$severity" 'map(. + {ruleId:$id, severity:$sev})')"
  findings_json="$(printf '%s' "$findings_json" | jq --argjson extra "$tagged" '. + $extra')"
}

count="$(printf '%s' "$RULES_JSON" | jq '.rules | length')"
for (( i=0; i<count; i++ )); do
  rule="$(printf '%s' "$RULES_JSON" | jq -c ".rules[$i]")"
  rule_kind="$(printf '%s' "$rule" | jq -r '.kind // "plugin-policy"')"
  if [[ "$LINT_MODE" == "cross-plugin" && "$rule_kind" == "plugin-policy" ]]; then
    continue
  fi
  rule_scope="$(printf '%s' "$rule" | jq -r '.detector.scope // empty')"
  if [[ "$PLUGIN_ROOT_ONLY" == "1" ]]; then
    [[ "$rule_scope" == "plugin-root" ]] || continue
  else
    [[ "$rule_scope" != "plugin-root" ]] || continue
  fi
  dispatch_detector "$rule"
done

if (( critical > 0 )); then verdict="REJECT_CRITICAL"
elif (( important > 0 )); then verdict="REJECT_IMPORTANT"
elif (( minor > 0 )); then verdict="ACCEPT_WITH_MINOR"
else verdict="ACCEPT"
fi

skill_arg="$SKILL_PATH"
[[ "$PLUGIN_ROOT_ONLY" == "1" ]] && skill_arg="$TARGET_PATH"

jq -n \
  --arg skill "$skill_arg" \
  --arg runId "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson critical "$critical" \
  --argjson important "$important" \
  --argjson minor "$minor" \
  --argjson passed "$passed" \
  --argjson findings "$findings_json" \
  --arg verdict "$verdict" \
  '{skill:$skill, designSha:null, runId:$runId, summary:{critical:$critical, important:$important, minor:$minor, passed:$passed}, findings:$findings, verdict:$verdict}'

case "$verdict" in
  REJECT_CRITICAL) exit 1 ;;
  *) exit 0 ;;
esac

fi

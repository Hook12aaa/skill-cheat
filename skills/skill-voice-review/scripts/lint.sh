#!/usr/bin/env bash
set -euo pipefail

# Invariant: lint.sh emits a single JSON object to stdout with keys {skill, designSha, runId, summary, findings, verdict}.
# Invariant: non-zero exit on schema violation, lint engine errors, or REJECT_CRITICAL verdict. Exit 0 on ACCEPT / ACCEPT_WITH_MINOR.
# Invariant: when invoked with --source-only, lint.sh only defines functions and does not execute main logic.
if [[ "${1:-}" == "--source-only" ]]; then
  _LINT_SOURCE_ONLY=1
  shift
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

# detect_grep_denylist <skill-path> <denylist-json-object> → findings JSON array
detect_grep_denylist() {
  local skill="$1"
  local denylist="$2"
  local patterns
  patterns="$(printf '%s' "$denylist" | jq -r '.entries[]')"
  local findings='[]'
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
    /<\/HARD-GATE>/ { if (target == "hard-gate-blocks" && emit) { print; emit=0; next } }
    /<HARD-GATE>/   { if (target == "hard-gate-blocks") { emit=1; print; next } }
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
    if [[ -n "$must_match" && "$line" =~ ^-\ .+ ]]; then
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

if [[ -z "${_LINT_SOURCE_ONLY:-}" ]]; then

if [[ $# -lt 1 ]]; then
  echo "usage: lint.sh <path-to-SKILL.md>" >&2
  exit 64
fi

SKILL_PATH="$1"
[[ -f "$SKILL_PATH" ]] || { echo "lint: file not found: $SKILL_PATH" >&2; exit 66; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REF="$(cd "${HERE}/../references" && pwd)"
RULES_FILE="${REF}/lint-rules.json"

if [[ ! -f "$RULES_FILE" ]]; then
  RULES_JSON='{"schemaVersion":"1.0","rules":[]}'
else
  RULES_JSON="$(cat "$RULES_FILE")"
fi

findings_json='[]'
critical=0
important=0
minor=0
passed=0

dispatch_detector() {
  passed=$((passed + 1))
}

count="$(printf '%s' "$RULES_JSON" | jq '.rules | length')"
for (( i=0; i<count; i++ )); do
  rule="$(printf '%s' "$RULES_JSON" | jq -c ".rules[$i]")"
  dispatch_detector "$rule"
done

if (( critical > 0 )); then verdict="REJECT_CRITICAL"
elif (( important > 0 )); then verdict="REJECT_IMPORTANT"
elif (( minor > 0 )); then verdict="ACCEPT_WITH_MINOR"
else verdict="ACCEPT"
fi

jq -n \
  --arg skill "$SKILL_PATH" \
  --arg runId "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson critical "$critical" \
  --argjson important "$important" \
  --argjson minor "$minor" \
  --argjson passed "$passed" \
  --argjson findings "$findings_json" \
  --arg verdict "$verdict" \
  '{skill:$skill, designSha:null, runId:$runId, summary:{critical:$critical, important:$important, minor:$minor, passed:$passed}, findings:$findings, verdict:$verdict}'

case "$verdict" in
  REJECT_CRITICAL|REJECT_IMPORTANT) exit 1 ;;
  *) exit 0 ;;
esac

fi

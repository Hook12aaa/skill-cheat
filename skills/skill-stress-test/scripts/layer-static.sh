#!/usr/bin/env bash
set -euo pipefail

# Invariant: emits a single JSON object {verdict, plugin_findings[], per_skill[]} on stdout.
# Invariant: per_skill order matches enumeration order from connect-plugin.sh; deterministic by sorted skill name.
# Invariant: layer verdict is the worst across plugin_findings severity and per_skill verdicts.
# Invariant: plugin_findings comes from a single lint.sh --plugin-root-only --mode cross-plugin pre-pass.
# Invariant: per-skill loop invokes lint.sh --mode cross-plugin, filtering plugin-policy rules.
# Invariant: empty enumeration emits {verdict: INCONCLUSIVE, plugin_findings, per_skill: [], reason}.
# Invariant: symlinked SKILL.md or SKILL.md outside skills/<name>/ depth refuses with INCONCLUSIVE.
# Invariant: lint.sh crash or non-JSON output yields per-skill INCONCLUSIVE; unknown verdict tokens exit non-zero.

TARGET=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2 ;;
    *) echo "layer-static: unknown arg $1" >&2; exit 64 ;;
  esac
done

[[ -n "$TARGET" ]] || { echo "layer-static: --target required" >&2; exit 64; }
[[ -d "$TARGET" ]] || { echo "layer-static: target is not a directory: $TARGET" >&2; exit 1; }

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
lint_script="${SKILL_CHEAT_LINT_OVERRIDE:-${script_dir}/../../skill-voice-review/scripts/lint.sh}"
[[ -f "$lint_script" ]] || { echo "layer-static: lint.sh not found at $lint_script" >&2; exit 1; }

rank() {
  case "$1" in
    ACCEPT) echo 0 ;;
    ACCEPT_WITH_MINOR) echo 1 ;;
    REJECT_IMPORTANT) echo 2 ;;
    REJECT_CRITICAL) echo 3 ;;
    INCONCLUSIVE) echo 4 ;;
    *) echo 5 ;;
  esac
}

plugin_findings='[]'
set +e
pre_pass_out="$(bash "$lint_script" --plugin-root-only --mode cross-plugin --target "$TARGET" 2>/dev/null)"
pre_pass_status=$?
set -e
if [[ $pre_pass_status -eq 0 || $pre_pass_status -eq 1 ]]; then
  pre_pass_verdict="$(printf '%s' "$pre_pass_out" | jq -r '.verdict // "INCONCLUSIVE"' 2>/dev/null || echo "INCONCLUSIVE")"
  case "$pre_pass_verdict" in
    ACCEPT|ACCEPT_WITH_MINOR|REJECT_IMPORTANT|REJECT_CRITICAL)
      plugin_findings="$(printf '%s' "$pre_pass_out" | jq -c '.findings // []' 2>/dev/null || echo '[]')"
      ;;
    *)
      plugin_findings='[]'
      ;;
  esac
fi

skills_dir="${TARGET}/skills"

if [[ ! -d "$skills_dir" ]]; then
  jq -n --argjson pf "$plugin_findings" \
    '{verdict: "INCONCLUSIVE", plugin_findings: $pf, per_skill: [], reason: "no skills/ directory under target"}'
  exit 0
fi

skills_dir_real="$(cd "$skills_dir" && pwd -P)"

skill_md_files=()
while IFS= read -r -d '' f; do
  skill_md_files+=("$f")
done < <(find "$skills_dir" -mindepth 2 -maxdepth 2 -name SKILL.md ! -type l -print0 2>/dev/null | sort -z)

all_skill_md=()
while IFS= read -r -d '' f; do
  all_skill_md+=("$f")
done < <(find "$skills_dir" -name SKILL.md ! -type l -print0 2>/dev/null | sort -z)

bad_depth_files=()
prefix="${skills_dir%/}/"
for f in "${all_skill_md[@]:-}"; do
  [[ -z "$f" ]] && continue
  rel="${f#$prefix}"
  case "$rel" in
    */*/*) bad_depth_files+=("$f") ;;
    SKILL.md) bad_depth_files+=("$f") ;;
    */SKILL.md) ;;
    *) bad_depth_files+=("$f") ;;
  esac
done

if [[ ${#bad_depth_files[@]} -gt 0 ]]; then
  joined="$(printf '%s\n' "${bad_depth_files[@]}")"
  echo "layer-static: SKILL.md found at unsupported depth:" >&2
  printf '  %s\n' "${bad_depth_files[@]}" >&2
  jq -n --arg r "SKILL.md found at unsupported depth; only skills/<name>/SKILL.md is enumerated" --arg paths "$joined" --argjson pf "$plugin_findings" \
    '{verdict: "INCONCLUSIVE", plugin_findings: $pf, per_skill: [], reason: $r, offending_paths: ($paths | split("\n") | map(select(length>0)))}'
  exit 0
fi

bad_symlink_files=()
while IFS= read -r -d '' f; do
  bad_symlink_files+=("$f")
done < <(find "$skills_dir" -mindepth 2 -maxdepth 2 -name SKILL.md -type l -print0 2>/dev/null | sort -z)

if [[ ${#bad_symlink_files[@]} -gt 0 ]]; then
  joined="$(printf '%s\n' "${bad_symlink_files[@]}")"
  echo "layer-static: symlinked SKILL.md not permitted:" >&2
  printf '  %s\n' "${bad_symlink_files[@]}" >&2
  jq -n --arg r "symlinked SKILL.md not permitted" --arg paths "$joined" --argjson pf "$plugin_findings" \
    '{verdict: "INCONCLUSIVE", plugin_findings: $pf, per_skill: [], reason: $r, offending_paths: ($paths | split("\n") | map(select(length>0)))}'
  exit 0
fi

for f in "${skill_md_files[@]}"; do
  resolved="$(cd "$(dirname "$f")" && pwd -P)/$(basename "$f")"
  case "$resolved" in
    "${skills_dir_real}"/*) ;;
    *)
      echo "layer-static: resolved SKILL.md escapes skills/: $f -> $resolved" >&2
      jq -n --arg r "SKILL.md resolves outside skills/ tree" --arg p "$f" --arg target "$resolved" --argjson pf "$plugin_findings" \
        '{verdict: "INCONCLUSIVE", plugin_findings: $pf, per_skill: [], reason: $r, offending_path: $p, resolved_to: $target}'
      exit 0
      ;;
  esac
done

if [[ ${#skill_md_files[@]} -eq 0 ]]; then
  jq -n --argjson pf "$plugin_findings" \
    '{verdict: "INCONCLUSIVE", plugin_findings: $pf, per_skill: [], reason: "no SKILL.md files found under skills/"}'
  exit 0
fi

per_skill='[]'
worst="ACCEPT"

for f in "${skill_md_files[@]}"; do
  skill_name="$(basename "$(dirname "$f")")"
  lint_stderr_file="$(mktemp -t layer-static-lint-stderr.XXXXXX)"
  set +e
  lint_out="$(bash "$lint_script" --mode cross-plugin "$f" 2>"$lint_stderr_file")"
  lint_status=$?
  set -e
  lint_stderr="$(cat "$lint_stderr_file" 2>/dev/null || true)"
  rm -f "$lint_stderr_file"

  if printf '%s' "$lint_out" | jq -e '.verdict' >/dev/null 2>&1; then
    v="$(printf '%s' "$lint_out" | jq -r '.verdict')"
    findings="$(printf '%s' "$lint_out" | jq -c '.findings // []')"
    case "$v" in
      ACCEPT|ACCEPT_WITH_MINOR|REJECT_IMPORTANT|REJECT_CRITICAL|INCONCLUSIVE) ;;
      *)
        echo "layer-static: unknown verdict from lint.sh: $v" >&2
        exit 1
        ;;
    esac
    entry="$(jq -n --arg s "$skill_name" --arg v "$v" --argjson f "$findings" '{skill: $s, verdict: $v, findings: $f}')"
    per_skill="$(printf '%s' "$per_skill" | jq --argjson e "$entry" '. + [$e]')"
    if (( $(rank "$v") > $(rank "$worst") )); then
      worst="$v"
    fi
    continue
  fi

  if [[ $lint_status -ne 0 ]]; then
    finding="$(jq -n --arg s "$lint_stderr" --argjson code $lint_status \
      '{rule_id: "LINT-CRASH", severity: "INCONCLUSIVE", message: "lint.sh exited non-zero with no parsable .verdict", exit_code: $code, stderr: $s}')"
  else
    finding="$(jq -n --arg out "$lint_out" --arg err "$lint_stderr" \
      '{rule_id: "LINT-NONJSON", severity: "INCONCLUSIVE", message: "lint.sh produced output without a .verdict field", stdout: $out, stderr: $err}')"
  fi
  entry="$(jq -n --arg s "$skill_name" --argjson f "[$finding]" \
    '{skill: $s, verdict: "INCONCLUSIVE", findings: $f}')"
  per_skill="$(printf '%s' "$per_skill" | jq --argjson e "$entry" '. + [$e]')"
  if (( $(rank "INCONCLUSIVE") > $(rank "$worst") )); then
    worst="INCONCLUSIVE"
  fi
done

plugin_findings_worst="ACCEPT"
n_critical="$(printf '%s' "$plugin_findings" | jq '[.[] | select(.severity == "CRITICAL")] | length')"
n_important="$(printf '%s' "$plugin_findings" | jq '[.[] | select(.severity == "IMPORTANT")] | length')"
n_minor="$(printf '%s' "$plugin_findings" | jq '[.[] | select(.severity == "MINOR")] | length')"
if (( n_critical > 0 )); then plugin_findings_worst="REJECT_CRITICAL"
elif (( n_important > 0 )); then plugin_findings_worst="REJECT_IMPORTANT"
elif (( n_minor > 0 )); then plugin_findings_worst="ACCEPT_WITH_MINOR"
fi

if (( $(rank "$plugin_findings_worst") > $(rank "$worst") )); then
  worst="$plugin_findings_worst"
fi

jq -n --arg v "$worst" --argjson p "$per_skill" --argjson pf "$plugin_findings" \
  '{verdict: $v, plugin_findings: $pf, per_skill: $p}'

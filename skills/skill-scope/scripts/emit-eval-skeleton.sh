#!/usr/bin/env bash
set -euo pipefail

# Invariant: stdin input path in $1; emits eval-set-skeleton JSON to stdout; exits non-zero on schema violation.
# Invariant: positive case per triggers[] entry; five adversarial negatives (patterns 1-5 per adversarial-eval-patterns.md).

if [[ $# -lt 1 ]]; then
  echo "usage: emit-eval-skeleton.sh <scope.json>" >&2
  exit 64
fi

SCOPE="$1"
[[ -f "$SCOPE" ]] || { echo "emit-eval-skeleton: scope file not found: $SCOPE" >&2; exit 66; }

skill_name="$(jq -r '.name' "$SCOPE")"
[[ -n "$skill_name" && "$skill_name" != "null" ]] || { echo "emit-eval-skeleton: scope.name required" >&2; exit 65; }

triggers_count="$(jq '.triggers | if type == "array" then length else 0 end' "$SCOPE")"
[[ "$triggers_count" -gt 0 ]] || { echo "emit-eval-skeleton: scope.triggers[] must be a non-empty array" >&2; exit 65; }

positives_json="$(jq -c '
  [.triggers[] |
    {
      query: ("<TODO: realistic user prompt matching trigger: " + .value + ">"),
      shouldTrigger: true,
      note: ("derived from trigger kind=" + .kind + " value=" + .value)
    }
  ]
' "$SCOPE")"

adversarial_json='[
  {"query": "<TODO: trigger-collision case — shares keywords with adjacent skill>", "shouldTrigger": false, "note": "adversarial/trigger-collision"},
  {"query": "<TODO: instruction-injection case — embedded coerce-to-trigger prose>", "shouldTrigger": false, "note": "adversarial/instruction-injection"},
  {"query": "", "shouldTrigger": false, "note": "adversarial/degenerate-prompt"},
  {"query": "<TODO: single-keyword-without-context case>", "shouldTrigger": false, "note": "adversarial/keyword-without-context"},
  {"query": "<TODO: cross-skill-ambiguity case — sibling skill should win>", "shouldTrigger": false, "note": "adversarial/cross-skill-ambiguity"}
]'

jq -n \
  --arg name "$skill_name" \
  --argjson pos "$positives_json" \
  --argjson adv "$adversarial_json" \
  '{
    skillName: $name,
    cases: (
      (($pos + $adv)
       | to_entries
       | map(.value + {id: (.key + 1)})
      )
    )
  }'

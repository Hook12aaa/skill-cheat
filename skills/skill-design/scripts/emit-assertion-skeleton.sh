#!/usr/bin/env bash
set -euo pipefail

# Invariant: named args --skill-name --design-json --design-md; emits assertion-skeleton JSON to stdout.
# Invariant: one assertion per hardGates[] (type=hard-gate-violation-absent); one per gateFunctions[] (type=gate-function-question).
# Invariant: empty hardGates[] or gateFunctions[] exits 65 with a named diagnostic.

SKILL_NAME=""
DESIGN_JSON=""
DESIGN_MD=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skill-name)  SKILL_NAME="$2";  shift 2 ;;
    --design-json) DESIGN_JSON="$2"; shift 2 ;;
    --design-md)   DESIGN_MD="$2";   shift 2 ;;
    *) echo "emit-assertion-skeleton: unknown arg $1" >&2; exit 64 ;;
  esac
done
[[ -n "$SKILL_NAME" ]]                || { echo "emit-assertion-skeleton: --skill-name required" >&2; exit 65; }
[[ -f "$DESIGN_JSON" ]]               || { echo "emit-assertion-skeleton: --design-json file not found: $DESIGN_JSON" >&2; exit 66; }
[[ -f "$DESIGN_MD" ]]                 || { echo "emit-assertion-skeleton: --design-md file not found: $DESIGN_MD" >&2; exit 66; }

hg_count="$(jq '.hardGates | if type == "array" then length else 0 end' "$DESIGN_JSON")"
[[ "$hg_count" -gt 0 ]] || { echo "emit-assertion-skeleton: design.hardGates[] must be a non-empty array" >&2; exit 65; }

gf_count="$(jq '.gateFunctions | if type == "array" then length else 0 end' "$DESIGN_JSON")"
[[ "$gf_count" -gt 0 ]] || { echo "emit-assertion-skeleton: design.gateFunctions[] must be a non-empty array" >&2; exit 65; }

hg_json="$(jq -c '
  [.hardGates[] |
    {
      type: "hard-gate-violation-absent",
      pattern: .body,
      evidence: ("run output must not violate hard-gate id=" + (.id|tostring))
    }
  ]
' "$DESIGN_JSON")"

gf_json="$(jq -c '
  [.gateFunctions[] |
    {
      type: "gate-function-question",
      pattern: ("BEFORE " + .before + ": " + .question),
      evidence: ("agent must behave as if the answer to the question is known before " + .before)
    }
  ]
' "$DESIGN_JSON")"

jq -n \
  --arg name "$SKILL_NAME" \
  --argjson hg "$hg_json" \
  --argjson gf "$gf_json" \
  '{
    skillName: $name,
    assertions: (
      (($hg + $gf)
       | to_entries
       | map(.value + {id: (.key + 1)})
      )
    )
  }'

#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EMIT="${HERE}/skills/skill-design/scripts/emit-assertion-skeleton.sh"
DJSON="${HERE}/tests/integration/fixtures/sample-design.json"
DMD="${HERE}/tests/integration/fixtures/sample-design.md"
SKILL_NAME="my-skill"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bash "$EMIT" --skill-name "$SKILL_NAME" --design-json "$DJSON" --design-md "$DMD" > "${tmp}/out.json"

got="$(jq -r '.skillName' "${tmp}/out.json")"
[[ "$got" == "$SKILL_NAME" ]] || { echo "FAIL: skillName=$got"; exit 1; }

hg="$(jq '[.assertions[] | select(.type == "hard-gate-violation-absent")] | length' "${tmp}/out.json")"
[[ "$hg" == "1" ]] || { echo "FAIL: hard-gate assertions=$hg (want 1)"; exit 1; }

gf="$(jq '[.assertions[] | select(.type == "gate-function-question")] | length' "${tmp}/out.json")"
[[ "$gf" == "2" ]] || { echo "FAIL: gate-function assertions=$gf (want 2)"; exit 1; }

total="$(jq '.assertions | length' "${tmp}/out.json")"
unique_ids="$(jq '[.assertions[].id] | unique | length' "${tmp}/out.json")"
[[ "$total" == "$unique_ids" ]] || { echo "FAIL: duplicate assertion ids"; exit 1; }

# Invariant: missing or empty hardGates[] exits non-zero with a clear diagnostic.
printf '%s\n' '{"schemaVersion":"1.0","hardGates":[],"gateFunctions":[{"before":"x","question":"y?"}],"antiPatternFirstSentence":"\"x\"","checklistSteps":["x"]}' > "${tmp}/no-gates.json"
if bash "$EMIT" --skill-name "x" --design-json "${tmp}/no-gates.json" --design-md "$DMD" >/dev/null 2>"${tmp}/err"; then
  echo "FAIL: emitter accepted empty hardGates[] (should exit non-zero)"; exit 1
fi
grep -q "hardGates" "${tmp}/err" || { echo "FAIL: empty-hardGates diagnostic missing; stderr was: $(cat "${tmp}/err")"; exit 1; }

echo "PASS: emit-assertion-skeleton"

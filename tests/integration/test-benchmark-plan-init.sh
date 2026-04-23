#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INIT="${HERE}/skills/skill-voice-review/scripts/benchmark-plan-init.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

SCOPE="${HERE}/tests/integration/fixtures/sample-scope.json"
cat > "${tmp}/eval-set.json" <<'EOF'
{"skillName":"my-skill","cases":[{"id":1,"query":"q1","shouldTrigger":true,"note":"n"}]}
EOF
cat > "${tmp}/assertions.json" <<'EOF'
{"skillName":"my-skill","assertions":[{"id":1,"type":"hard-gate-violation-absent","pattern":"Do NOT X","evidence":"e"}]}
EOF

bash "$INIT" \
  --scope "$SCOPE" \
  --eval-set "${tmp}/eval-set.json" \
  --assertions "${tmp}/assertions.json" \
  --baseline-ref HEAD \
  --candidate-ref working-copy \
  --baseline-path "${tmp}/b" \
  --candidate-path "${tmp}/c" \
  --out-dir "${tmp}/plan"

PJSON="${tmp}/plan/benchmark-plan.json"
PMD="${tmp}/plan/benchmark-plan.md"
PSHA="${tmp}/plan/benchmark-plan.md.sha256"

for f in "$PJSON" "$PMD" "$PSHA"; do
  [[ -f "$f" ]] || { echo "FAIL: missing $f"; exit 1; }
done

# Invariant: baseline-first in worktrees.
[[ "$(jq -r '.worktrees.baseline' "$PJSON")" == "${tmp}/b" ]] || { echo "FAIL: baseline path wrong"; exit 1; }
[[ "$(jq -r '.worktrees.candidate' "$PJSON")" == "${tmp}/c" ]] || { echo "FAIL: candidate path wrong"; exit 1; }

# Invariant: integrityBlock.sha256 is 64 hex.
sha="$(jq -r '.integrityBlock.sha256' "$PJSON")"
[[ "$sha" =~ ^[a-f0-9]{64}$ ]] || { echo "FAIL: sha256 shape wrong: $sha"; exit 1; }

# Invariant: cases + assertions counts propagate from inputs.
[[ "$(jq '.cases | length' "$PJSON")" == "1" ]] || { echo "FAIL: cases count"; exit 1; }
[[ "$(jq '.assertions | length' "$PJSON")" == "1" ]] || { echo "FAIL: assertions count"; exit 1; }

# Invariant: results empty, aggregate null before enrichment.
[[ "$(jq '.results | length' "$PJSON")" == "0" ]] || { echo "FAIL: results not empty"; exit 1; }
[[ "$(jq '.aggregate' "$PJSON")" == "null" ]] || { echo "FAIL: aggregate not null"; exit 1; }

echo "PASS: benchmark-plan-init"

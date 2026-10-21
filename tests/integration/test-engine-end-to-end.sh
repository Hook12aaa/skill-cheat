#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INIT="${HERE}/skills/skill-voice-review/scripts/benchmark-plan-init.sh"
RUN="${HERE}/skills/skill-voice-review/scripts/run-eval.js"
AGG="${HERE}/skills/skill-voice-review/scripts/aggregate-benchmark.js"
SCOPE="${HERE}/tests/integration/fixtures/sample-scope.json"
HIT="${HERE}/tests/integration/fixtures/mock-stream-triggered.jsonl"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Invariant: benchmark-plan-init produces a plan whose cases + assertions drive the run-eval + aggregate pipeline without any hand-editing.

cat > "${tmp}/eval.json" <<'EOF'
{"skillName":"my-skill","cases":[{"id":1,"query":"do the thing","shouldTrigger":true,"note":"n"}]}
EOF
cat > "${tmp}/assert.json" <<'EOF'
{"skillName":"my-skill","assertions":[{"id":1,"type":"gate-function-question","pattern":"BEFORE X: \"Y?\"","evidence":"e"}]}
EOF

bash "$INIT" \
  --scope "$SCOPE" \
  --eval-set "${tmp}/eval.json" \
  --assertions "${tmp}/assert.json" \
  --baseline-ref HEAD \
  --candidate-ref working-copy \
  --baseline-path "${tmp}/b" \
  --candidate-path "${tmp}/c" \
  --out-dir "${tmp}/plan"

PJSON="${tmp}/plan/benchmark-plan.json"
[[ -f "$PJSON" ]] || { echo "FAIL: no benchmark-plan.json"; exit 1; }

# Invariant: each ref gets one run-eval invocation per case; outputs are tagged with ref + caseId then fed to aggregate-benchmark.
: > "${tmp}/runs.jsonl"
for ref in baseline candidate; do
  node "$RUN" --skill-path "${tmp}/${ref:0:1}" --skill-name my-skill --query "do the thing" --mock-stream-file "$HIT" \
    | jq -c --arg ref "$ref" --argjson caseId 1 '. + {ref:$ref, caseId:$caseId}' \
    >> "${tmp}/runs.jsonl"
done

lines="$(wc -l < "${tmp}/runs.jsonl" | tr -d ' ')"
[[ "$lines" == "2" ]] || { echo "FAIL: runs.jsonl should have 2 lines, got $lines"; exit 1; }

agg="$(node "$AGG" --runs "${tmp}/runs.jsonl")"
[[ "$(printf '%s' "$agg" | jq '.baseline.passRate')" == "1" ]] || { echo "FAIL: baseline.passRate"; exit 1; }
[[ "$(printf '%s' "$agg" | jq '.candidate.passRate')" == "1" ]] || { echo "FAIL: candidate.passRate"; exit 1; }

echo "PASS: engine end-to-end"

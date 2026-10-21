#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGG="${HERE}/skills/skill-voice-review/scripts/aggregate-benchmark.js"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "${tmp}/runs.jsonl" <<'EOF'
{"ref":"baseline","caseId":1,"triggered":true,"totalTokens":100,"durationMs":1000}
{"ref":"baseline","caseId":1,"triggered":true,"totalTokens":120,"durationMs":1200}
{"ref":"baseline","caseId":1,"triggered":true,"totalTokens":140,"durationMs":1400}
{"ref":"candidate","caseId":1,"triggered":true,"totalTokens":80,"durationMs":800}
{"ref":"candidate","caseId":1,"triggered":true,"totalTokens":90,"durationMs":900}
{"ref":"candidate","caseId":1,"triggered":true,"totalTokens":100,"durationMs":1000}
EOF

out="$(node "$AGG" --runs "${tmp}/runs.jsonl")"

# Invariant: baseline mean tokens = 120 (100+120+140)/3.
[[ "$(printf '%s' "$out" | jq '.baseline.meanTokens')" == "120" ]] || { echo "FAIL: baseline.meanTokens"; exit 1; }
# Invariant: candidate mean tokens = 90.
[[ "$(printf '%s' "$out" | jq '.candidate.meanTokens')" == "90" ]] || { echo "FAIL: candidate.meanTokens"; exit 1; }
# Invariant: pass rates = 1.0.
[[ "$(printf '%s' "$out" | jq '.baseline.passRate')" == "1" ]] || { echo "FAIL: baseline.passRate"; exit 1; }
[[ "$(printf '%s' "$out" | jq '.candidate.passRate')" == "1" ]] || { echo "FAIL: candidate.passRate"; exit 1; }
# Invariant: delta.meanTokens = -30 (candidate - baseline).
[[ "$(printf '%s' "$out" | jq '.delta.meanTokens')" == "-30" ]] || { echo "FAIL: delta.meanTokens"; exit 1; }

# Invariant: unknown ref exits 65 with a diagnostic.
printf '%s\n' '{"ref":"stranger","caseId":1,"triggered":true,"totalTokens":1,"durationMs":1}' > "${tmp}/bad.jsonl"
if node "$AGG" --runs "${tmp}/bad.jsonl" >/dev/null 2>"${tmp}/err"; then
  echo "FAIL: aggregator accepted unknown ref"; exit 1
fi
grep -q "unexpected ref" "${tmp}/err" || { echo "FAIL: missing diagnostic; stderr was: $(cat "${tmp}/err")"; exit 1; }

echo "PASS: aggregate-benchmark"

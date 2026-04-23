#!/usr/bin/env bash
set -euo pipefail

# Invariant: emits benchmark-plan.json + benchmark-plan.md + benchmark-plan.md.sha256 into --out-dir.
# Invariant: baselineRef recorded before candidateRef; results=[], aggregate=null at init.
# Invariant: integrity block in benchmark-plan.md is byte-identical between runs given the same inputs.

SCOPE="" EVAL_SET="" ASSERTIONS="" BREF="" CREF="" BPATH="" CPATH="" OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)          SCOPE="$2";      shift 2 ;;
    --eval-set)       EVAL_SET="$2";   shift 2 ;;
    --assertions)     ASSERTIONS="$2"; shift 2 ;;
    --baseline-ref)   BREF="$2";       shift 2 ;;
    --candidate-ref)  CREF="$2";       shift 2 ;;
    --baseline-path)  BPATH="$2";      shift 2 ;;
    --candidate-path) CPATH="$2";      shift 2 ;;
    --out-dir)        OUT="$2";        shift 2 ;;
    *) echo "benchmark-plan-init: unknown arg $1" >&2; exit 64 ;;
  esac
done
for name in SCOPE EVAL_SET ASSERTIONS BREF CREF BPATH CPATH OUT; do
  [[ -n "${!name}" ]] || { echo "benchmark-plan-init: --${name,,} required" >&2; exit 64; }
done
for f in "$SCOPE" "$EVAL_SET" "$ASSERTIONS"; do
  [[ -f "$f" ]] || { echo "benchmark-plan-init: file not found: $f" >&2; exit 66; }
done

mkdir -p "$OUT"
PMD="${OUT}/benchmark-plan.md"
PJSON="${OUT}/benchmark-plan.json"

skill_name="$(jq -r '.name' "$SCOPE")"
run_id="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

ib_content="$(jq -cn \
  --arg name "$skill_name" \
  --arg bref "$BREF" \
  --arg cref "$CREF" \
  --slurpfile es "$EVAL_SET" \
  --slurpfile as "$ASSERTIONS" \
  '{
    skillName: $name,
    baselineRef: $bref,
    candidateRef: $cref,
    caseQueries: [$es[0].cases[].query],
    assertionPatterns: [$as[0].assertions[].pattern]
  }')"

{
  echo "<!-- integrity-block:start -->"
  printf '%s\n' "$ib_content"
  echo "<!-- integrity-block:end -->"
  echo ""
  echo "# benchmark-plan"
  echo ""
  echo "skill: ${skill_name}"
  echo "run: ${run_id}"
} > "$PMD"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${HERE}/benchmark-integrity-hash.sh" "$PMD"
sha="$(awk '{print $1}' "${PMD}.sha256")"

jq -n \
  --arg name "$skill_name" \
  --arg run "$run_id" \
  --arg sha "$sha" \
  --arg bref "$BREF" \
  --arg cref "$CREF" \
  --arg bp "$BPATH" \
  --arg cp "$CPATH" \
  --slurpfile es "$EVAL_SET" \
  --slurpfile as "$ASSERTIONS" \
  '{
    schemaVersion: "1.0",
    skillName: $name,
    runId: $run,
    integrityBlock: {sha256: $sha, path: "benchmark-plan.md"},
    baselineRef: $bref,
    candidateRef: $cref,
    worktrees: {baseline: $bp, candidate: $cp},
    cases: $es[0].cases,
    assertions: $as[0].assertions,
    results: [],
    aggregate: null
  }' > "$PJSON"

#!/usr/bin/env bash
set -euo pipefail

# Invariant: materializes baseline + candidate worktrees at <root>/<run-id>/{baseline,candidate}/; baseline first.
# Invariant: stdout is a single JSON object; exit 67 on git failure; exit 64 on bad args.

BASELINE=""
CANDIDATE=""
ROOT=""
RUN_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --baseline)  BASELINE="$2";  shift 2 ;;
    --candidate) CANDIDATE="$2"; shift 2 ;;
    --root)      ROOT="$2";      shift 2 ;;
    --run-id)    RUN_ID="$2";    shift 2 ;;
    *) echo "git-worktree-setup: unknown arg $1" >&2; exit 64 ;;
  esac
done
[[ -n "$BASELINE" && -n "$CANDIDATE" && -n "$ROOT" && -n "$RUN_ID" ]] \
  || { echo "git-worktree-setup: --baseline --candidate --root --run-id all required" >&2; exit 64; }

git rev-parse --verify "$BASELINE" >/dev/null 2>&1 \
  || { echo "git-worktree-setup: baseline ref not resolvable: $BASELINE" >&2; exit 67; }
git rev-parse --verify "$CANDIDATE" >/dev/null 2>&1 \
  || { echo "git-worktree-setup: candidate ref not resolvable: $CANDIDATE" >&2; exit 67; }

BASE_PATH="${ROOT}/${RUN_ID}/baseline"
CAND_PATH="${ROOT}/${RUN_ID}/candidate"
mkdir -p "$(dirname "$BASE_PATH")"

git worktree add --detach "$BASE_PATH" "$BASELINE" >/dev/null 2>&1 \
  || { echo "git-worktree-setup: baseline worktree add failed" >&2; exit 67; }
git worktree add --detach "$CAND_PATH" "$CANDIDATE" >/dev/null 2>&1 \
  || { echo "git-worktree-setup: candidate worktree add failed" >&2; exit 67; }

jq -n \
  --arg base "$BASE_PATH" \
  --arg cand "$CAND_PATH" \
  --arg bref "$BASELINE" \
  --arg cref "$CANDIDATE" \
  --arg run "$RUN_ID" \
  '{runId: $run, baselineRef: $bref, candidateRef: $cref, worktrees: {baseline: $base, candidate: $cand}}'

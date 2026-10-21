#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SETUP="${HERE}/skills/skill-voice-review/scripts/git-worktree-setup.sh"

tmp="$(mktemp -d)"
cleanup() { rm -rf "$tmp"; git -C "$HERE" worktree prune 2>/dev/null || true; }
trap cleanup EXIT

# Invariant: two worktrees materialized; baseline first in output; non-zero exit on unknown ref.
out="$(bash "$SETUP" --baseline HEAD --candidate HEAD --root "$tmp/worktrees" --run-id test-run)"
bpath="$(printf '%s' "$out" | jq -r '.worktrees.baseline')"
cpath="$(printf '%s' "$out" | jq -r '.worktrees.candidate')"

[[ -d "$bpath" ]] || { echo "FAIL: baseline worktree missing: $bpath"; exit 1; }
[[ -d "$cpath" ]] || { echo "FAIL: candidate worktree missing: $cpath"; exit 1; }
[[ -f "$bpath/README.md" ]] || { echo "FAIL: baseline worktree looks empty"; exit 1; }

# Invariant: bad ref exits 67.
if bash "$SETUP" --baseline no-such-ref --candidate HEAD --root "$tmp/bad" --run-id bad 2>/dev/null; then
  echo "FAIL: setup accepted bad ref"; exit 1
fi

echo "PASS: git-worktree-setup"

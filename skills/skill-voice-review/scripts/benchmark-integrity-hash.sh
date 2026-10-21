#!/usr/bin/env bash
set -euo pipefail

# Invariant: writes a 64-char sha256 sidecar at <file>.sha256 covering the byte range strictly between the integrity-block markers.
# Invariant: markers `<!-- integrity-block:start -->` / `<!-- integrity-block:end -->` themselves are NOT included in the hash.

if [[ $# -lt 1 ]]; then
  echo "usage: benchmark-integrity-hash.sh <benchmark-plan.md>" >&2
  exit 64
fi

src="$1"
[[ -f "$src" ]] || { echo "benchmark-integrity-hash: file not found: $src" >&2; exit 66; }

basename="$(basename "$src")"
digest="$(awk '
    /<!-- integrity-block:start -->/ { emit=1; next }
    /<!-- integrity-block:end -->/   { emit=0; next }
    emit { print }
  ' "$src" | openssl dgst -sha256 | awk '{print $NF}')"

[[ ${#digest} -eq 64 ]] || { echo "benchmark-integrity-hash: digest not 64 hex chars" >&2; exit 65; }

printf '%s  %s\n' "$digest" "$basename" > "${src}.sha256"

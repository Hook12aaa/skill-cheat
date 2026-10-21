#!/usr/bin/env bash
set -euo pipefail

# Invariant: compute SHA-256 of bytes strictly between integrity-block markers, write <path>.sha256 sidecar.
# Invariant: fail non-zero if either marker is missing or duplicated.

if [[ $# -ne 1 ]]; then
  echo "usage: integrity-hash.sh <path-to-design.md>" >&2
  exit 64
fi

src="$1"
[[ -f "$src" ]] || { echo "integrity-hash: file not found: $src" >&2; exit 66; }

start_count="$(grep -Fc '<!-- integrity-block:start -->' "$src" || true)"
end_count="$(grep -Fc '<!-- integrity-block:end -->' "$src" || true)"

[[ "$start_count" == "1" ]] || { echo "integrity-hash: start marker count=$start_count (want 1)" >&2; exit 65; }
[[ "$end_count"   == "1" ]] || { echo "integrity-hash: end marker count=$end_count (want 1)"   >&2; exit 65; }

digest="$(
  awk '
    /<!-- integrity-block:start -->/ { emit=1; next }
    /<!-- integrity-block:end -->/   { emit=0; next }
    emit { print }
  ' "$src" | openssl dgst -sha256 | awk '{print $NF}'
)"

[[ "$digest" =~ ^[0-9a-f]{64}$ ]] || { echo "integrity-hash: unexpected digest shape: $digest" >&2; exit 70; }

basename="$(basename "$src")"
printf '%s  %s\n' "$digest" "$basename" > "${src}.sha256"
echo "$digest  $basename"

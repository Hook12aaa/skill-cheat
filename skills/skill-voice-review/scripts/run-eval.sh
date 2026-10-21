#!/usr/bin/env bash
set -euo pipefail

# Invariant: thin wrapper around run-eval.js; passes all args through unchanged.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec node "${HERE}/run-eval.js" "$@"

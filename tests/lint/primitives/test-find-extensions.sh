#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${HERE}/skills/skill-voice-review/scripts/lint.sh" --source-only

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/plugin"
echo "ok" > "$TMP/plugin/file.md"
echo "ok" > "$TMP/plugin/file.sh"
echo "ok" > "$TMP/plugin/file.py"

findings="$(detect_find_extensions "$TMP/plugin" '[".md",".sh",".json"]')"
if ! printf '%s' "$findings" | jq -e 'length == 1' >/dev/null; then
  echo "FAIL: expected 1 finding for .py file"
  echo "$findings"; exit 1
fi

if ! printf '%s' "$findings" | jq -e '.[0].location.path | endswith("file.py")' >/dev/null; then
  echo "FAIL: finding does not reference file.py"
  echo "$findings"; exit 1
fi

rm "$TMP/plugin/file.py"
findings="$(detect_find_extensions "$TMP/plugin" '[".md",".sh",".json"]')"
if ! printf '%s' "$findings" | jq -e 'length == 0' >/dev/null; then
  echo "FAIL: expected no findings after disallowed file removed"
  echo "$findings"; exit 1
fi

echo "PASS: find-extensions"

#!/usr/bin/env bash
set -euo pipefail
script="skills/skill-stress-test/scripts/report-writer.js"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "${tmp}/manifest.json" <<'JSON'
{
  "target": {
    "path": "/some/plugin",
    "plugin_name": "demo",
    "plugin_version": "1.2.3",
    "git_sha": "deadbeef",
    "skills": ["alpha", "beta"]
  },
  "harness_version": "0.1.0",
  "run_id": "2026-05-11T00-00-00Z-abc",
  "started_at": "2026-05-11T00:00:00Z"
}
JSON

cat > "${tmp}/static.json" <<'JSON'
{
  "verdict": "ACCEPT_WITH_MINOR",
  "per_skill": [
    {"skill": "alpha", "verdict": "ACCEPT", "findings": []},
    {"skill": "beta",  "verdict": "ACCEPT_WITH_MINOR", "findings": [{"rule": "LINT-008", "severity": "MINOR"}]}
  ]
}
JSON

node "$script" --manifest "${tmp}/manifest.json" --static "${tmp}/static.json" --output "${tmp}/report.json"

[[ -f "${tmp}/report.json" ]] || { echo "FAIL: report.json was not written" >&2; exit 1; }

jq -e '.manifest.target.plugin_name == "demo"' "${tmp}/report.json" > /dev/null \
  || { echo "FAIL: manifest.target.plugin_name not preserved" >&2; exit 1; }

jq -e '.layers.static.verdict == "ACCEPT_WITH_MINOR"' "${tmp}/report.json" > /dev/null \
  || { echo "FAIL: layers.static.verdict not preserved" >&2; exit 1; }

jq -e '.layers.static.per_skill | length == 2' "${tmp}/report.json" > /dev/null \
  || { echo "FAIL: per_skill count off" >&2; exit 1; }

jq -e '.verdict == "PENDING"' "${tmp}/report.json" > /dev/null \
  || { echo "FAIL: verdict should be PENDING until verdict-resolver runs" >&2; exit 1; }

echo "PASS: report-writer"

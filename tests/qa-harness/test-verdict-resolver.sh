#!/usr/bin/env bash
set -euo pipefail
script="skills/skill-stress-test/scripts/verdict-resolver.js"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

run_case() {
  local label="$1" static_verdict="$2" expected="$3"
  cat > "${tmp}/r.json" <<JSON
{
  "verdict": "PENDING",
  "manifest": {"target": {"plugin_name": "x", "skills": ["a"]}, "harness_version": "0.1.0", "run_id": "r", "started_at": "2026-05-11T00:00:00Z"},
  "layers": {"static": {"verdict": "${static_verdict}", "per_skill": []}, "behavioral": null, "e2e": null, "evolutionary": null}
}
JSON
  local actual
  actual="$(node "$script" --report "${tmp}/r.json")"
  if [[ "$actual" != "$expected" ]]; then
    echo "FAIL: $label  static=$static_verdict  expected=$expected  actual=$actual" >&2
    exit 1
  fi
}

run_case "static ACCEPT -> clean"            "ACCEPT"            "VALIDATION_CLEAN"
run_case "static ACCEPT_WITH_MINOR -> drift" "ACCEPT_WITH_MINOR" "PLUGIN_DRIFT"
run_case "static REJECT_IMPORTANT -> drift"  "REJECT_IMPORTANT"  "PLUGIN_DRIFT"
run_case "static REJECT_CRITICAL -> drift"   "REJECT_CRITICAL"   "PLUGIN_DRIFT"
run_case "static INCONCLUSIVE -> inconclusive" "INCONCLUSIVE"    "VALIDATION_INCONCLUSIVE"

cat > "${tmp}/missing.json" <<'JSON'
{
  "verdict": "PENDING",
  "manifest": {"target": {"plugin_name": "x", "skills": []}, "harness_version": "0.1.0", "run_id": "r", "started_at": "2026-05-11T00:00:00Z"},
  "layers": {"static": null, "behavioral": null, "e2e": null, "evolutionary": null}
}
JSON
actual="$(node "$script" --report "${tmp}/missing.json")"
if [[ "$actual" != "VALIDATION_INCONCLUSIVE" ]]; then
  echo "FAIL: missing static -> VALIDATION_INCONCLUSIVE  actual=$actual" >&2
  exit 1
fi

echo "PASS: verdict-resolver"

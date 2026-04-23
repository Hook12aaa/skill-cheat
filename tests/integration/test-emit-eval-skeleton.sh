#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EMIT="${HERE}/skills/skill-scope/scripts/emit-eval-skeleton.sh"
FIXTURE="${HERE}/tests/integration/fixtures/sample-scope.json"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

bash "$EMIT" "$FIXTURE" > "${tmp}/out.json"

got="$(jq -r '.skillName' "${tmp}/out.json")"
[[ "$got" == "my-skill" ]] || { echo "FAIL: skillName=$got (want my-skill)"; exit 1; }

positives="$(jq '[.cases[] | select(.shouldTrigger == true)] | length' "${tmp}/out.json")"
[[ "$positives" == "2" ]] || { echo "FAIL: positive cases=$positives (want 2)"; exit 1; }

negatives="$(jq '[.cases[] | select(.shouldTrigger == false)] | length' "${tmp}/out.json")"
[[ "$negatives" == "5" ]] || { echo "FAIL: negative cases=$negatives (want 5)"; exit 1; }

total="$(jq '.cases | length' "${tmp}/out.json")"
[[ "$total" == "7" ]] || { echo "FAIL: total cases=$total (want 7)"; exit 1; }
unique_ids="$(jq '[.cases[].id] | unique | length' "${tmp}/out.json")"
[[ "$unique_ids" == "7" ]] || { echo "FAIL: duplicate ids in cases"; exit 1; }

jq . "${tmp}/out.json" >/dev/null || { echo "FAIL: emitted JSON invalid"; exit 1; }

echo "PASS: emit-eval-skeleton"

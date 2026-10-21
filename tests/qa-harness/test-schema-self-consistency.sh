#!/usr/bin/env bash
set -euo pipefail
fixture="tests/qa-harness/fixtures/clean-plugin"
schema="skills/skill-stress-test/references/report-schema.json"
orchestrator="skills/skill-stress-test/scripts/qa-orchestrator.js"

cleanup() { rm -rf "${fixture}/.skill-cheat-qa"; }
trap cleanup EXIT
cleanup

for layer in behavioral e2e evolutionary; do
  declared="$(jq -c ".properties.layers.properties.${layer}.type" "$schema")"
  if [[ "$declared" != '["object","null"]' ]]; then
    echo "FAIL: schema.layers.${layer}.type must be [\"object\",\"null\"], got: $declared" >&2
    exit 1
  fi
done

node "$orchestrator" --plugin "$fixture" > /dev/null
report="$(find "${fixture}/.skill-cheat-qa/runs" -name report.json | head -1)"
[[ -f "$report" ]] || { echo "FAIL: report.json missing after orchestrator run" >&2; exit 1; }

for layer in behavioral e2e evolutionary; do
  emitted="$(jq -r ".layers.${layer} | if . == null then \"null\" else type end" "$report")"
  if [[ "$emitted" != "null" && "$emitted" != "object" ]]; then
    echo "FAIL: report.layers.${layer} must be null or object, got: $emitted" >&2
    exit 1
  fi
done

required_keys="$(jq -r '.required[]' "$schema" | sort)"
expected="layers
manifest
verdict"
if [[ "$required_keys" != "$expected" ]]; then
  echo "FAIL: schema.required must be exactly {verdict, manifest, layers}, got:" >&2
  echo "$required_keys" >&2
  exit 1
fi

verdict_enum="$(jq -c '.properties.verdict.enum | sort' "$schema")"
expected_enum='["BLOCKED_NO_TARGET","HARNESS_GAP","PLUGIN_DRIFT","VALIDATION_CLEAN","VALIDATION_INCONCLUSIVE"]'
if [[ "$verdict_enum" != "$expected_enum" ]]; then
  echo "FAIL: schema verdict enum drift" >&2
  echo "  expected: $expected_enum" >&2
  echo "  actual:   $verdict_enum" >&2
  exit 1
fi

emitted_verdict="$(jq -r '.verdict' "$report")"
if ! jq -e --arg v "$emitted_verdict" '.properties.verdict.enum | index($v) != null' "$schema" > /dev/null; then
  echo "FAIL: emitted verdict '$emitted_verdict' not in schema enum" >&2
  exit 1
fi

declared_pf="$(jq -c '.properties.layers.properties.static.properties.plugin_findings.type' "$schema")"
if [[ "$declared_pf" != '"array"' ]]; then
  echo "FAIL: schema.layers.static.plugin_findings.type must be \"array\", got: $declared_pf" >&2
  exit 1
fi

emitted_pf_type="$(jq -r '.layers.static.plugin_findings | type' "$report")"
if [[ "$emitted_pf_type" != "array" ]]; then
  echo "FAIL: report.layers.static.plugin_findings must be array, got: $emitted_pf_type" >&2
  exit 1
fi

echo "PASS: schema self-consistency"

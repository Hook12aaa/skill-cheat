#!/usr/bin/env bash
set -euo pipefail
script="skills/skill-stress-test/scripts/layer-static.sh"
fix_empty="tests/qa-harness/fixtures/empty-skills-plugin"
fix_nodir="tests/qa-harness/fixtures/no-skills-dir-plugin"
fix_nested="tests/qa-harness/fixtures/nested-skill-plugin"
fix_symlink="tests/qa-harness/fixtures/symlink-plugin"
fix_clean="tests/qa-harness/fixtures/clean-plugin"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" != "$actual" ]]; then
    echo "FAIL: $label" >&2
    echo "  expected: $expected" >&2
    echo "  actual:   $actual" >&2
    exit 1
  fi
}

# F-08: empty skills/ enumeration -> INCONCLUSIVE
result="$(bash "$script" --target "$fix_empty")"
assert_eq "empty-skills: verdict" "INCONCLUSIVE" "$(printf '%s' "$result" | jq -r '.verdict')"
assert_eq "empty-skills: per_skill count" "0" "$(printf '%s' "$result" | jq -r '.per_skill | length')"
[[ "$(printf '%s' "$result" | jq -r '.reason')" == *"no SKILL.md"* ]] \
  || { echo "FAIL: empty-skills reason missing" >&2; exit 1; }

# F-24: no skills/ dir at all -> INCONCLUSIVE
result="$(bash "$script" --target "$fix_nodir")"
assert_eq "no-skills-dir: verdict" "INCONCLUSIVE" "$(printf '%s' "$result" | jq -r '.verdict')"
assert_eq "no-skills-dir: per_skill count" "0" "$(printf '%s' "$result" | jq -r '.per_skill | length')"
[[ "$(printf '%s' "$result" | jq -r '.reason')" == *"no skills/"* ]] \
  || { echo "FAIL: no-skills-dir reason missing" >&2; exit 1; }

# F-19: SKILL.md at unsupported depth -> INCONCLUSIVE
result="$(bash "$script" --target "$fix_nested" 2>/dev/null)"
assert_eq "nested-skill: verdict" "INCONCLUSIVE" "$(printf '%s' "$result" | jq -r '.verdict')"
assert_eq "nested-skill: per_skill count" "0" "$(printf '%s' "$result" | jq -r '.per_skill | length')"
[[ "$(printf '%s' "$result" | jq -r '.reason')" == *"unsupported depth"* ]] \
  || { echo "FAIL: nested-skill reason missing 'unsupported depth'" >&2; exit 1; }
[[ "$(printf '%s' "$result" | jq -r '.offending_paths | length')" -ge "1" ]] \
  || { echo "FAIL: nested-skill should list offending paths" >&2; exit 1; }

# F-18: symlinked SKILL.md -> INCONCLUSIVE, never followed
result="$(bash "$script" --target "$fix_symlink" 2>/dev/null)"
assert_eq "symlink-plugin: verdict" "INCONCLUSIVE" "$(printf '%s' "$result" | jq -r '.verdict')"
assert_eq "symlink-plugin: per_skill count" "0" "$(printf '%s' "$result" | jq -r '.per_skill | length')"
[[ "$(printf '%s' "$result" | jq -r '.reason')" == *"symlinked SKILL.md"* ]] \
  || { echo "FAIL: symlink reason missing 'symlinked SKILL.md'" >&2; exit 1; }

# F-01: lint.sh that crashes -> per-skill INCONCLUSIVE, not VALIDATION_CLEAN
crash_lint="${tmp}/crash-lint.sh"
cat > "$crash_lint" <<'EOF'
#!/usr/bin/env bash
echo "synthetic lint crash" >&2
exit 7
EOF
chmod +x "$crash_lint"

result="$(SKILL_CHEAT_LINT_OVERRIDE="$crash_lint" bash "$script" --target "$fix_clean")"
assert_eq "crash-lint: layer verdict" "INCONCLUSIVE" "$(printf '%s' "$result" | jq -r '.verdict')"
assert_eq "crash-lint: per_skill count" "1" "$(printf '%s' "$result" | jq -r '.per_skill | length')"
assert_eq "crash-lint: per_skill verdict" "INCONCLUSIVE" "$(printf '%s' "$result" | jq -r '.per_skill[0].verdict')"
assert_eq "crash-lint: rule_id" "LINT-CRASH" "$(printf '%s' "$result" | jq -r '.per_skill[0].findings[0].rule_id')"
assert_eq "crash-lint: exit_code captured" "7" "$(printf '%s' "$result" | jq -r '.per_skill[0].findings[0].exit_code')"

# F-01 garbage path: lint emits non-JSON -> per-skill INCONCLUSIVE
garbage_lint="${tmp}/garbage-lint.sh"
cat > "$garbage_lint" <<'EOF'
#!/usr/bin/env bash
echo "this is not json"
exit 0
EOF
chmod +x "$garbage_lint"

result="$(SKILL_CHEAT_LINT_OVERRIDE="$garbage_lint" bash "$script" --target "$fix_clean")"
assert_eq "garbage-lint: layer verdict" "INCONCLUSIVE" "$(printf '%s' "$result" | jq -r '.verdict')"
assert_eq "garbage-lint: per_skill verdict" "INCONCLUSIVE" "$(printf '%s' "$result" | jq -r '.per_skill[0].verdict')"
assert_eq "garbage-lint: rule_id" "LINT-NONJSON" "$(printf '%s' "$result" | jq -r '.per_skill[0].findings[0].rule_id')"

# F-02: lint emits an unknown verdict token -> exit non-zero
weird_lint="${tmp}/weird-lint.sh"
cat > "$weird_lint" <<'EOF'
#!/usr/bin/env bash
echo '{"verdict": "WHATEVER", "findings": []}'
EOF
chmod +x "$weird_lint"

set +e
SKILL_CHEAT_LINT_OVERRIDE="$weird_lint" bash "$script" --target "$fix_clean" >/dev/null 2>"${tmp}/weird-stderr"
ec=$?
set -e
[[ "$ec" != "0" ]] \
  || { echo "FAIL: unknown verdict from lint should exit non-zero (got $ec)" >&2; exit 1; }
grep -q "unknown verdict from lint.sh: WHATEVER" "${tmp}/weird-stderr" \
  || { echo "FAIL: unknown verdict stderr missing label" >&2; cat "${tmp}/weird-stderr" >&2; exit 1; }

echo "PASS: layer-static edge cases"

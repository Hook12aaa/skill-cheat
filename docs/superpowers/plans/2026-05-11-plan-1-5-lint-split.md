# Plan 1.5 — Lint Engine SKILL-shape / PLUGIN-policy Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split lint rules into universal "SKILL-shape" rules and skill-cheat-internal "PLUGIN-policy" rules; add `--mode self|cross-plugin` and `--plugin-root-only` flags to `lint.sh`; rework `layer-static.sh` to run plugin-root–scoped rules once as a pre-pass instead of N times across N skills. Fixes F-22 + F-23.

**Architecture:** Each rule in `lint-rules.json` gets a top-level `kind` field. `lint.sh` filters rules by `kind` in cross-plugin mode and by `detector.scope` in plugin-root-only mode. `layer-static.sh` does a single plugin-root pre-pass before the per-skill loop and emits a new `static.plugin_findings` array alongside `static.per_skill`.

**Tech Stack:** Same as Plan 1 — `bash` (≥4), `node` (≥18, ESM), `jq`. No new dependencies.

**Comment discipline (applies to every `.sh` and `.js` code block in this plan):** comments are LLM-instructions only — directives and invariants. No change-history, no rationale, no maintainer notes.

---

## File Structure

Files modified (6) and added (5):

```
skills/skill-voice-review/
├── references/
│   └── lint-rules.json                              ← Task 1 (modify)
└── scripts/
    └── lint.sh                                      ← Task 2, 3 (modify)

skills/skill-stress-test/
├── references/
│   └── report-schema.json                           ← Task 5 (modify)
└── scripts/
    ├── layer-static.sh                              ← Task 4 (modify)
    └── verdict-resolver.js                          ← Task 6 (modify)

tests/qa-harness/
├── fixtures/
│   ├── cross-plugin-clean-plugin/                   ← Task 8 (new fixture)
│   │   ├── .claude-plugin/plugin.json
│   │   ├── unrelated-asset.yaml
│   │   ├── another-asset.png
│   │   └── skills/sample/SKILL.md
│   └── multi-skill-noise-plugin/                    ← Task 7 (new fixture)
│       ├── .claude-plugin/plugin.json
│       ├── rogue-asset.yaml
│       └── skills/
│           ├── alpha/SKILL.md
│           ├── beta/SKILL.md
│           └── gamma/SKILL.md
├── test-rule-classification.sh                      ← Task 1 (new)
├── test-lint-mode-self.sh                           ← Task 2 (new)
├── test-lint-mode-cross-plugin.sh                   ← Task 2 (new)
├── test-lint-plugin-root-only.sh                    ← Task 3 (new)
├── test-layer-static-plugin-findings.sh             ← Task 7 (new)
└── test-layer-static-cross-plugin-clean.sh          ← Task 8 (new)
```

**Responsibilities:**
- `lint-rules.json` — every rule entry gains a top-level `kind` field (`skill-shape` or `plugin-policy`).
- `lint.sh` — accepts `--mode self|cross-plugin` (default `self`) and `--plugin-root-only`; filters rules accordingly before detector dispatch.
- `layer-static.sh` — invokes `lint.sh --mode cross-plugin --plugin-root-only` once for the target, then iterates SKILL.md files with `lint.sh --mode cross-plugin`. Emits `{verdict, plugin_findings, per_skill}`.
- `report-schema.json` — declares `layers.static.plugin_findings` as an optional array.
- `verdict-resolver.js` — when computing the static sub-verdict, takes the worst across plugin_findings severity and per_skill verdicts.
- Test files exercise mode flag, plugin-root pre-pass, classification coverage, and the two real-world signal cases (multi-skill dedup, plugin-asset cross-plugin clean).

---

## Task 1: Classify every rule in lint-rules.json + add coverage test

**Files:**
- Modify: `skills/skill-voice-review/references/lint-rules.json`
- Test: `tests/qa-harness/test-rule-classification.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/qa-harness/test-rule-classification.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
rules="skills/skill-voice-review/references/lint-rules.json"

missing="$(jq -r '.rules[] | select(.kind == null) | .id' "$rules")"
if [[ -n "$missing" ]]; then
  echo "FAIL: rules without a kind field:" >&2
  echo "$missing" >&2
  exit 1
fi

invalid="$(jq -r '.rules[] | select(.kind != "skill-shape" and .kind != "plugin-policy") | .id + " kind=" + .kind' "$rules")"
if [[ -n "$invalid" ]]; then
  echo "FAIL: rules with invalid kind (must be skill-shape or plugin-policy):" >&2
  echo "$invalid" >&2
  exit 1
fi

skill_shape_count="$(jq '[.rules[] | select(.kind == "skill-shape")] | length' "$rules")"
plugin_policy_count="$(jq '[.rules[] | select(.kind == "plugin-policy")] | length' "$rules")"
total="$(jq '.rules | length' "$rules")"
[[ "$((skill_shape_count + plugin_policy_count))" == "$total" ]] \
  || { echo "FAIL: classification count mismatch" >&2; exit 1; }

echo "PASS: rule classification ($skill_shape_count skill-shape, $plugin_policy_count plugin-policy)"
```

```bash
chmod +x tests/qa-harness/test-rule-classification.sh
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/qa-harness/test-rule-classification.sh`
Expected: FAIL listing every LINT-001 through LINT-021 (21 rules) as missing a `kind` field.

- [ ] **Step 3: Add `kind` to every rule**

Edit `skills/skill-voice-review/references/lint-rules.json`. For each rule object inside the `rules` array, insert a top-level `kind` field after the `id` field:

```json
{ "id": "LINT-001", "kind": "plugin-policy", "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-002", "kind": "skill-shape",  "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-003", "kind": "skill-shape",  "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-004", "kind": "skill-shape",  "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-005", "kind": "skill-shape",  "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-006", "kind": "skill-shape",  "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-007", "kind": "skill-shape",  "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-008", "kind": "skill-shape",  "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-009", "kind": "skill-shape",  "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-010", "kind": "skill-shape",  "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-011", "kind": "skill-shape",  "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-012", "kind": "skill-shape",  "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-013", "kind": "skill-shape",  "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-014", "kind": "skill-shape",  "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-015", "kind": "skill-shape",  "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-016", "kind": "plugin-policy", "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-017", "kind": "skill-shape",  "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-018", "kind": "skill-shape",  "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-019", "kind": "skill-shape",  "severity": "CRITICAL", "detector": {...} }
{ "id": "LINT-020", "kind": "skill-shape",  "severity": "IMPORTANT", "detector": {...} }
{ "id": "LINT-021", "kind": "skill-shape",  "severity": "IMPORTANT", "detector": {...} }
```

Use `jq` to do this surgically without rewriting the whole file:

```bash
jq '.rules |= map(.kind = (
  if .id == "LINT-001" then "plugin-policy"
  elif .id == "LINT-016" then "plugin-policy"
  else "skill-shape"
  end
))' skills/skill-voice-review/references/lint-rules.json > /tmp/lint-rules.new && \
  mv /tmp/lint-rules.new skills/skill-voice-review/references/lint-rules.json
```

Verify the file still parses:
```bash
jq -e . skills/skill-voice-review/references/lint-rules.json > /dev/null && echo OK
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/qa-harness/test-rule-classification.sh`
Expected: `PASS: rule classification (19 skill-shape, 2 plugin-policy)`.

- [ ] **Step 5: Confirm full suite still passes**

Run: `bash tests/run-tests.sh`
Expected: 39 passing (38 prior + 1 new).

- [ ] **Step 6: Commit**

```bash
git add skills/skill-voice-review/references/lint-rules.json tests/qa-harness/test-rule-classification.sh
git commit -m "feat(lint): classify every rule as skill-shape or plugin-policy

LINT-001 (file-extension allowlist) and LINT-016 (Integrity Block
region marker) are skill-cheat house rules. The other 19 are universal
SKILL-shape rules. Foundation for Plan 1.5 --mode flag.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Add `--mode self|cross-plugin` flag to lint.sh

**Files:**
- Modify: `skills/skill-voice-review/scripts/lint.sh`
- Test: `tests/qa-harness/test-lint-mode-self.sh`
- Test: `tests/qa-harness/test-lint-mode-cross-plugin.sh`

- [ ] **Step 1: Write the failing tests**

Create `tests/qa-harness/test-lint-mode-self.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
lint="skills/skill-voice-review/scripts/lint.sh"
fixture="tests/qa-harness/fixtures/clean-plugin/skills/sample-clean/SKILL.md"

result="$(bash "$lint" --mode self "$fixture")"
verdict="$(printf '%s' "$result" | jq -r '.verdict')"
[[ "$verdict" == "ACCEPT" ]] \
  || { echo "FAIL: self mode on clean fixture should ACCEPT, got $verdict" >&2; exit 1; }

passed="$(printf '%s' "$result" | jq -r '.summary.passed')"
[[ "$passed" -ge 19 ]] \
  || { echo "FAIL: self mode should run at least 19 rules, got passed=$passed" >&2; exit 1; }

result_default="$(bash "$lint" "$fixture")"
verdict_default="$(printf '%s' "$result_default" | jq -r '.verdict')"
[[ "$verdict_default" == "$verdict" ]] \
  || { echo "FAIL: default mode should equal --mode self, got default=$verdict_default vs self=$verdict" >&2; exit 1; }

echo "PASS: lint --mode self"
```

Create `tests/qa-harness/test-lint-mode-cross-plugin.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
lint="skills/skill-voice-review/scripts/lint.sh"
fixture="tests/qa-harness/fixtures/clean-plugin/skills/sample-clean/SKILL.md"

result_self="$(bash "$lint" --mode self "$fixture")"
result_cross="$(bash "$lint" --mode cross-plugin "$fixture")"

ran_self="$(printf '%s' "$result_self" | jq -r '.summary.passed + .summary.critical + .summary.important + .summary.minor')"
ran_cross="$(printf '%s' "$result_cross" | jq -r '.summary.passed + .summary.critical + .summary.important + .summary.minor')"

[[ "$ran_self" -gt "$ran_cross" ]] \
  || { echo "FAIL: cross-plugin should run fewer rules than self (self=$ran_self cross=$ran_cross)" >&2; exit 1; }

diff="$((ran_self - ran_cross))"
[[ "$diff" == "2" ]] \
  || { echo "FAIL: cross-plugin should filter exactly 2 plugin-policy rules (got diff=$diff)" >&2; exit 1; }

has_lint001="$(printf '%s' "$result_cross" | jq -r '[.findings[]?.rule // empty] | map(select(. == "LINT-001")) | length')"
[[ "$has_lint001" == "0" ]] \
  || { echo "FAIL: cross-plugin emitted LINT-001 findings (count=$has_lint001)" >&2; exit 1; }

echo "PASS: lint --mode cross-plugin"
```

```bash
chmod +x tests/qa-harness/test-lint-mode-self.sh tests/qa-harness/test-lint-mode-cross-plugin.sh
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash tests/qa-harness/test-lint-mode-self.sh`
Expected: depending on how lint.sh handles unknown flags, may FAIL with "unknown arg --mode" or treat `--mode self` as a path and fail to read.

Run: `bash tests/qa-harness/test-lint-mode-cross-plugin.sh`
Expected: FAIL similarly.

- [ ] **Step 3: Modify lint.sh to accept --mode and filter rules**

Edit `skills/skill-voice-review/scripts/lint.sh`. Add `--mode` parsing near the top, alongside the existing `--source-only` check.

After the `set -euo pipefail` and existing `--source-only` handling, add:

```bash
LINT_MODE="self"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)
      LINT_MODE="$2"
      shift 2
      ;;
    *)
      break
      ;;
  esac
done

case "$LINT_MODE" in
  self|cross-plugin) ;;
  *) echo "lint.sh: --mode must be 'self' or 'cross-plugin', got '$LINT_MODE'" >&2; exit 64 ;;
esac
```

Then, in the rule iteration loop, before dispatching each rule's detector, add a filter:

```bash
rule_kind="$(printf '%s' "$rule" | jq -r '.kind // "plugin-policy"')"
if [[ "$LINT_MODE" == "cross-plugin" && "$rule_kind" == "plugin-policy" ]]; then
  continue
fi
```

The exact location depends on the existing structure of lint.sh's main loop. Read the file first to locate the iteration over `.rules[]`.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/qa-harness/test-lint-mode-self.sh`
Expected: `PASS: lint --mode self`.

Run: `bash tests/qa-harness/test-lint-mode-cross-plugin.sh`
Expected: `PASS: lint --mode cross-plugin`.

- [ ] **Step 5: Confirm full suite still passes**

Run: `bash tests/run-tests.sh`
Expected: 41 passing (39 prior + 2 new). Importantly, every existing test still passes — `--mode self` is the default, so legacy callers see no behavior change.

- [ ] **Step 6: Commit**

```bash
git add skills/skill-voice-review/scripts/lint.sh tests/qa-harness/test-lint-mode-self.sh tests/qa-harness/test-lint-mode-cross-plugin.sh
git commit -m "feat(lint): --mode self|cross-plugin filters plugin-policy rules

Default --mode self preserves existing behavior. --mode cross-plugin
filters out kind: plugin-policy rules before detector dispatch.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Add `--plugin-root-only` flag to lint.sh

**Files:**
- Modify: `skills/skill-voice-review/scripts/lint.sh`
- Test: `tests/qa-harness/test-lint-plugin-root-only.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/qa-harness/test-lint-plugin-root-only.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
lint="skills/skill-voice-review/scripts/lint.sh"
fixture="tests/qa-harness/fixtures/clean-plugin"

result="$(bash "$lint" --plugin-root-only --mode self --target "$fixture")"

verdict="$(printf '%s' "$result" | jq -r '.verdict')"
[[ "$verdict" == "ACCEPT" || "$verdict" == "ACCEPT_WITH_MINOR" || "$verdict" == "REJECT_IMPORTANT" || "$verdict" == "REJECT_CRITICAL" ]] \
  || { echo "FAIL: --plugin-root-only verdict invalid: $verdict" >&2; exit 1; }

skill_body_findings="$(printf '%s' "$result" | jq -r '[.findings[]?.rule] | map(select(. != "LINT-001" and . != "LINT-016")) | length')"
[[ "$skill_body_findings" == "0" ]] \
  || { echo "FAIL: --plugin-root-only emitted skill-body findings ($skill_body_findings)" >&2; exit 1; }

result_cross="$(bash "$lint" --plugin-root-only --mode cross-plugin --target "$fixture")"
has_lint001_cross="$(printf '%s' "$result_cross" | jq -r '[.findings[]?.rule] | map(select(. == "LINT-001")) | length')"
[[ "$has_lint001_cross" == "0" ]] \
  || { echo "FAIL: --plugin-root-only + cross-plugin should filter LINT-001 (got $has_lint001_cross findings)" >&2; exit 1; }

echo "PASS: lint --plugin-root-only"
```

```bash
chmod +x tests/qa-harness/test-lint-plugin-root-only.sh
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/qa-harness/test-lint-plugin-root-only.sh`
Expected: FAIL with "unknown arg --plugin-root-only" or invalid usage.

- [ ] **Step 3: Modify lint.sh to accept --plugin-root-only and --target**

Edit `skills/skill-voice-review/scripts/lint.sh`. Extend the argument parsing block from Task 2:

```bash
PLUGIN_ROOT_ONLY=0
TARGET_PATH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) LINT_MODE="$2"; shift 2 ;;
    --plugin-root-only) PLUGIN_ROOT_ONLY=1; shift ;;
    --target) TARGET_PATH="$2"; shift 2 ;;
    *) break ;;
  esac
done

if [[ "$PLUGIN_ROOT_ONLY" == "1" && -z "$TARGET_PATH" ]]; then
  echo "lint.sh: --plugin-root-only requires --target <plugin-root>" >&2
  exit 64
fi
```

Then, in the rule iteration loop, add a scope filter that uses the rule's `detector.scope` field:

```bash
rule_scope="$(printf '%s' "$rule" | jq -r '.detector.scope // empty')"

if [[ "$PLUGIN_ROOT_ONLY" == "1" ]]; then
  [[ "$rule_scope" == "plugin-root" ]] || continue
else
  [[ "$rule_scope" != "plugin-root" ]] || continue
fi
```

The first branch (when `--plugin-root-only` is set) only runs rules with `detector.scope == "plugin-root"`. The second branch (normal per-skill mode) skips plugin-root rules — these are owned by the pre-pass now.

In plugin-root-only mode, the detector should be invoked against `$TARGET_PATH`, not the SKILL.md positional argument. Find the detector dispatch logic and add a branch:

```bash
if [[ "$PLUGIN_ROOT_ONLY" == "1" ]]; then
  detector_target="$TARGET_PATH"
else
  detector_target="$skill_md_path"
fi
```

Then pass `detector_target` to the detector function instead of the original path variable.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/qa-harness/test-lint-plugin-root-only.sh`
Expected: `PASS: lint --plugin-root-only`.

- [ ] **Step 5: Confirm full suite still passes**

Run: `bash tests/run-tests.sh`
Expected: 42 passing. Every existing test still passes — the new skip in the normal path means plugin-root rules (just LINT-001) no longer fire when lint.sh is called per-SKILL.md, but existing per-SKILL.md tests don't assert on LINT-001 specifically.

**Important:** if a previously-passing test now fails because it expected LINT-001 to fire on a SKILL.md call, that test was relying on the buggy behavior we're fixing. Update the test to either invoke lint.sh with `--plugin-root-only --target <plugin>` separately OR remove the expectation.

- [ ] **Step 6: Commit**

```bash
git add skills/skill-voice-review/scripts/lint.sh tests/qa-harness/test-lint-plugin-root-only.sh
git commit -m "feat(lint): --plugin-root-only runs plugin-scope rules once

When --plugin-root-only is set, only rules with detector.scope ==
'plugin-root' run, and they scan --target <plugin-root> instead of
the SKILL.md positional arg. In normal mode, plugin-root rules skip
entirely (the harness pre-pass owns them).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Rework layer-static.sh to use the plugin-root pre-pass

**Files:**
- Modify: `skills/skill-stress-test/scripts/layer-static.sh`
- Test: existing `tests/qa-harness/test-layer-static.sh` (verify still passes)
- Test: existing `tests/qa-harness/test-layer-static-edge-cases.sh` (verify still passes)

- [ ] **Step 1: Read the existing layer-static.sh**

Run: `cat skills/skill-stress-test/scripts/layer-static.sh`

Locate three things:
- The argument parsing block (currently handles `--target`).
- The find-and-enumerate block that builds `skill_md_files`.
- The per-skill loop that invokes `lint.sh` and accumulates `per_skill` JSON.

- [ ] **Step 2: Modify layer-static.sh to invoke pre-pass first, then per-skill loop**

Edit `skills/skill-stress-test/scripts/layer-static.sh`. After the argument parsing and before the per-skill loop:

```bash
plugin_findings='[]'
set +e
pre_pass_out="$(bash "$lint_script" --plugin-root-only --mode cross-plugin --target "$TARGET" 2>/dev/null)"
pre_pass_status=$?
set -e
if [[ $pre_pass_status -eq 0 ]]; then
  pre_pass_verdict="$(printf '%s' "$pre_pass_out" | jq -r '.verdict // "INCONCLUSIVE"')"
  case "$pre_pass_verdict" in
    ACCEPT|ACCEPT_WITH_MINOR|REJECT_IMPORTANT|REJECT_CRITICAL)
      plugin_findings="$(printf '%s' "$pre_pass_out" | jq -c '.findings // []')"
      ;;
    *)
      plugin_findings='[]'
      ;;
  esac
fi
```

Then, modify the per-skill `bash "$lint_script" "$f"` invocation to add `--mode cross-plugin`:

```bash
lint_out="$(bash "$lint_script" --mode cross-plugin "$f")"
```

Finally, modify the worst-verdict computation. The layer verdict is now the worst across plugin_findings severity and per_skill verdicts. Add a helper:

```bash
plugin_findings_worst="ACCEPT"
n_critical="$(printf '%s' "$plugin_findings" | jq '[.[] | select(.severity == "CRITICAL")] | length')"
n_important="$(printf '%s' "$plugin_findings" | jq '[.[] | select(.severity == "IMPORTANT")] | length')"
n_minor="$(printf '%s' "$plugin_findings" | jq '[.[] | select(.severity == "MINOR")] | length')"
if (( n_critical > 0 )); then plugin_findings_worst="REJECT_CRITICAL"
elif (( n_important > 0 )); then plugin_findings_worst="REJECT_IMPORTANT"
elif (( n_minor > 0 )); then plugin_findings_worst="ACCEPT_WITH_MINOR"
fi

if (( $(rank "$plugin_findings_worst") > $(rank "$worst") )); then
  worst="$plugin_findings_worst"
fi
```

Update the final emit:

```bash
jq -n --arg v "$worst" --argjson p "$per_skill" --argjson pf "$plugin_findings" \
  '{verdict: $v, plugin_findings: $pf, per_skill: $p}'
```

For the empty-enumeration short-circuit (existing Plan 1 fix F-08), include `plugin_findings` too:

```bash
if (( ${#skill_md_files[@]} == 0 )); then
  jq -n --argjson pf "$plugin_findings" \
    '{verdict: "INCONCLUSIVE", plugin_findings: $pf, per_skill: [], reason: "no SKILL.md files found under skills/"}'
  exit 0
fi
```

(Same for the other INCONCLUSIVE early-return paths — `plugin_findings` is always emitted.)

- [ ] **Step 3: Run existing layer-static tests**

Run: `bash tests/qa-harness/test-layer-static.sh`
Expected: PASS. The existing tests assert on `verdict` and `per_skill`, which are unchanged in shape.

Run: `bash tests/qa-harness/test-layer-static-edge-cases.sh`
Expected: PASS. The edge cases (empty, no-skills-dir, symlink, nested) still emit INCONCLUSIVE with their reason; the new `plugin_findings` is just an extra key.

- [ ] **Step 4: Confirm full suite still passes**

Run: `bash tests/run-tests.sh`
Expected: 42 passing (same count — Task 4 doesn't add tests, it just modifies the script).

If a Plan 1 test fails because it does a strict equality check on the JSON shape, update the assertion to ignore the new `plugin_findings` key. Most assertions use `jq` to extract specific fields, which is robust.

- [ ] **Step 5: Commit**

```bash
git add skills/skill-stress-test/scripts/layer-static.sh
git commit -m "feat(layer-static): plugin-root pre-pass + per-skill cross-plugin mode

Invokes lint.sh --plugin-root-only --mode cross-plugin once before
the per-skill loop. Collects plugin-scope findings into a new
plugin_findings array. Per-skill loop now runs --mode cross-plugin,
filtering plugin-policy rules. Verdict is the worst across plugin
findings severity and per-skill verdicts.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Update report-schema.json to declare plugin_findings

**Files:**
- Modify: `skills/skill-stress-test/references/report-schema.json`
- Modify: `tests/qa-harness/test-schema-self-consistency.sh`

- [ ] **Step 1: Read the existing schema**

Run: `jq '.properties.layers.properties.static' skills/skill-stress-test/references/report-schema.json`

Confirm current shape declares `verdict` and `per_skill` as required, no mention of `plugin_findings`.

- [ ] **Step 2: Modify the schema**

Edit `skills/skill-stress-test/references/report-schema.json`. Update `properties.layers.properties.static` to:

```json
"static": {
  "type": "object",
  "required": ["verdict", "per_skill"],
  "properties": {
    "verdict": {
      "type": "string",
      "enum": ["ACCEPT", "ACCEPT_WITH_MINOR", "REJECT_IMPORTANT", "REJECT_CRITICAL", "INCONCLUSIVE"]
    },
    "plugin_findings": {
      "type": "array",
      "default": []
    },
    "per_skill": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["skill", "verdict", "findings"],
        "properties": {
          "skill": { "type": "string" },
          "verdict": { "type": "string" },
          "findings": { "type": "array" }
        }
      }
    },
    "reason": { "type": "string" }
  }
}
```

Verify the file still parses:
```bash
jq -e . skills/skill-stress-test/references/report-schema.json > /dev/null && echo OK
```

- [ ] **Step 3: Extend test-schema-self-consistency.sh**

Edit `tests/qa-harness/test-schema-self-consistency.sh`. After the existing assertion block for `layers.behavioral/e2e/evolutionary`, add a block for `plugin_findings`:

```bash
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
```

- [ ] **Step 4: Run the schema test**

Run: `bash tests/qa-harness/test-schema-self-consistency.sh`
Expected: `PASS: schema self-consistency`.

- [ ] **Step 5: Confirm full suite still passes**

Run: `bash tests/run-tests.sh`
Expected: 42 passing.

- [ ] **Step 6: Commit**

```bash
git add skills/skill-stress-test/references/report-schema.json tests/qa-harness/test-schema-self-consistency.sh
git commit -m "feat(schema): declare layers.static.plugin_findings

Optional array on the static layer. Populated by layer-static.sh's
plugin-root pre-pass. Updates the self-consistency test to assert
both declared and emitted types.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Update verdict-resolver.js (no-op safety check)

**Files:**
- Modify: `skills/skill-stress-test/scripts/verdict-resolver.js`
- Test: existing `tests/qa-harness/test-verdict-resolver.sh`

The static-layer verdict aggregation already happens inside `layer-static.sh` (Task 4). `verdict-resolver.js` consumes the already-aggregated `layers.static.verdict`. So no logic change is required here — the existing precedence (`ACCEPT → VALIDATION_CLEAN`, anything else → `PLUGIN_DRIFT`, INCONCLUSIVE → `VALIDATION_INCONCLUSIVE`) holds.

This task is a verification step to confirm `verdict-resolver.js` doesn't need a change AND to add a defensive comment.

- [ ] **Step 1: Read verdict-resolver.js**

Run: `cat skills/skill-stress-test/scripts/verdict-resolver.js`

Confirm: it reads `report.layers.static.verdict` and does NOT inspect `plugin_findings` directly.

- [ ] **Step 2: Add a defensive invariant comment**

Edit `skills/skill-stress-test/scripts/verdict-resolver.js`. Add one comment near the static-layer read:

```javascript
// Invariant: layers.static.verdict is already the worst across plugin_findings + per_skill — set by layer-static.sh.
```

This is an LLM-instructions comment per the project's comment-discipline policy.

- [ ] **Step 3: Run existing verdict-resolver test**

Run: `bash tests/qa-harness/test-verdict-resolver.sh`
Expected: `PASS: verdict-resolver`. No behavior change.

- [ ] **Step 4: Confirm full suite still passes**

Run: `bash tests/run-tests.sh`
Expected: 42 passing.

- [ ] **Step 5: Commit**

```bash
git add skills/skill-stress-test/scripts/verdict-resolver.js
git commit -m "docs(verdict-resolver): record plugin_findings invariant

The static-layer verdict already incorporates plugin_findings severity
via layer-static.sh's aggregation. verdict-resolver consumes the
pre-aggregated verdict. One-line invariant comment for future readers.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Multi-skill plugin-findings dedup regression test

**Files:**
- Create: `tests/qa-harness/fixtures/multi-skill-noise-plugin/.claude-plugin/plugin.json`
- Create: `tests/qa-harness/fixtures/multi-skill-noise-plugin/rogue-asset.yaml`
- Create: `tests/qa-harness/fixtures/multi-skill-noise-plugin/skills/alpha/SKILL.md`
- Create: `tests/qa-harness/fixtures/multi-skill-noise-plugin/skills/beta/SKILL.md`
- Create: `tests/qa-harness/fixtures/multi-skill-noise-plugin/skills/gamma/SKILL.md`
- Test: `tests/qa-harness/test-layer-static-plugin-findings.sh`

- [ ] **Step 1: Build the fixture**

```bash
mkdir -p tests/qa-harness/fixtures/multi-skill-noise-plugin/.claude-plugin
mkdir -p tests/qa-harness/fixtures/multi-skill-noise-plugin/skills/alpha
mkdir -p tests/qa-harness/fixtures/multi-skill-noise-plugin/skills/beta
mkdir -p tests/qa-harness/fixtures/multi-skill-noise-plugin/skills/gamma
```

Create `tests/qa-harness/fixtures/multi-skill-noise-plugin/.claude-plugin/plugin.json`:
```json
{
  "name": "multi-skill-noise-plugin",
  "version": "0.0.1",
  "description": "Three skills + a plugin-root file that would trip LINT-001 in self mode."
}
```

Create `tests/qa-harness/fixtures/multi-skill-noise-plugin/rogue-asset.yaml`:
```yaml
key: value
```

For each of `alpha`, `beta`, `gamma`, copy the existing clean-plugin SKILL.md and rename the skill:

```bash
for s in alpha beta gamma; do
  sed "s/sample-clean/$s/g; s/SAMPLE_CLEAN/${s^^}_VERDICT/g" \
    tests/qa-harness/fixtures/clean-plugin/skills/sample-clean/SKILL.md \
    > tests/qa-harness/fixtures/multi-skill-noise-plugin/skills/$s/SKILL.md
done
```

Verify each SKILL.md lints ACCEPT in cross-plugin mode:
```bash
for s in alpha beta gamma; do
  bash skills/skill-voice-review/scripts/lint.sh --mode cross-plugin \
    tests/qa-harness/fixtures/multi-skill-noise-plugin/skills/$s/SKILL.md \
    | jq -r '.verdict'
done
```
Expected: three lines of `ACCEPT`.

- [ ] **Step 2: Write the failing test**

Create `tests/qa-harness/test-layer-static-plugin-findings.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
script="skills/skill-stress-test/scripts/layer-static.sh"
fixture="tests/qa-harness/fixtures/multi-skill-noise-plugin"

result="$(bash "$script" --target "$fixture")"

per_skill_count="$(printf '%s' "$result" | jq -r '.per_skill | length')"
[[ "$per_skill_count" == "3" ]] \
  || { echo "FAIL: expected 3 per_skill entries, got $per_skill_count" >&2; exit 1; }

plugin_findings_count="$(printf '%s' "$result" | jq -r '.plugin_findings | length')"
[[ "$plugin_findings_count" == "0" ]] \
  || { echo "FAIL: cross-plugin mode should filter LINT-001; got $plugin_findings_count plugin_findings" >&2; exit 1; }

skill_findings_with_lint001="$(printf '%s' "$result" | jq -r '[.per_skill[].findings[]?.rule // empty] | map(select(. == "LINT-001")) | length')"
[[ "$skill_findings_with_lint001" == "0" ]] \
  || { echo "FAIL: per_skill should not contain LINT-001 (got $skill_findings_with_lint001)" >&2; exit 1; }

verdict="$(printf '%s' "$result" | jq -r '.verdict')"
[[ "$verdict" == "ACCEPT" ]] \
  || { echo "FAIL: expected ACCEPT (all skills clean, no plugin findings in cross-plugin mode), got $verdict" >&2; exit 1; }

echo "PASS: layer-static plugin findings dedup"
```

```bash
chmod +x tests/qa-harness/test-layer-static-plugin-findings.sh
```

- [ ] **Step 3: Run the test (should already pass after Task 4)**

Run: `bash tests/qa-harness/test-layer-static-plugin-findings.sh`
Expected: `PASS: layer-static plugin findings dedup`.

If FAIL: the layer-static.sh changes from Task 4 are incomplete. Inspect `bash skills/skill-stress-test/scripts/layer-static.sh --target tests/qa-harness/fixtures/multi-skill-noise-plugin | jq .` and debug.

- [ ] **Step 4: Confirm full suite still passes**

Run: `bash tests/run-tests.sh`
Expected: 43 passing.

- [ ] **Step 5: Commit**

```bash
git add tests/qa-harness/fixtures/multi-skill-noise-plugin tests/qa-harness/test-layer-static-plugin-findings.sh
git commit -m "test(layer-static): F-22 regression — plugin-root rules don't duplicate

3-skill fixture + plugin-root .yaml file. In cross-plugin mode (the
only mode layer-static.sh invokes), LINT-001 is filtered out — so the
fixture lands at ACCEPT with zero plugin findings and zero per-skill
findings. Confirms F-22 fix.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: Cross-plugin clean fixture (F-23 regression)

**Files:**
- Create: `tests/qa-harness/fixtures/cross-plugin-clean-plugin/.claude-plugin/plugin.json`
- Create: `tests/qa-harness/fixtures/cross-plugin-clean-plugin/unrelated-asset.yaml`
- Create: `tests/qa-harness/fixtures/cross-plugin-clean-plugin/another-asset.png` (zero-byte sentinel; doesn't need to be a real PNG)
- Create: `tests/qa-harness/fixtures/cross-plugin-clean-plugin/skills/sample/SKILL.md`
- Test: `tests/qa-harness/test-layer-static-cross-plugin-clean.sh`

- [ ] **Step 1: Build the fixture**

```bash
mkdir -p tests/qa-harness/fixtures/cross-plugin-clean-plugin/.claude-plugin
mkdir -p tests/qa-harness/fixtures/cross-plugin-clean-plugin/skills/sample
```

Create `tests/qa-harness/fixtures/cross-plugin-clean-plugin/.claude-plugin/plugin.json`:
```json
{
  "name": "cross-plugin-clean-plugin",
  "version": "0.0.1",
  "description": "A plugin with non-allowlisted assets (.yaml, .png) that should land VALIDATION_CLEAN in cross-plugin mode."
}
```

Create `tests/qa-harness/fixtures/cross-plugin-clean-plugin/unrelated-asset.yaml`:
```yaml
config: true
```

Create the .png as a zero-byte sentinel (purely to trip LINT-001 in self mode):
```bash
: > tests/qa-harness/fixtures/cross-plugin-clean-plugin/another-asset.png
```

Copy the clean SKILL.md:
```bash
sed 's/sample-clean/sample/g; s/SAMPLE_CLEAN/SAMPLE_VERDICT/g' \
  tests/qa-harness/fixtures/clean-plugin/skills/sample-clean/SKILL.md \
  > tests/qa-harness/fixtures/cross-plugin-clean-plugin/skills/sample/SKILL.md
```

Verify the SKILL.md lints ACCEPT:
```bash
bash skills/skill-voice-review/scripts/lint.sh --mode cross-plugin \
  tests/qa-harness/fixtures/cross-plugin-clean-plugin/skills/sample/SKILL.md \
  | jq -r '.verdict'
```
Expected: `ACCEPT`.

- [ ] **Step 2: Write the test**

Create `tests/qa-harness/test-layer-static-cross-plugin-clean.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
script="skills/skill-stress-test/scripts/layer-static.sh"
fixture="tests/qa-harness/fixtures/cross-plugin-clean-plugin"

result="$(bash "$script" --target "$fixture")"

verdict="$(printf '%s' "$result" | jq -r '.verdict')"
[[ "$verdict" == "ACCEPT" ]] \
  || { echo "FAIL: cross-plugin-clean fixture expected ACCEPT, got $verdict" >&2; exit 1; }

plugin_findings_count="$(printf '%s' "$result" | jq -r '.plugin_findings | length')"
[[ "$plugin_findings_count" == "0" ]] \
  || { echo "FAIL: expected 0 plugin_findings (cross-plugin filters LINT-001), got $plugin_findings_count" >&2; exit 1; }

per_skill_count="$(printf '%s' "$result" | jq -r '.per_skill | length')"
[[ "$per_skill_count" == "1" ]] \
  || { echo "FAIL: expected 1 per_skill entry, got $per_skill_count" >&2; exit 1; }

first_verdict="$(printf '%s' "$result" | jq -r '.per_skill[0].verdict')"
[[ "$first_verdict" == "ACCEPT" ]] \
  || { echo "FAIL: per_skill[0].verdict expected ACCEPT, got $first_verdict" >&2; exit 1; }

echo "PASS: layer-static cross-plugin clean (F-23)"
```

```bash
chmod +x tests/qa-harness/test-layer-static-cross-plugin-clean.sh
```

- [ ] **Step 3: Run the test**

Run: `bash tests/qa-harness/test-layer-static-cross-plugin-clean.sh`
Expected: `PASS: layer-static cross-plugin clean (F-23)`.

- [ ] **Step 4: Confirm full suite still passes**

Run: `bash tests/run-tests.sh`
Expected: 44 passing.

- [ ] **Step 5: Commit**

```bash
git add tests/qa-harness/fixtures/cross-plugin-clean-plugin tests/qa-harness/test-layer-static-cross-plugin-clean.sh
git commit -m "test(layer-static): F-23 regression — cross-plugin clean with assets

Plugin with .yaml and .png assets that would trip LINT-001 in self
mode. In cross-plugin mode, no plugin findings, no per-skill findings,
verdict ACCEPT. Confirms F-23 fix.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Self-review

**Spec coverage:**
- §3.1 (rule classification) → Task 1
- §3.2 (lint mode flag) → Task 2
- §3.3 (plugin-root pre-pass + `--plugin-root-only`) → Tasks 3, 4
- §3.4 (verdict resolution) → Task 6 (verifies no change needed)
- §3.5 (schema update) → Task 5
- §5 (testing strategy 5 tests) → Tasks 1, 2, 3, 7, 8 (5 new test files; bootstrap-self-audit and Plan 1 tests verified to still pass)
- §6 (exit state — runbug/langchain/superpowers return clean if skills are clean) → Implicitly verified by Task 8 (cross-plugin-clean fixture) + Plan 1.5 re-stress pass after merge.

**No placeholders:** verified — every step has concrete content.

**Type consistency:**
- `kind` field always one of `skill-shape` or `plugin-policy`.
- `LINT_MODE` always one of `self` or `cross-plugin`.
- `plugin_findings` always an array (default `[]`).

**One spec requirement gap:** §7 of the spec lists two open questions (LINT-016 classification, severity rollup). Both are addressed in the plan:
- LINT-016 is classified as `plugin-policy` in Task 1 (matches the spec's provisional call).
- Severity rollup uses the direct rank-equivalence map in Task 4 (CRITICAL → REJECT_CRITICAL, etc.) — matches the spec.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-05-11-plan-1-5-lint-split.md`. Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?

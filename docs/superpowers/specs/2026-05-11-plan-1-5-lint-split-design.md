# Plan 1.5 — lint engine SKILL-shape / PLUGIN-policy split — design spec

**Date:** 2026-05-11
**Status:** Design approved through three sections; awaiting user review of this written spec before the implementation plan.
**Branch:** `worktree-plan-1-5-lint-split`
**Prior art:** Plan 1 (foundation + Layer 1 static) shipped as `worktree-plugin-validator-plan-1` (held, not merged). Stress findings F-22 + F-23 from `docs/superpowers/findings/2026-05-11-plan-1-stress.md` motivate this plan.

## 1. Motivation

Plan 1's V1 corpus stress run produced one consistent failure across 16 real-world plugins: every plugin with skills landed in `PLUGIN_DRIFT`, but for the same uninteresting reason. `LINT-001` (file-extension allowlist) and `LINT-016` (Integrity Block region marker) are skill-cheat's own house rules — they have nothing to say about the SKILL.md quality of any other plugin. Worse, `LINT-001` scopes to the plugin root and runs once per SKILL.md in `layer-static.sh`, so a 4-skill plugin produces 4 copies of every plugin-root finding. runbug's report had 1328/1479 findings (90%) attributable to this single rule duplicated across 4 skills.

Net effect: Layer 1's signal is unusable on real plugins until two things change.

- **F-22**: deduplicate plugin-root–scoped rules across skills (one scan, not N).
- **F-23**: split rules into universal "SKILL-shape" vs skill-cheat-internal "PLUGIN-policy" so cross-plugin runs default to skill-shape only.

## 2. Goals and non-goals

**Goals**
- Add a `kind` field to every lint rule, classifying it as `skill-shape` (universal) or `plugin-policy` (skill-cheat's house rules).
- Add a `--mode self|cross-plugin` flag to `lint.sh`. Default `self`. In `cross-plugin` mode, rules with `kind: "plugin-policy"` are filtered out before any detector runs.
- Add a `--plugin-root-only` flag to `lint.sh` so the harness can run plugin-root–scoped rules independently of any single SKILL.md.
- Rework `layer-static.sh` to run plugin-root–scoped rules ONCE as a pre-pass (using `--plugin-root-only`) and surface findings under `static.plugin_findings`. Per-skill loop only runs skill-body–scoped rules.
- Update `report-schema.json` to declare `layers.static.plugin_findings`.
- Update `verdict-resolver.js` so the static sub-verdict takes the worst across `plugin_findings` severity and `per_skill[].verdict` rank.
- Provide regression tests proving: (a) cross-plugin mode skips plugin-policy rules; (b) self mode runs them; (c) plugin-root findings appear once in `plugin_findings`, not N times across `per_skill`.
- One-time content audit: classify every existing rule (LINT-001 through LINT-021) into `skill-shape` or `plugin-policy`.

**Non-goals**
- No new lint rules.
- No detector changes other than the rule-kind filter.
- No changes to `qa-orchestrator.js` (the orchestrator already passes the report through unchanged).
- No changes to Plan 1's skill (SKILL.md frontmatter, Anti-Pattern, Core Principle, etc. all unchanged).
- No Plan 2 work (behavioral layer) and no Plan 1 hardening items (F-03, F-05, F-09 through F-14, N-2, N-3).

## 3. Architecture

### 3.1 Rule classification (data model)

`skills/skill-voice-review/references/lint-rules.json` adds a `kind` field per rule. Two valid values: `"skill-shape"` and `"plugin-policy"`. Rules without `kind` default to `"plugin-policy"` — preserves the current `mode: self` behavior with zero data migration risk.

**Provisional classification** (audit confirms or revises during implementation):
- **plugin-policy**: `LINT-001` (file-extension allowlist — skill-cheat's `.md/.js/.sh/.json/.cjs/.html/.css/.woff2` policy), `LINT-016` (`design-region-clean-of-hard-gates` Integrity Block marker — skill-cheat-specific pattern).
- **skill-shape**: every other rule (`LINT-002` through `LINT-015`, `LINT-017` through `LINT-021`) — canonical anatomy, imperative voice, HARD-GATE shape, hedges, library names, verdict tokens, etc.

The implementation plan executes the audit one rule at a time and surfaces any ambiguities before locking the classification.

### 3.2 Lint mode flag

`skills/skill-voice-review/scripts/lint.sh` accepts:

```
bash lint.sh [--mode self|cross-plugin] [--source-only] <skill-md-path>
```

- Default `--mode self`: existing behavior — all rules run regardless of `kind`. Bootstrap self-audit, all 38 existing tests, every Plan 1 fixture continues to work unchanged.
- `--mode cross-plugin`: filters out rules where `kind == "plugin-policy"` before detector dispatch. The lint summary still reports `passed` counts but only over rules that actually ran (no phantom "0 of 21 ran clean" reports).

The mode flag is parsed in lint.sh's existing flag block. The filter applies after `extends` resolution; rules inherited from `skill-cheat:baseline` carry their `kind` field through.

### 3.3 Plugin-root pre-pass

`skills/skill-stress-test/scripts/layer-static.sh` separates rules by the existing `scope` field in `lint-rules.json` (NOT the new `kind`; `scope` already exists and is used by `find-extensions` to choose the search root):
- **Plugin-root scope** (`scope: "plugin-root"`): rules that scan the plugin tree, not a single SKILL.md. Currently just `LINT-001`. Run ONCE before the per-skill loop.
- **Skill-body scope** (`scope: "skill-body"` and others): per-skill loop.

Note: Plan 1 stress finding F-something-else flagged that `scope` is only actually honored by `find-extensions` today. Plan 1.5 leans on the declared `scope` field as a routing key (the harness decides which rules run where), not as a runtime detector behavior. Bringing the rest of the detectors into honoring `scope` is out of this plan's scope.

The per-skill loop is unchanged from Plan 1: invoke `lint.sh --mode cross-plugin <skill-md>` per SKILL.md, aggregate `per_skill[]`.

The plugin-root pre-pass invokes `lint.sh --mode cross-plugin --plugin-root-only <target-root>` once. New flag: `--plugin-root-only` tells lint.sh to skip skill-body rules and emit only plugin-root findings.

Result:
```json
{
  "verdict": "PLUGIN_DRIFT",
  "plugin_findings": [
    {"rule": "LINT-001", "path": "node_modules/foo", "severity": "CRITICAL"}
  ],
  "per_skill": [
    {"skill": "alpha", "verdict": "ACCEPT", "findings": []},
    {"skill": "beta",  "verdict": "REJECT_IMPORTANT", "findings": [...]}
  ]
}
```

### 3.4 Verdict resolution

`skills/skill-stress-test/scripts/verdict-resolver.js` (and the layer's own aggregation in `layer-static.sh`) take the worst across:
- `plugin_findings`: any `severity: "CRITICAL"` → equivalent to `REJECT_CRITICAL`; `IMPORTANT` → `REJECT_IMPORTANT`; `MINOR` → `ACCEPT_WITH_MINOR`; empty → `ACCEPT`.
- `per_skill[].verdict`: per-skill rank as today.

The headline verdict mapping is unchanged: `ACCEPT` → `VALIDATION_CLEAN`; anything else → `PLUGIN_DRIFT`; `INCONCLUSIVE` → `VALIDATION_INCONCLUSIVE`.

### 3.5 Schema update

`skills/skill-stress-test/references/report-schema.json` adds:

```json
"static": {
  "type": "object",
  "required": ["verdict", "per_skill"],
  "properties": {
    "verdict": { ... unchanged ... },
    "plugin_findings": { "type": "array" },
    "per_skill": { ... unchanged ... }
  }
}
```

`plugin_findings` is optional (default `[]`) so existing fixtures without one still validate.

## 4. Component inventory

Files touched (≤6 files):

- `skills/skill-voice-review/references/lint-rules.json` — add `kind` to every rule.
- `skills/skill-voice-review/scripts/lint.sh` — `--mode self|cross-plugin`, `--plugin-root-only`, rule filter pre-dispatch.
- `skills/skill-stress-test/scripts/layer-static.sh` — split plugin-root pre-pass from per-skill loop, emit `plugin_findings`.
- `skills/skill-stress-test/scripts/verdict-resolver.js` — aggregate `plugin_findings` severity into the headline path.
- `skills/skill-stress-test/references/report-schema.json` — declare `plugin_findings`.
- `tests/qa-harness/test-schema-self-consistency.sh` — assert `plugin_findings` in declared schema.

Files NOT touched:
- All Plan 1 commits (the `plugin-validator-plan-1` worktree is held; Plan 1.5 lands on a separate branch).
- `qa-orchestrator.js`, `connect-plugin.sh`, `report-writer.js`, the SKILL.md, the 4 plan-1 fixtures.

## 5. Testing strategy

Five new regression tests under `tests/qa-harness/`:

1. **`test-lint-mode-self.sh`** — `lint.sh` in default `--mode self` runs every rule including plugin-policy rules; existing bootstrap-self-audit semantics preserved.
2. **`test-lint-mode-cross-plugin.sh`** — `lint.sh --mode cross-plugin` filters `kind: "plugin-policy"` rules out before dispatch. Assert: when running cross-plugin on a fixture that would trip LINT-001 in self mode, LINT-001 does NOT appear in findings.
3. **`test-layer-static-plugin-findings.sh`** — fixture plugin with N=4 skills + a file under plugin-root that LINT-001 would flag. Pre-fix: 4 duplicate findings. Post-fix: exactly 1 entry in `plugin_findings`, none in `per_skill[].findings`.
4. **`test-layer-static-cross-plugin-clean.sh`** — fixture plugin that has only SKILL-shape compliant content but DOES carry typical plugin assets (`.png`, `.yaml`). In cross-plugin mode (the only mode `layer-static.sh` invokes), verdict should be `VALIDATION_CLEAN`. Confirms F-23 fix.
5. **`test-rule-classification-coverage.sh`** — every rule in `lint-rules.json` has a `kind` field. No rule is missing classification; no rule has an invalid value.

Bootstrap self-audit (`tests/lint/test-bootstrap-self-audit.sh`) and Plan 1's tests (`test-layer-static.sh`, `test-orchestrator-edge-cases.sh`, `test-self-validation.sh`, etc.) must continue to pass unchanged.

## 6. Exit state

After Plan 1.5 lands:
- Running `node skills/skill-stress-test/scripts/qa-orchestrator.js --plugin <any-real-plugin>` and the resulting `report.json.layers.static.plugin_findings` shows at most the plugin-root rules that actually apply universally (currently zero, since LINT-001 and LINT-016 are plugin-policy and filtered out).
- runbug, langchain-pack, superpowers, model-trainer, and the rest of the V1 corpus return `VALIDATION_CLEAN` if their SKILL.md files match SKILL-shape rules, or `PLUGIN_DRIFT` only for real SKILL-shape violations.
- Bootstrap self-audit still catches skill-cheat's own LINT-001 violations.
- The 38 Plan 1 tests pass unchanged (after Plan 1 + Plan 1.5 merge).

## 7. Open questions

- **LINT-016 classification.** The Integrity Block `design-region-clean-of-hard-gates` marker is a skill-cheat invention. But the broader "HARD-GATE block must live in a designated region" idea could be universal. Provisional call: `plugin-policy`. Implementation plan re-reviews the rule body before locking.
- **`plugin_findings` severity rollup.** This spec proposes a direct rank-equivalence map (CRITICAL → REJECT_CRITICAL). Alternative: keep a separate severity ladder for plugin-scope findings. We pick the simpler equivalence; revisit if it produces confusing reports.

## 8. Next step

After user review of this written spec, invoke `superpowers:writing-plans` to produce a phased implementation plan (probably one phase — the scope is tight).

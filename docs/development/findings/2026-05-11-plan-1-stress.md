# plugin-validator Plan 1 — stress-test findings

**Date:** 2026-05-11
**Status:** Pre-merge stress audit. Branch `worktree-plugin-validator-plan-1`. Do NOT merge until P0 findings are resolved or explicitly accepted.
**Method:** Five stress vectors run after Plan 1's 35/35 test suite passed. V3, V4 verified inline; V5 was a manual code audit; V1 (real-world corpus) and V2 (adversarial inputs) are still in flight as of writing.

## Operating principle going forward

**Crash loud. Never swallow errors. Never produce wrong-but-plausible data.**

The harness validates other plugins. If it ever produces output that looks like a verdict but isn't, downstream users will trust it. Silent degradation in this codebase is worse than a crash, because the report has the same shape either way — readers can't tell the difference.

Concretely:
- A crashed `lint.sh` must surface as a clear `INCONCLUSIVE` per-skill entry with the underlying error excerpted, never propagate as `null` through `rank()`.
- A malformed input must produce a labeled stderr message and a non-zero exit, never a clean-looking VALIDATION_CLEAN.
- A schema mismatch between declared and emitted shape is a hard error to fix, not a "describes intent" excuse.

## Vector results

### V3 — Schema self-consistency (CONFIRMED inline)

`report-schema.json` declares `layers.behavioral`, `layers.e2e`, `layers.evolutionary` as `{"type": "object"}`. The orchestrator emits each as `null` for Plan 1. Every report.json the harness produces violates its own declared schema.

### V4 — Concurrency collision (CONFIRMED inline)

8 parallel runs against the same fixture → 1 run directory created, 7 silently overwritten. Root cause: `connect-plugin.sh:61` builds `run_id` from `strftime("%Y-%m-%dT%H-%M-%SZ")` — second-precision, no entropy. The SKILL.md Bottom Line adds `openssl rand -hex 4`; `qa-orchestrator.js` does not. Inconsistent and unsafe.

### V5 — Code audit (CONFIRMED by subagent)

Full audit at `/private/tmp/.../tasks/a4243672451944426.output`. Findings rolled into the table below.

### V2 — Adversarial inputs (CONFIRMED by subagent)

15 scenarios. Two real defects, three hardening gaps. Highlights below; full table appended at bottom.

### V1 — Real-world corpus (CONFIRMED by subagent)

23 plugins tested across `~/.claude/plugins/cache/` and the `dumbing ground/` corpus. **Zero crashes, all reports schema-valid, BLOCKED_NO_TARGET handled correctly.** But two CRITICAL signal-quality defects emerged: every real plugin lands in PLUGIN_DRIFT for the same uninteresting reason (LINT-001 fires on `.png`, `.yaml`, `.ts`, `node_modules/`), and six plugins (claude-hud, agent-sdk-dev, feature-dev, code-review, interface-design, explanatory-output-style) return VALIDATION_CLEAN with **zero skills enumerated** because they only ship commands/hooks/output-styles. Layer 1's signal is contaminated by host-policy rules and false-positive on every plugin without a `skills/` dir.

## Findings table

| # | Severity | File:line | Defect | Fix direction |
|---|---|---|---|---|
| F-01 | CRITICAL | `layer-static.sh:42-46` | `set +e ; lint_out=$(…) ; set -e` discards lint exit status; a crashed lint produces a `null` verdict that propagates through `rank()` as "worse than REJECT_CRITICAL" and writes literal `null` into `per_skill[].verdict`. | Capture status separately. Non-zero or non-JSON output → emit per-skill `INCONCLUSIVE` with the captured stderr in the finding, never poison `worst`. **FIXED in commit f856e8f** |
| F-02 | CRITICAL | `layer-static.sh:30-38` | `rank()` has no case for `INCONCLUSIVE`. Falls through to `*) echo 4`, tied with any garbage value. | Add `INCONCLUSIVE) echo 4 ;;`, bump unknown to `5` and exit non-zero on unknown. **FIXED in commit f856e8f** |
| F-03 | CRITICAL | `verdict-resolver.js:32` | `if (!staticLayer || staticLayer.verdict === "INCONCLUSIVE")` treats a *missing* `layers.static` the same as INCONCLUSIVE. Missing static is a harness bug, not a soft outcome. | Treat null static as a hard error: write a labeled stderr, exit non-zero with no headline. |
| F-04 | CRITICAL | `qa-orchestrator.js:34` + `connect-plugin.sh:16-19` | Harness-root safety check is bypassed because the orchestrator always passes `--plugin pluginArg`. Running the orchestrator from inside the harness root happily audits itself. | Hoist the `CLAUDE_PLUGIN_ROOT == pluginArg` check into the orchestrator. Refuse loud. **FIXED in commit f3bca59** |
| F-05 | CRITICAL | `qa-orchestrator.js:43` | `JSON.parse(connect.stdout)` is uncaught. Any future stdout warning crashes the orchestrator without printing a VERDICT line. | Wrap and map parse failure to `BLOCKED_NO_TARGET` with a labeled error. |
| F-06 | CRITICAL | `connect-plugin.sh:61` + `qa-orchestrator.js:46` | Seconds-only `run_id` → parallel runs silently overwrite. Confirmed: 8 → 1 directory in V4. | Add `+ "-" + crypto.randomBytes(4).toString("hex")` (or `openssl rand -hex 4` in shell) to the run_id. Use `mkdirSync(runDir, { recursive: false })` to fail loud on collision. **FIXED in commit 70c2052** |
| F-07 | CRITICAL | `report-schema.json` lines for `behavioral`, `e2e`, `evolutionary` | Declares `{"type": "object"}`, but the orchestrator emits `null` for all three in Plan 1. | Change to `{"type": ["object", "null"]}` in all three places. **FIXED in commit 5f83523** |
| F-08 | CRITICAL | `layer-static.sh:23-54` + `SKILL.md` Step 2 | Empty `skills/` enumeration returns `VALIDATION_CLEAN`. SKILL.md Step 2 explicitly says it should return `VALIDATION_INCONCLUSIVE` with `reason: "no skills found"`. | Detect empty enumeration; emit `verdict: INCONCLUSIVE`, `per_skill: []`, `reason: "no skills found"`. **FIXED in commit f856e8f** |
| F-09 | IMPORTANT | `connect-plugin.sh:44-47` | `find … \| sed \| sort \| jq` swallows per-pipe errors; an unreadable `skills/` subdir prints stderr but manifest still claims `skills: []`. | Add `[[ -r "$skills_dir" ]]` and `set -o pipefail`; surface as `BLOCKED_NO_TARGET` with reason. |
| F-10 | IMPORTANT | `qa-orchestrator.js:51-79` | Three near-identical failure blocks map every non-zero status to `VALIDATION_INCONCLUSIVE` and exit 1. SKILL.md says orchestrator only exits non-zero on `BLOCKED_NO_TARGET`. | Per-layer failures should write a partial report and exit 0 with `VALIDATION_INCONCLUSIVE`. Distinguish "no target" from "lint engine crashed" by exit code. |
| F-11 | IMPORTANT | `qa-orchestrator.js:80` | Resolver's stdout is written into `finalReport.verdict` with no whitelist validation. A resolver typo poisons the report. | Validate `headline` against the 5-token whitelist; fail loud on mismatch. |
| F-12 | IMPORTANT | `report-writer.js:31-32` | Uncaught `JSON.parse` on input files. Failure path is indistinguishable from missing file. | try/catch with `report-writer:` prefix; distinct exit code. |
| F-13 | IMPORTANT | `SKILL.md` Bottom Line bash | Diverges from orchestrator: uses `openssl rand -hex 4` and `$PWD`-relative paths. Anyone copy-pasting from inside a target plugin gets path errors. | Make the snippet self-locating (use `${BASH_SOURCE[0]}` relative resolution) or document the precondition. |
| F-14 | IMPORTANT | `report-writer.js:10-19` | `parseArgs` accepts `--foo` with no value and stores `undefined`; unknown flags silently corrupt args. No duplicate-flag rejection. | Reject unknown flags; reject flags missing values. |
| F-15 | MINOR | `connect-plugin.sh:34-35` | `plugin_version` defaulted to `""` with no validation. | Either require it or document the empty default. |
| F-16 | MINOR | `layer-static.sh:48` | O(n²) jq accumulation. Fine for <50 skills, stalls on 500. | Single `jq -s` consolidation at the end of the loop. |
| F-17 | MINOR | All scripts | No preflight check that `jq`, `node`, `git`, `openssl`, `find` exist on PATH. | Add a `command -v` preflight in `connect-plugin.sh`. |
| F-18 | **CRITICAL — SECURITY** | `connect-plugin.sh:44`, `layer-static.sh:26`, `lint.sh` | Symlinked `SKILL.md` files are silently followed. A plugin with `skills/X/SKILL.md` symlinked to `/etc/passwd`, `~/.ssh/id_rsa`, or `~/.aws/credentials` causes the harness to read that file, and lint excerpts may surface snippets of its content into `report.json`. Confirmed: a symlinked attacker file with `name: x` in frontmatter produces `"excerpt": "x"` in the report. Path-traversal / file-exfiltration via report. | In `connect-plugin.sh` and `layer-static.sh`, refuse symlinked `SKILL.md` paths: append `! -type l` to the `find` clauses, or realpath-check the resolved path stays under `${TARGET}/skills/`. Emit `VALIDATION_INCONCLUSIVE` with "symlinked SKILL.md not permitted" message and the offending path. **FIXED in commit f856e8f** |
| F-19 | IMPORTANT | `connect-plugin.sh:44`, `layer-static.sh:26` | `find -mindepth 2 -maxdepth 2` silently skips skills nested at non-standard depth. `skills/category/subskill/SKILL.md` enumerates as zero skills → VALIDATION_CLEAN. A plugin author who organizes by category gets a green pass on zero skills. | After the bounded `find`, do a second pass `find "$skills_dir" -name SKILL.md -mindepth 3 -o -maxdepth 1`. If non-empty, emit `VALIDATION_INCONCLUSIVE` with "SKILL.md found outside the supported depth" and the offending paths. **FIXED in commit f856e8f** |
| F-20 | MINOR | `connect-plugin.sh:33` | `jq -r '.name'` accepts any type; `{"name": 42}` becomes the string `"42"` in the manifest. Inconsistent with the non-empty requirement. | Add `jq -e 'select(.name \| type == "string")'`. |
| F-21 | MINOR | `layer-static.sh` lint loop | 10MB `SKILL.md` linted in ~16 sec; no upper bound. DoS-by-large-input vector. | Cap SKILL.md size at e.g. 1 MB; above cap emit `VALIDATION_INCONCLUSIVE` per-skill with the size in the finding. |
| F-22 | **CRITICAL — signal** | `skills/skill-voice-review/scripts/lint.sh:253-259` (LINT-001 detector) + `layer-static.sh` per-skill fan | `LINT-001` (find-extensions) scopes to `plugin-root` but the harness runs `lint.sh` once per SKILL.md, so the entire plugin tree gets scanned N times and every plugin-root finding is reported N times. runbug example: 332 actual file-ext violations × 4 skills = 1328 duplicate findings, drowning the real signal. The detector also scans `node_modules/`, build artifacts, captures, dotted dirs that have nothing to do with skill quality. | Dedupe plugin-root–scoped rules at layer aggregation (run them once, not per-skill). Also prune `.git`, `node_modules`, `dist`, `.skill-cheat-qa`, dotted dirs from the scan. **Touches lint.sh, not just the harness — out of scope for this branch; documented as Plan-2 prerequisite.** |
| F-23 | **CRITICAL — signal** | `skills/skill-voice-review/references/lint-rules.json` LINT-001 detector | Allowlist `.md .js .sh .json .cjs .html .css .woff2` is **skill-cheat-internal**, not a baseline reasonable for arbitrary plugins. Every real plugin in the V1 corpus that has `.png`, `.yaml`, `.ts`, `.py`, `.toml`, `.txt`, `.lock`, `LICENSE` (i.e., every real plugin) lands in PLUGIN_DRIFT for reasons that have nothing to do with skill quality. Result: Layer 1's signal-to-noise is zero on real-world inputs. | Split LINT rules into "SKILL-shape" (universal: HARD-GATE, Anti-Pattern, anatomy, voice) and "PLUGIN-policy" (skill-cheat-specific: file-ext allowlist, dir layout). Cross-plugin runs disable PLUGIN-policy by default. **Lint engine change, not harness — out of scope for this branch; documented as Plan-2 prerequisite.** |
| F-24 | IMPORTANT | `layer-static.sh:23-26` + 6 confirmed cases in V1 | Plugins with zero `skills/<name>/SKILL.md` (commands-only / hooks-only / output-style plugins) return `VALIDATION_CLEAN` with zero work done. Real instances in V1: claude-hud, agent-sdk-dev, feature-dev, code-review, interface-design, explanatory-output-style. Direct user harm: those plugins ship features the harness should describe as "not yet validated" rather than "clean." | Folded into F-08 fix: empty enumeration → `VALIDATION_INCONCLUSIVE` with `reason: "no skills to lint"`. **FIXED in commit f856e8f** |
| F-25 | MINOR | `lint.sh:47-51` jq accumulation | langchain-pack (24 skills) took 43 s; ~1.8 s per skill. Scales linearly, will hurt at 50+ skill plugins. | Same fix as F-16 (single `jq -s` consolidation), but landing in `lint.sh` rather than `layer-static.sh`. |

## Fix-now vs. defer (preliminary, pending V1 + V2)

**Fix now in this branch, before merge** (all on the harness side, no lint-engine changes):
- **F-18 (symlink exfiltration)** — CRITICAL security defect. Read of arbitrary host files via symlinked `SKILL.md`, snippets land in report.json.
- F-01, F-02 (layer-static silent-crash propagation) — violates the new "crash loud" principle.
- F-04 (orchestrator self-audit bypass) — harness must refuse to audit itself by accident.
- F-06 (concurrency collision) — silent data loss confirmed in V4.
- F-07 (schema vs. emitted shape) — single-line schema fix.
- F-08 / F-24 (empty enumeration → false CLEAN) — SKILL.md itself describes the correct behavior; the code disobeys it. V1 confirmed 6 real plugins hit this.
- F-19 (skills at non-standard depth silently skipped) — same shape as F-08.

**Plan-2 prerequisites — must land before behavioral layer or its findings are also noise** (lint-engine changes, separate plan):
- **F-22** (LINT-001 duplication across skills) — `lint.sh` change to dedupe plugin-root–scoped rules.
- **F-23** (LINT-001 allowlist is skill-cheat-internal) — `lint-rules.json` change to split SKILL-shape rules from PLUGIN-policy rules.

**Defer to later hardening passes:**
- F-03, F-05, F-09, F-10, F-11, F-12, F-13, F-14.

**Backlog:**
- F-15, F-16, F-17, F-20, F-21, F-25.

## Open questions for V1

- Does the harness crash on any real plugin in the corpus?
- Does empty-`skills/` get returned as INCONCLUSIVE on a real plugin (Anthropic skills package?), or does F-08 actually bite anyone today?
- Does category-organized layout (the Anthropic skills folder uses `skills/skills/<name>/SKILL.md`?) trip F-19 in practice?

## V2 — adversarial inputs (full table)

| # | Scenario | Exit | Verdict | Report Written | Notes |
|---|---|---|---|---|---|
| 1 | Empty `skills/` dir | 0 | VALIDATION_CLEAN | yes | F-08 — should be INCONCLUSIVE |
| 2 | No `skills/` dir at all | 0 | VALIDATION_CLEAN | yes | F-08 |
| 3 | Missing `.name` in plugin.json | 1 | BLOCKED_NO_TARGET | no | OK |
| 4 | Empty `{}` plugin.json | 1 | BLOCKED_NO_TARGET | no | OK |
| 5 | Invalid JSON in plugin.json | 1 | BLOCKED_NO_TARGET | no | OK |
| 6 | Non-UTF8 SKILL.md (BOM bytes) | 0 | PLUGIN_DRIFT | yes | OK — lint flags structure |
| 7 | Symlink `SKILL.md → /etc/passwd` | 0 | PLUGIN_DRIFT | yes | **F-18 — silent follow, content excerpted into report** |
| 8 | Skill dir with no SKILL.md | 0 | VALIDATION_CLEAN | yes | OK — dir without SKILL.md skipped |
| 9 | Skill name `my skill` (space) | 0 | PLUGIN_DRIFT | yes | OK — name preserved end-to-end |
| 10 | Skill name with emoji `💀-skill` | 0 | PLUGIN_DRIFT | yes | OK |
| 11 | Shell metachars in dir name | 0 | PLUGIN_DRIFT | yes | OK — no command execution |
| 12 | 10MB SKILL.md (text) | 0 | PLUGIN_DRIFT | yes | F-21 — slow (~16 s), no cap |
| 13 | `skills/category/subskill/SKILL.md` | 0 | VALIDATION_CLEAN | yes | **F-19 — silent skip, manifest claims 0 skills** |
| 14 | Extra fields in plugin.json | 0 | VALIDATION_CLEAN | yes | OK — ignored as intended |
| 15 | `--plugin` vs cwd auto-detect | 0 | VALIDATION_CLEAN | yes | OK — `--plugin` wins |

## V1 re-stress (2026-05-12, post Plan 1.5)

**Method:** ran `qa-orchestrator.js --plugin <root>` against 47 plugins (`~/.claude/plugins/cache/` + `dumbing ground/`), wider than V1's 23. Layer 1 only, cross-plugin mode (default since Plan 1.5 — plugin-policy rules filtered).

**Verdict distribution (47 plugins):**
- 34 PLUGIN_DRIFT — real skill-shape findings
- 13 VALIDATION_INCONCLUSIVE — no `skills/` directory (F-08/F-24 fix verified on real corpus)
- 0 false VALIDATION_CLEAN
- 0 crashes

**F-22 (LINT-001 duplicated N times per skill) — DEAD.** Zero LINT-001 findings anywhere in the corpus. LINT-001 is now classified `kind: plugin-policy`; `--mode cross-plugin` skips it entirely. `layer-static.sh` runs a single `--plugin-root-only` pre-pass so plugin-root-scope rules can never fan out per-skill in any mode.

**F-23 (file-ext allowlist contaminates every foreign plugin) — DEAD.** Total `plugin_findings` across 47 plugins: **0**. Every finding in the corpus is now a SKILL-shape rule (LINT-002–LINT-021 minus LINT-016, the second plugin-policy rule). The skill-cheat-internal allowlist (`.md .js .sh ...`) no longer poisons cross-plugin signal.

**Rule distribution across the 4,954 corpus findings (all skill-shape):**

```
LINT-010: 2155   LINT-005:  288   LINT-013:   59
LINT-003:  492   LINT-014:  287   LINT-007:   28
LINT-020:  430   LINT-004:  194   LINT-006:   25
LINT-021:  402   LINT-012:  192   LINT-018:   21
LINT-008:  297   LINT-019:   67   LINT-017:   10
                                  LINT-002:    7
```

(unique rule IDs: 16; LINT-001 and LINT-016 absent as expected)

**Direct V1 comparison — runbug:**
| Metric | V1 (pre-fix) | V1 re-stress (post Plan 1.5) |
|---|---|---|
| `plugin_findings` | 1328 (332 LINT-001 × 4 skills) | **0** |
| per-skill findings | drowned in LINT-001 | 147 (LINT-002..020, all skill-shape) |
| verdict source | LINT-001 false-positive | real anatomy/hard-gate violations |

**F-08/F-24 (empty-skills false CLEAN) — verified dead on real corpus.** 13 plugins correctly route to INCONCLUSIVE with `reason: "no skills/ directory under target"`. V1's 6 confirmed cases (claude-hud, agent-sdk-dev, feature-dev, code-review, interface-design, explanatory-output-style) all in this bucket plus 7 more in the broader corpus (commit-commands, learning-output-style, pr-review-toolkit, ralph-wiggum, security-guidance, claude-for-msft-365-install, agent-sdk-dev/dumbing).

**Conclusion:** Layer 1 signal-to-noise on real plugins is now bounded by the SKILL-shape rule surface, not by the harness's own bookkeeping. Plan 1.5 closes F-22, F-23, F-08, F-24 in the wild.

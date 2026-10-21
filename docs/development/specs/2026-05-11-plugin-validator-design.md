# plugin-validator harness — design spec

**Date:** 2026-05-11
**Status:** Design approved through 4 sections; awaiting user review of this written spec before implementation plan.
**Prior art studied:** Anthropic's `skill-creator` at `/Users/hook/Documents/coding/python/dumbing ground/skills/skills/skill-creator/` — confirmed pattern for subprocess `claude -p` triggering evaluation. skill-cheat's existing Plan-5 benchmark engine (`run-eval.js`, `aggregate-benchmark.js`) is the foundation; this design extends it from "rate one description against one eval set" to "stress-test a whole plugin across 4 layers with evolutionary mutation."

## 1. Motivation

The four research agents from 2026-05-11 surfaced 14 gaps across lint coverage, references completeness, pipeline contract integrity, and test coverage. Themes:

- **Detector contracts drift silently.** Lint rules declare `scope: "skill-body"` but every detector except `find-extensions` ignores `scope` — five rules currently scan content they were never meant to.
- **Pipeline handoffs drift silently.** Schema says downstream stages read `scope.json`; stages read `scope.md` instead. `pluginMode` enum values diverge between schema and consumer. `ACCEPT_WITH_MINOR` unlocks the write in the bootstrap but is rejected by scaffold.
- **Coverage gaps are invisible.** No mechanism tests whether the lint engine actually catches the prescriptions in `canonical-anatomy.md`, or whether a real plugin's skills behave the way their frontmatter claims they do.

A holistic test pass cannot find these. They surface only when conditions vary — different baselines, different mutation paths, different worktrees. The harness specified here is the QA team for any connected Claude Code plugin: it picks up the repo, validates every skill across 4 layers, then evolves mutations to find blind spots in the validation itself.

## 2. Goals and non-goals

**Goals**
- Accept any Claude Code plugin (target's path or auto-detected from cwd) and produce a graded validation report.
- Cover four orthogonal validation axes: static anatomy/voice, behavioral triggering, end-to-end pipeline contracts, evolutionary mutation coverage.
- Surface blind spots in skill-cheat's own enforcement (lint rules, voice-review, pipeline contracts) by mutating known-good corpus baselines and measuring catch rate.
- Make ownership of every finding unambiguous: plugin-author findings vs skill-cheat-maintainer findings, split at report time.
- Use per-mutation git worktrees so experiments cannot pollute each other or the baseline.

**Non-goals**
- Not a replacement for the 5-stage authoring pipeline. This validates already-authored plugins.
- Not a real-time linter in IDE; it is a batched run.
- Not a fuzzer over arbitrary input strings. Mutations are typed transforms over SKILL.md structure and frontmatter.
- Not a security tool. It does not check for secrets, vulns, or supply-chain risk.

## 3. Architecture overview

A new skill `/skill-stress-test` is added under `skills/skill-stress-test/`. It is not a pipeline stage; it runs independently against any plugin.

```
/skill-stress-test --plugin <path>
  │
  ├── Connect & discover
  │     reads .claude-plugin/plugin.json, enumerates skills/
  │
  ├── Corpus refresh (on demand)
  │     scripts/corpus-seeder.sh keeps ~/.skill-cheat/corpus/ current
  │
  ├── Layer 1: Static audit (per skill)         → static/findings.json
  │     reuses skills/skill-voice-review/scripts/lint.sh
  │
  ├── Layer 2: Behavioral simulation (per skill) → behavioral/findings.json
  │     extends scripts/run-eval.js per trigger phrase + adversarial variants
  │
  ├── Layer 3: E2E pipeline simulation           → e2e/findings.json
  │     only if the target is pipeline-style; otherwise PIPELINE_INAPPLICABLE
  │
  └── Layer 4: Evolutionary loop                 → evolutionary/fitness-landscape.json
        for each mutation operator:
          for each corpus baseline:
            git worktree add → apply operator → run targeted layer
            on caught: remove worktree; on missed: retain for inspection
        compose surviving mutations into next generation
        stop at max-generation, no-new-escapes-for-2-gens, or token budget
```

**Layer ownership split:** Layers 1–3 measure the target plugin. Layer 4 measures skill-cheat's own enforcement coverage.

## 4. Skill placement, triggers, verdicts

**Trigger phrases** (frontmatter `description`):
- "stress-test this plugin"
- "validate the skills in <path>"
- "QA the channelle-test plugin"
- "run the harness against runbug"
- "find blind spots in my plugin"

**Connection model**:
- Explicit: `/skill-stress-test --plugin /abs/path/to/plugin-repo`
- Auto-detect: when invoked from a directory containing `.claude-plugin/plugin.json`, that plugin is the target.

**Inputs read from the target**:
1. `.claude-plugin/plugin.json` — name, version, marketplace metadata.
2. `skills/*/SKILL.md` — all skills enumerated.
3. `scripts/`, `references/`, `hooks/` — exercised by E2E if present.

**Headline verdicts** (single ALL-CAPS tokens):
- `VALIDATION_CLEAN` — baseline layers AND mutation loop both clean.
- `PLUGIN_DRIFT` — baseline layers reported findings on the unmutated plugin. Owner: plugin author.
- `HARNESS_GAP` — mutation loop surfaced edge cases no baseline layer catches. Owner: skill-cheat maintainer.
- `VALIDATION_INCONCLUSIVE` — harness couldn't complete (claude binary missing, partial corpus, timeout).
- `BLOCKED_NO_TARGET` — no plugin resolved from arg or cwd.

**Precedence** (worst wins for headline): `BLOCKED_NO_TARGET > VALIDATION_INCONCLUSIVE > HARNESS_GAP > PLUGIN_DRIFT > VALIDATION_CLEAN`.

Rationale: if both DRIFT and GAP occur, headline is `HARNESS_GAP` because the plugin author would never have been told about the drift through normal lint — fix our enforcement first.

**Per-layer sub-verdicts** (in findings JSON):
- Static reuses voice-review's existing tokens: `ACCEPT` / `ACCEPT_WITH_MINOR` / `REJECT_IMPORTANT` / `REJECT_CRITICAL`.
- Behavioral: `TRIGGER_CLEAN` / `TRIGGER_MISS` / `TRIGGER_BAIT_FOUND` / `TRIGGER_INCONCLUSIVE`.
- E2E: `CONTRACT_HOLDS` / `CONTRACT_BREAK` / `PIPELINE_INAPPLICABLE`.
- Evolutionary: `LANDSCAPE_CLEAN` / `BLIND_SPOT_DETECTED` / `EVOLUTION_INCOMPLETE`.

**Token-spend posture**: behavioral layer is `claude -p` per trigger phrase × N reruns. The orchestrator prints a token estimate before launching Layer 4 and requires confirmation when projected cost exceeds `--max-tokens` (default 200k).

## 5. Mutation taxonomy and evolutionary loop

Mutations are typed transforms `(baseline, params) → mutant`, grouped by which architectural layer is expected to catch them.

**Class A — Voice (target: static/lint layer)**
- `inject-hedge` — replace `Do NOT X` with hedged form.
- `weaken-hard-gate` — remove or soften a HARD-GATE block.
- `third-person-drift` — replace `Trigger /X whenever` with `the skill triggers when`.
- `library-leak` — inject a library name into body prose.
- `verdict-token-case-drift` — lowercase or kebab a verdict token.

**Class B — Structural (target: static/anatomy layer)**
- `drop-section` (Rationalization Table, Anti-Pattern, Process Flow, etc.).
- `reorder-sections` against canonical 13-section order.
- `drop-bottom-line`.
- `truncate-rationalization` to a single row.
- `omit-antipattern-quote`.
- `digraph-orphan-node` adds an unreachable Process Flow node.

**Class C — Frontmatter (target: static + behavioral)**
- `terse-description` — collapse to one sentence; expect behavioral layer to surface trigger misses.
- `drop-trigger-phrases` — remove user-phrasing quotes.
- `drop-verdict-token` — remove ALL-CAPS verdict mention.
- `name-h1-mismatch` — change H1 to mismatch frontmatter `name`.

**Class D — Pipeline contract (target: E2E layer)**
- `bad-verdict-emit` — Bottom Line emits lowercase verdict.
- `skip-sidecar` — produce `design.md` without `.sha256`.
- `wrong-pluginmode-enum` — emit `"new plugin"` when schema says `"new"`.
- `orphan-verdict` — emit a verdict no downstream consumes.
- `read-from-wrong-path` — point a stage at `scope.md` when schema says `scope.json`.
- `verdict-frontmatter-mismatch` — emit a verdict not declared in frontmatter.

**Class E — Behavioral (target: behavioral layer)**
- `description-trigger-mismatch` — keep description triggers; body doesn't serve them.
- `unannounced-trigger` — add functionality the description never mentions.
- `false-trigger-bait` — claim triggers that should fire another skill.

**Per-mutation outcome**: `caught` (targeted layer flagged at CRITICAL/IMPORTANT), `missed` (layer ran but didn't flag), `false_positive` (layer flagged the unmutated baseline — noisy detector).

**Evolutionary loop**: generation 0 applies single operators; generation N composes operators that escaped earlier generations. Selection pressure: escapes survive into the next generation and get composed with new operators. Stop conditions: configurable `--max-generation` (default 3), no new escapes for two consecutive generations, or `--max-tokens` exceeded.

**Output**: fitness landscape table `(operator, baseline, generation) → outcome`. High-value blind spots are `(operator-combo, layer)` cells with 0% coverage across multiple baselines.

**Corpus integration**: each generation samples its baseline from the seeded corpus. Same operator against different baselines exercises different rule corners.

Catalog at `references/mutation-taxonomy.md`; operator implementations at `scripts/mutators/<class>.js`.

## 6. Storage layout and worktree lifecycle

**Corpus** (user-global, shared across plugins under test):
```
~/.skill-cheat/corpus/
├── manifest.json                  source URL, commit SHA, last-pulled-at
├── anthropic-skills/              full git clones, not shallow
├── financial-services/
├── superpowers/
├── user-plugins/<plugin-name>/
└── public/<remote-slug>/
```
Refresh: `bash scripts/corpus-seeder.sh [--force]`. Sources live in `references/corpus-sources.json` so adding a repo doesn't require editing scripts.

**Worktrees** (ephemeral, used only by Layer 4):
```
~/.skill-cheat/worktrees/<run-id>/<mutation-id>/
```
- `<run-id>` = `YYYY-MM-DDTHH-MM-SS-<8charhash>`.
- `<mutation-id>` = `<class>_<operator>_<baseline-slug>_g<N>`.
- Branch: `skill-cheat/qa/<run-id>/<mutation-id>` off the corpus repo (not skill-cheat, not the target).
- Mutations apply to corpus baselines (known-good skills); we then run skill-cheat's lint/voice-review against the mutant to test our enforcement.

**Lifecycle per mutation**: create worktree → apply operator → run targeted layer → record outcome → on `caught`: `git worktree remove --force` + delete branch. On `missed` or `false_positive`: retain for inspection. `bash scripts/prune-worktrees.sh [--older-than 7d]` cleans retained escapes on demand.

**Reports** (in the target plugin so the author owns their results):
```
<target>/.skill-cheat-qa/runs/<run-id>/
├── manifest.json                  target SHA, corpus SHAs, harness version
├── static/findings.json
├── behavioral/findings.json
├── e2e/findings.json
├── evolutionary/fitness-landscape.json
├── evolutionary/escapes/<mutation-id>.json
├── report.json
└── report.html
```
First run adds `.skill-cheat-qa/` to the target's `.gitignore` (with confirmation).

**Concurrency**: mutations within a generation are independent → parallelizable. Default `--parallel 4`. Disk budget: corpus ≈ 200–500MB; each worktree ≈ 10–50MB transient.

**Target without git**: bail with `VALIDATION_INCONCLUSIVE` and a message that `git init && git add . && git commit` would unblock the run.

## 7. Report format

**`report.json`** (machine artifact, schema at `references/report-schema.json`):
```
{
  "verdict": "HARNESS_GAP",
  "manifest": { target_sha, corpus_shas, harness_version, model },
  "cost": { token_estimate, token_actual, duration_ms },
  "layers": {
    "static":       { verdict, findings[] },
    "behavioral":   { verdict, runs[], stats: { trigger_rate, stddev } },
    "e2e":          { verdict, stages[] },
    "evolutionary": { verdict, generations, escapes[], coverage_by_class }
  },
  "ownership": {
    "plugin_author_actions": [...],
    "skill_cheat_actions":   [...]
  }
}
```

**`report.html`** (human artifact, eval-viewer-style):
- Headline verdict banner, color-coded.
- Collapsible manifest panel.
- Per-layer cards with sub-verdicts and findings.
- Evolutionary heatmap: mutation-class × layer = coverage %.
- Drill-down to per-escape diffs (mutated SKILL.md vs baseline, slipped-past patch highlighted).

Template at `references/html-template.html`; renderer at `scripts/render-report.js`.

**Ownership split** is load-bearing for action: opening the report tells the reader immediately which list to work — plugin-author findings (baseline layers) or skill-cheat-maintainer findings (evolutionary escapes).

**Cost transparency**: token estimate printed before Layer 4 launches; confirmation required when estimate exceeds `--max-tokens`. Final `cost.token_actual` reconciles after the run.

## 8. Component inventory

New files under `skills/skill-stress-test/`:
- `SKILL.md` — frontmatter, triggers, Anti-Pattern, Core Principle, Process Flow, Checklist, Step Details, Gate Functions, Rationalization Table, Red Flags, Key Principles, Bottom Line. Canonical 13-section anatomy.
- `scripts/connect-plugin.sh` — resolve target from arg or cwd; emit normalized plugin manifest.
- `scripts/corpus-seeder.sh` — clone/refresh corpus repos.
- `scripts/worktree-manager.sh` — wrap `git worktree add/remove` with naming convention.
- `scripts/qa-orchestrator.js` — entry point; sequences Layers 1–4.
- `scripts/mutators/voice.js`, `structural.js`, `frontmatter.js`, `pipeline.js`, `behavioral.js` — operator implementations.
- `scripts/render-report.js` — JSON → HTML.
- `scripts/prune-worktrees.sh` — retention cleanup.
- `references/mutation-taxonomy.md` — operator catalog with Rationalization Table + Red Flags.
- `references/corpus-sources.json` — repo URLs.
- `references/report-schema.json` — JSON Schema for `report.json`.
- `references/html-template.html` — report template.
- `references/sub-verdict-vocabulary.md` — per-layer sub-verdict definitions.
- `agents/qa-reporter.md` — subagent template for narrative report generation.
- `evals/` — fixtures for testing the harness itself.

Reused from existing skill-cheat:
- `skills/skill-voice-review/scripts/lint.sh`, `lint.js`, `lint-rules.json` — Layer 1.
- `skills/skill-voice-review/scripts/run-eval.js`, `aggregate-benchmark.js` — Layer 2 foundation, extended to accept multi-skill plugins.

## 9. Testing strategy (dogfooding)

The harness must validate itself. The repo gets:
- `tests/qa-harness/test-connect-plugin.sh` — argument parsing, cwd auto-detect, missing-`.claude-plugin/` case.
- `tests/qa-harness/test-corpus-seeder.sh` — initial clone, idempotent refresh, manifest accuracy.
- `tests/qa-harness/test-worktree-manager.sh` — create/remove cycle, naming convention, leak detection.
- `tests/qa-harness/test-mutators/<class>.sh` — each mutator class gets a fixture baseline and asserts the mutation is applied as specified.
- `tests/qa-harness/test-orchestrator-mock.sh` — end-to-end with mock corpus and mock `claude -p` (uses existing `--mock-stream-file` pattern from `run-eval.js`).
- `tests/qa-harness/test-self-validation.sh` — run `/skill-stress-test --plugin .` against skill-cheat itself; expect `PLUGIN_DRIFT` (the 14 gaps) on first run, `VALIDATION_CLEAN` after they're fixed.

All tests must pass before `/skill-stress-test` ships as a skill.

## 10. Open questions

- **Behavioral fixture seeding**: trigger phrases for adversarial variants are presently hand-authored. Should the harness generate adversarial phrasings via `claude -p` upfront, or require the plugin author to provide an `evals/adversarial-set.json`? Defer to implementation plan.
- **Cross-plugin contamination**: if the corpus contains a plugin whose skills share names with the target, do we namespace at the trigger-replay step? Likely yes; design assumes per-plugin namespacing.
- **Fitness function tuning**: current proposal treats every miss equally. A weighted variant (CRITICAL > IMPORTANT > MINOR) may produce a better landscape ranking. Defer to first run's empirical results.
- **CI integration**: how does the harness expose a non-zero exit code for CI? Probably `exit 1` on `HARNESS_GAP` and `exit 2` on `PLUGIN_DRIFT`, with `--strict` toggle to fail on either. Defer to implementation plan.

## 11. Next step

After user review of this written spec, invoke the `superpowers:writing-plans` skill to produce a phased implementation plan.

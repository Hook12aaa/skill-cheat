# How skill-cheat was built

This is the story of how skill-cheat went from "I keep typing the same scaffolding" to a five-stage pipeline with twenty-one lint rules. Everything here was written during the build, not after the fact. The plans are dated, the findings reference specific commits, and the specs carry SHA-256 sidecars that locked the design before implementation began.

If you want to understand what skill-cheat does, read the [README](README.md). If you want to understand how it got here, keep reading.

---

## The approach

I don't build pipelines top-down. What I've found works — and this is true for most of the agentic stuff I've built — is to try things out in a few key experiments first, come back, and ask: can I turn this into something repeatable?

skill-cheat started that way. I'd been building skills for the model trainer, the auto-discover runner, things like that. Each one taught me something about what made a skill hold up under load versus fall apart. By the time I sat down to build skill-cheat, I already had an intuition for the anatomy. The job was to make the intuition into a contract.

The whole thing was built in six planned phases over three weeks in April–May 2026. Each phase had a written spec, a written implementation plan, and a test suite that had to pass before merge. I used the [superpowers](https://github.com/nicholasgriffintn/superpowers) orchestration framework for task decomposition and subagent-driven development throughout.

| Phase | What shipped | Plan |
|---|---|---|
| **1 — Foundation** | Plugin skeleton, hooks, config, bootstrap SKILL.md, test runner | [Plan 1](docs/development/plans/2026-04-22-skill-cheat-plan-1-foundation.md) |
| **2 — Lint engine** | 16 rules, 7 detectors, lint.js + lint.sh, JSON schema, bad/good fixtures | [Plan 2](docs/development/plans/2026-04-22-skill-cheat-plan-2-lint-engine.md) |
| **3 — Pipeline** | 6 stage skills, voice-reviewer agent, 5 slash commands, self-audit | [Plan 3](docs/development/plans/2026-04-22-skill-cheat-plan-3-pipeline.md) |
| **4 — Benchmark foundation** | scope.json/design.json sidecars, eval-set + assertion skeletons | [Plan 4](docs/development/plans/2026-04-23-skill-cheat-plan-4-benchmarking-foundation.md) |
| **5 — Benchmark engine** | run-eval.js, aggregate-benchmark.js, git-worktree isolation, grader/comparator/analyzer agents | [Plan 5](docs/development/plans/2026-04-23-skill-cheat-plan-5-benchmark-engine.md) |
| **1.5 — Lint split** | skill-shape vs plugin-policy rule taxonomy, --mode flag, plugin-root pre-pass | [Plan 1.5](docs/development/plans/2026-05-11-plan-1-5-lint-split.md) |

Plan 1.5 is out of order because it landed between Plans 5 and the stress-test work. What happened was the V1 corpus run against 47 real plugins exposed that my plugin-policy rules (file-extension allowlist, directory layout) were producing false positives on foreign plugins. The fix was to classify every rule as either `skill-shape` (universally portable) or `plugin-policy` (my local opinion) and filter by kind at query time. Simple in retrospect, but it took running against real plugins to see it.

---

## Design specs

One of the things I picked up from superpowers is the discipline of writing the design spec before the implementation plan. Each phase started from a written spec that was approved before any code was written.

- [Original design spec](docs/development/specs/2026-04-22-skill-cheat-design.md) — the foundational architecture. The five-stage pipeline, the lint engine's detector dispatch, the Integrity Block pattern, and the author/reviewer separation all started here.
- [Plugin-validator design](docs/development/specs/2026-05-11-plugin-validator-design.md) — the stress-test harness. I designed four layers (static, behavioural, E2E, evolutionary); only static ships in v0.1.
- [Lint split design](docs/development/specs/2026-05-11-plan-1-5-lint-split-design.md) — the skill-shape vs plugin-policy taxonomy that came out of the corpus run.

The original design spec carries a SHA-256 sidecar at `docs/development/specs/2026-04-22-skill-cheat-design.md.sha256`. This is the same Integrity Block pattern the plugin itself enforces — I locked my own design before writing the implementation plan. Eating my own cooking.

---

## Stress-test findings

After the plugin-validator's first plan shipped, I ran a five-vector stress audit before merging. This is the kind of thing that catches the stuff your test suite doesn't — the edges where the system produces output that *looks* right but isn't.

The full findings are at [Plan 1 stress findings](docs/development/findings/2026-05-11-plan-1-stress.md). The highlights:

- **F-07 (Schema self-consistency)** — the report schema declared `layers.behavioral` etc. as `{"type": "object"}` but the orchestrator emitted `null`. Every report the harness produced violated its own schema. Fixed by declaring unwired layers nullable.
- **F-06 (Run ID collision)** — second-precision timestamps with no entropy meant 8 parallel runs against the same fixture produced 1 run directory and silently overwrote the other 7. Fixed with `openssl rand -hex 4` entropy.
- **F-04 (Self-audit refusal)** — the harness would happily audit its own plugin root if you invoked it from within skill-cheat. Fixed with a self-detection guard.

The principle that crystallised from this: *crash loud, never swallow errors, never produce wrong-but-plausible data.* A harness that validates other plugins cannot itself produce output that looks like a verdict but isn't. This became principle 7 in the README.

---

## What's not shipped yet

The benchmark engine (Plans 4–5) is scaffolded but not wired into `/skill-voice-review`. The scripts exist and pass their tests, but the integration that runs `claude -p` against eval-set skeletons and folds results into the voice-review verdict is Plan 6 work.

The stress-test harness ships Layer 1 (static lint). Layers 2–4 (behavioural, E2E, evolutionary) are designed but not implemented. I'm looking forward to getting there — the evolutionary layer in particular is where it gets interesting.

---

## The V1 corpus run

On 14 May 2026, I ran the stress-test harness against 47 real plugins from `~/.claude/plugins/cache/` plus a wider corpus:

- 34 `PLUGIN_DRIFT` — at least one SKILL.md triggered a lint finding.
- 13 `VALIDATION_INCONCLUSIVE` — no-skills plugins routed correctly.
- 0 false `VALIDATION_CLEAN`.
- 0 crashes.

This was the moment I knew the skill-shape / plugin-policy split was working. Signal on foreign plugins was bounded by universally portable rules, and no plugin-policy false positive leaked through cross-plugin mode.

---

## What I learned from along the way

- **[Superpowers](https://github.com/nicholasgriffintn/superpowers)** — this is where I learned the gate-driven, review-separated approach to Claude skills. The author/reviewer separation, the plan-driven development discipline, the SHA fingerprinting — all of that started there. skill-cheat wouldn't exist without it.
- **[Spectral (Stoplight)](https://github.com/stoplightio/spectral)** — the reference architecture for typed-rule schema engines. When I was figuring out how to lint prose-shaped artifacts with declarative rules, this was the model.
- **CoNLL-2010 Shared Task** — the hedge-word denylist isn't vibes. It sits on Farkas et al.'s BioScope corpus and Hyland's metadiscourse taxonomy. Real NLP research, not a word list I made up.
- **[anthropics/skills](https://github.com/anthropics/skills)** — three grader/comparator/analyzer subagent prompts are ported under Apache 2.0. See [NOTICE](NOTICE).
- **Fagan inspections (1976)** — the author-cannot-self-review rule is fifty years old. It works because separation is the constraint, not the format.

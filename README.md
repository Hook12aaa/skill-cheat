# skill-cheat

A Claude Code plugin that scaffolds skills in the imperative, gate-driven, contract-first style.

**Runs standalone. No plugin dependencies.** Host-tool prerequisites: `bash`, `openssl`, `node`, `graphviz` (`dot`), `jq`.

## Install

```
/plugin marketplace add /path/to/skill_cheat
/plugin install skill-cheat
```

## Use

Any of these invocations kicks off the 5-stage pipeline:

- Type `/skill-scope` to start explicitly.
- Say "I want to build a skill for X" — the UserPromptSubmit hook reminds Claude to start the pipeline.

## Stages

1. `/skill-scope` — lock name, triggers, verdicts, Anti-Pattern. Emits `scope.md`, `scope.json`, `evals/eval-set-skeleton.json`.
2. `/skill-design` — write HARD-GATEs, Core Principle, flow, checklist. Emits `design.md`, `design.json`, `evals/assertion-skeleton.json`, Integrity Block + SHA-256.
3. `/skill-author` — fill the skill body; verify Integrity Block unchanged.
4. `/skill-voice-review` — mechanical lint + voice-reviewer subagent; REJECT or ACCEPT. Phase-3 behavioral benchmark lands in Plan 5+.
5. `/skill-scaffold` — emit the plugin tree at the target path (`evals/` travels with the skill).

## Validation: /skill-stress-test

Stress-tests any connected Claude Code plugin by running the voice-review lint engine over every SKILL.md in the target.

Usage:

```bash
# explicit target
node skills/skill-stress-test/scripts/qa-orchestrator.js --plugin /abs/path/to/plugin

# cwd auto-detect
cd /abs/path/to/plugin && node /abs/path/to/skill-cheat/skills/skill-stress-test/scripts/qa-orchestrator.js
```

Output: `<target>/.skill-cheat-qa/runs/<run-id>/report.json` plus a single `VERDICT: <token>` line on stdout.

Verdicts (Plan 1, static layer only):

- `VALIDATION_CLEAN` — every SKILL.md returned ACCEPT.
- `PLUGIN_DRIFT` — at least one SKILL.md returned ACCEPT_WITH_MINOR or REJECT_*.
- `VALIDATION_INCONCLUSIVE` — the layer could not complete.
- `BLOCKED_NO_TARGET` — no plugin resolved from arg or cwd.

Layers 2–4 (behavioral, E2E, evolutionary) land in subsequent plans.

## Principles

- Contract-first, library-last.
- Imperative voice, ALL-CAPS verdicts, zero hedges.
- `.md` + `.js` + `.sh` + `.json` only.
- Structural distrust — no agent both produces and approves its own work.
- Self-contained — no plugin dependencies.

## Canonical sources for the hedge-word denylist

The hedge-word denylist at `skills/skill-voice-review/references/hedge-words-denylist.json` draws from six canonical sources. Every entry is attested in at least one; most appear in two or more.

| Source | Role | URL |
|---|---|---|
| Demir (2018), *Hedging and academic writing* — JLLS 14(4) | Consolidated Hyland taxonomy; Appendix A is the canonical hedge word list | http://www.jlls.org/index.php/jlls/article/view/812 |
| Hyland (1998), *Hedging in Scientific Research Articles* — John Benjamins | Original academic reference | https://benjamins.com/catalog/pbns.54 |
| Farkas et al. (2010), CoNLL-2010 Shared Task / BioScope | NLP canonical hedge-cue corpus | https://aclanthology.org/W10-3001/ |
| Wikipedia MoS: *Words to watch* | Community weasel-word list (CC BY-SA) | https://en.wikipedia.org/wiki/Wikipedia:Manual_of_Style/Words_to_watch |
| Google developer docs style guide: *prescriptive documentation* | Industry directive-voice hedges | https://developers.google.com/style/prescriptive-documentation |
| Anthropic: *Prompt engineering overview* | Imperative-voice guidance for Claude instructions | https://docs.anthropic.com/en/docs/build-with-claude/prompt-engineering/overview |

Raw downloads and the extracted Demir Appendix A are checked in under `docs/hedge-research/` for provenance. To re-extract Demir's consolidated list (uses `curl -f` so HTTP errors exit non-zero instead of silently writing an error page):

```bash
set -euo pipefail
curl -fsSL -o docs/hedge-research/demir-2018.pdf \
  http://www.jlls.org/index.php/jlls/article/download/812/422
file docs/hedge-research/demir-2018.pdf | grep -q '^.*: PDF document'
pdftotext -layout docs/hedge-research/demir-2018.pdf docs/hedge-research/demir-2018.txt
sed -n '861,930p' docs/hedge-research/demir-2018.txt   # Appendix A
```

## Canonical sources for the library-names denylist

The library-names denylist at `skills/skill-voice-review/references/library-names-denylist.json` is seeded from programmatic JSON feeds (not hand-curation alone) so the provenance is reproducible. Every entry is a distinct proper-noun library name with low false-positive risk in English prose.

| Source | Role | URL |
|---|---|---|
| hugovk — *Top PyPI packages* (monthly) | Canonical JSON feed for Python popularity; seeds numpy / pandas / pydantic / httpx / etc. | https://hugovk.dev/top-pypi-packages/top-pypi-packages.min.json |
| tristan-f-r/npm-rank | Canonical JSON feed for npm popularity; seeds axios / lodash / rxjs / eslint / prettier | https://github.com/tristan-f-r/npm-rank/releases/download/latest/raw.json |
| crates.io API | Rust popularity (CC0); reserved for future expansion | https://crates.io/api/v1/crates?sort=downloads&per_page=100 |
| libraries.io open dataset | Multi-ecosystem SourceRank (CC-BY-SA) | https://libraries.io/data |
| anthropics/skills (claude-api, skill-creator) | Calibrates which library names leak into AI-instruction prose | https://github.com/anthropics/skills |
| PatrickJS/awesome-cursorrules | Corpus of AI-coding-assistant instructions; informs frontend/state adds (redux, zustand, shadcn, tailwindcss) | https://github.com/PatrickJS/awesome-cursorrules |

Raw JSON downloads are checked in under `docs/library-research/` for provenance. To re-extract top 200 names per ecosystem:

```bash
set -euo pipefail
mkdir -p docs/library-research
curl -fsSL -o docs/library-research/top-pypi-packages.min.json \
  https://hugovk.dev/top-pypi-packages/top-pypi-packages.min.json
curl -fsSL -L -o docs/library-research/npm-rank.json \
  https://github.com/tristan-f-r/npm-rank/releases/download/latest/raw.json

jq -r '.rows[:200][].project' docs/library-research/top-pypi-packages.min.json > pypi-top200.txt
jq -r '.[:200][].name'       docs/library-research/npm-rank.json          > npm-top200.txt
```

Before merging new names into `entries[]`, filter out English-word collisions (`requests`, `click`, `fetch`, `bootstrap`, `six`, `wheel`, `build`, `guidance`, `anthropic`, `openai`) — the detector is case-insensitive with word boundaries, so any library name that doubles as a common English word will produce false positives.

## Benchmark artifacts

Every skill authored through skill-cheat carries its own behavioral benchmark inputs in `skills/<name>/evals/`:

- `eval-set-skeleton.json` — positive + adversarial trigger cases, seeded by `/skill-scope` from declared triggers via `scripts/emit-eval-skeleton.sh`.
- `assertion-skeleton.json` — one behavioral assertion per HARD-GATE + Gate Function, seeded by `/skill-design` via `scripts/emit-assertion-skeleton.sh`.

The skeletons are JSON-seeded contracts. The skill author fills in realistic queries and refines assertions before `/skill-voice-review` dispatches them against git-isolated baseline/candidate worktrees (Plan 5).

Schemas live in:

- `skills/skill-scope/references/scope-schema.md`
- `skills/skill-design/references/design-schema.md`
- `skills/skill-voice-review/references/benchmark-plan-schema.md`
- `skills/skill-voice-review/references/adversarial-eval-patterns.md`

## Benchmark engine

Plan 5 ships the runtime that consumes the eval and assertion skeletons emitted by `/skill-scope` and `/skill-design` and produces enriched per-skill benchmark results.

Components in `skills/skill-voice-review/`:

- `scripts/git-worktree-setup.sh` — materializes baseline + candidate worktrees at `<root>/<run-id>/{baseline,candidate}/`.
- `scripts/benchmark-plan-init.sh` — writes `benchmark-plan.json` + `benchmark-plan.md` (with Integrity Block) + SHA-256 sidecar from scope.json + eval-set + assertion-skeleton + refs.
- `scripts/benchmark-integrity-hash.sh` — companion hasher for benchmark-plan.md's integrity block.
- `scripts/run-eval.js` / `run-eval.sh` — spawns `claude -p --include-partial-messages`, watches the JSONL stream for skill activation (`content_block_start` with matching tool_use name), emits `{triggered, durationMs, totalTokens, streamEvents}`. Mock-stream mode (`--mock-stream-file`) unblocks CI.
- `scripts/aggregate-benchmark.js` — folds N run-eval outputs into pass-rate + mean/stddev tokens + mean/stddev duration per ref, plus delta.
- `agents/grader.md` / `comparator.md` / `analyzer.md` — subagent prompts (ported from [anthropics/skills](https://github.com/anthropics/skills) under Apache 2.0; see `/NOTICE`).

Plan 6 wires `/skill-voice-review` phase 3 to this engine and adds the Node dashboard UI (mirrors model_trainer/report's `dashboard/` layout).

# skill-cheat

> A Claude Code plugin that authors skills the way I think they should be authored. Five gated stages. Twenty-one lint rules. No vibes.

**Status:** 0.1.0 · MIT · standalone, no plugin dependencies.

Writing a SKILL.md is not the same as writing a markdown file. The markdown part is easy. The hard part is keeping a behaviour contract disciplined across twenty skills, across two months, across the temptation to soften an imperative because the model is reading it and feels like a person.

That is what this handles. It treats every skill as a typed artifact. It lints the artifact against a canonical anatomy. It freezes the design before the body gets written. It refuses to let the same agent both produce and approve its own work.

If that sounds like the discipline you want, keep reading. If it sounds slow, it is, and you should not use this.

---

## Quickstart

```
/plugin marketplace add /path/to/skill-cheat
/plugin install skill-cheat@skill-cheat-local
```

Open a session. Say "I want to build a skill for X" — or type `/skill-scope` to start explicitly. The `UserPromptSubmit` hook detects skill-authoring intent and reminds Claude to run the pipeline.

Host tools you need on `PATH`: `bash`, `openssl`, `node`, `graphviz` (`dot`), `jq`.

---

## The five stages

```mermaid
flowchart LR
    A[/skill-scope/] --> B[/skill-design/]
    B --> C[/skill-author/]
    C --> D[/skill-voice-review/]
    D -->|REJECT| C
    D -->|ACCEPT| E[/skill-scaffold/]

    classDef stage fill:#1f1a14,stroke:#c98c3c,color:#f5ecd8;
    class A,B,C,D,E stage;
```

| Command | The gate | Your job |
|---|---|---|
| `/skill-scope` | Name, triggers, verdicts, Anti-Pattern locked. Emits `scope.md`, `scope.json`, and an eval-set skeleton seeded from declared triggers. | Confirm the scope is right. |
| `/skill-design` | HARD-GATEs, Core Principle, flow diagram, checklist, assertion skeleton. Hashed into an Integrity Block with a SHA-256 sidecar. | Approve the design. |
| `/skill-author` | Body filled in. Integrity Block re-verified — edit a design field after lock-in and the SHA-256 sidecar breaks. The pipeline halts. That is the point. | Watch. Do not edit the design backdoor. |
| `/skill-voice-review` | Mechanical lint over twenty-one rules, then a reviewer subagent that did not see the author's work. REJECT or ACCEPT. | Apply the fixes, or argue the rule. |
| `/skill-scaffold` | Emits the plugin tree at the target path. The `evals/` directory travels with the skill. | Wire it into your plugin. |

You approve at three gates: the scope, the design, and the voice-review verdict. Everything in between is the pipeline doing its job.

---

## Validation: `/skill-stress-test`

Point it at any Claude Code plugin and it will run the voice-review lint engine over every `SKILL.md` in the target.

```bash
# explicit target
node skills/skill-stress-test/scripts/qa-orchestrator.js --plugin /abs/path/to/plugin

# cwd auto-detect
cd /abs/path/to/plugin && node /abs/path/to/skill-cheat/skills/skill-stress-test/scripts/qa-orchestrator.js
```

Output lands at `<target>/.skill-cheat-qa/runs/<run-id>/report.json` and a single `VERDICT: <token>` line on stdout. Tokens:

- `VALIDATION_CLEAN` — every SKILL.md returned ACCEPT.
- `PLUGIN_DRIFT` — at least one SKILL.md returned ACCEPT_WITH_MINOR or REJECT_*.
- `VALIDATION_INCONCLUSIVE` — the layer could not complete (no skills, depth violation, symlink refusal).
- `BLOCKED_NO_TARGET` — no plugin resolved from arg or cwd.

The static layer ships now. The behavioural, end-to-end, and evolutionary layers land in subsequent plans.

A V1 corpus run on 14 May 2026 against 47 real plugins from `~/.claude/plugins/cache/` and a wider corpus returned 34 PLUGIN_DRIFT, 13 INCONCLUSIVE (no-skills plugins routed correctly), 0 false CLEAN, 0 crashes. The lint engine's signal-to-noise on foreign plugins is now bounded by SKILL-shape rules only.

---

## Why this exists

I was writing my fifth Claude Code skill in a week when I noticed I kept typing the same scaffolding at the top of every one. The same all-caps verdicts. The same anti-hedge reminders. The same HARD-GATE blocks. By the time I had eight skills, I had a tacit anatomy I was applying by reflex but never as a contract.

That is the gap this fills. A SKILL.md is a behaviour contract — the model is the executor, and a sloppy contract gives you sloppy behaviour. The hard part is not the prose. The hard part is keeping the prose disciplined across twenty skills, two months, and the temptation to soften an imperative because the language model is reading it and feels like a person.

skill-cheat is the version of myself that does not get tired. It lints the artifact against twenty-one rules grounded in published practice. It freezes the design before the body gets written. It refuses to let the same agent both produce and approve its own work. The point is not to replace your taste. The point is to make your taste show up consistently when you are not paying attention.

---

## How it actually behaves

### The skill is a contract. Treat it like one.

Frontmatter is validated. Sections are typed. Voice is mechanical. The lint engine carries twenty-one rules in `skills/skill-voice-review/references/lint-rules.json`, dispatched through a seven-way detector switch (`grep-denylist`, `hard-gate-span`, `yaml-frontmatter`, `bash-syntax`, `regex-line`, `find-extensions`, `digraph-fence`). Every rule is declarative. New rules are JSON, not code.

### Lint before you eval.

A static, deterministic gate runs before any behavioural test. Lint failures are cheap, repeatable, and bound by a known rule set. Behavioural failures are stochastic, expensive, and only meaningful once the artifact under test is shape-correct. This is shift-left applied to LLM artifacts. Lint first. Eval second.

### Two kinds of rule. Know which.

Rules carry a `kind` axis. `skill-shape` rules apply universally — every Claude Code skill, anywhere, should hold these. `plugin-policy` rules are skill-cheat's local opinion: file-extension allowlist, directory layout. When the stress-test harness runs against a foreign plugin, the `--mode cross-plugin` flag filters the policy rules out. That way your signal on someone else's plugin is bounded by what is genuinely portable.

The split is borrowed straight from ESLint's `eslint:recommended` plus project overrides. It is not novel. It is, as of May 2026, the only `skill-shape` vs `plugin-policy` taxonomy in a public Claude Code skill linter.

### The design is tamper-evident.

`/skill-design` writes a SHA-256 sidecar over the locked design fields. `/skill-author` re-verifies the hash before it lets the body proceed. Edit `scope.json` or `design.json` after lock-in, and the next stage halts. The point is not security. The point is that authoring drift across stages costs you a re-derivation.

### No agent grades its own work.

`/skill-author` writes. `/skill-voice-review` judges. They are separate subagents with separate prompts. The reviewer does not see the author's reasoning, only the artifact. The same rule applies to the stress harness: a third reviewer judges the lint output, not the lint engine's own claims.

This separation is the LLM analogue of branch protection. It is fifty years old in code review (Fagan inspections, 1976). It is overdue in prompt authoring.

---

## How it compares

Honest table. As of May 2026.

| | Anthropic `skill-creator` | `superpowers:writing-skills` | `claudelint` | `SkillCheck` | `skill-cheat` |
|---|---|---|---|---|---|
| Schema-driven static lint | no | no | yes | yes | yes |
| Imperative-voice / hedge denylist | partial | no | no | no | yes |
| 13-section canonical anatomy | no | no | no | no | yes |
| `skill-shape` vs `plugin-policy` split | — | — | no | no | yes |
| Cross-plugin worst-wins harness | — | — | no | partial | yes |
| LLM-as-judge eval loop | yes | partial | no | no | Plan 5+ |
| Author / reviewer separation | partial | yes | no | no | yes |

The orthogonal axis is opinion. `skill-creator` meets you wherever you are. `superpowers:writing-skills` teaches a discipline through narrative. `claudelint` and `SkillCheck` apply broadly safe checks. skill-cheat takes a specific position on how a skill should read and enforces it mechanically. If you disagree with the position, fork the rules. The rule shape is portable.

---

## On HARD-GATE syntactic enforcement

Anthropic's published prompt-engineering guidance treats `MUST` / `NEVER` / `ALWAYS` blocks as a yellow flag. Their reasoning: readers pattern-match nag text and tune it out, so the imperative loses force. Rule-plus-reasoning prose ("use constructor injection — field injection breaks testability because...") is preferred.

I think that is correct for human readers and wrong for LLM readers.

A human holds context across paragraphs and decides which line is binding. An LLM following a multi-screen skill needs a syntactic anchor — a token shape that says "this is the non-negotiable line, ignore the surrounding prose if it contradicts." The HARD-GATE block is that anchor. It is the LLM analogue of an `assert` statement: ugly, repetitive, deliberately interruptive, and exactly what you want when correctness depends on the assertion firing.

If your skill is going to be read mostly by humans, fork the rule. If it is going to be executed by an LLM under load, the HARD-GATE earns its place. The argument is open. I will defend it.

---

## When not to use this

Skip this if any of the following are true.

- **You want a friendly authoring flow.** The pipeline is gauntlet-shaped on purpose. There is no "vibe with me" path. Use `skill-creator`.
- **You disagree with the 13-section anatomy.** It is a position, not a discovery. You will fight the linter forever.
- **Your skills are read mostly by humans.** The voice rules optimise for LLM-readability. The all-caps fatigue is real.
- **You need behavioural eval today.** Static layer ships now. Behavioural, E2E, and evolutionary layers land in subsequent plans.
- **You bounce off opinionated tools.** This one is not going to flatter your skill. It will tell you it is incoherent and where.

---

## Repository layout

```
.
├── .claude-plugin/        plugin manifest + local marketplace
├── hooks/                 SessionStart bootstrap + UserPromptSubmit intent detector
├── skills/
│   ├── using-skill-cheat/   session-start introduction (auto-loaded)
│   ├── skill-scope/         lock name, triggers, verdicts
│   ├── skill-design/        HARD-GATEs, flow, Integrity Block
│   ├── skill-author/        body, verify Integrity unchanged
│   ├── skill-voice-review/  lint engine + reviewer subagent
│   ├── skill-scaffold/      emit the plugin tree
│   └── skill-stress-test/   cross-plugin QA harness
├── tests/                 44 shell tests; every hook + script covered
├── docs/                  field manual + flow atlas + internal plans
├── CLAUDE.md              project instructions for contributors
└── README.md
```

---

## The principles I will not bend on

1. **Contract-first, library-last.** A SKILL.md is a behaviour contract. Schemas, denylists, and integrity hashes come before tooling.
2. **Imperative voice. ALL-CAPS verdicts. Zero hedges.** "Could", "might", "would", "should", "may" — denylisted in the body, allowed in references.
3. **`.md` + `.js` + `.sh` + `.json` only.** Generated artifacts (diagrams, PDFs) live in `docs/`. The runtime carries no other formats.
4. **No agent both produces and approves its own work.** Author and reviewer are separate prompts.
5. **The design is tamper-evident.** Edit a locked design field and the next stage halts.
6. **Lint before eval.** Static deterministic checks run before any behavioural test. Always.
7. **Crash loud.** Silent error swallowing is a defect. Wrong-but-plausible output is worse than no output.

---

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

The library-names denylist at `skills/skill-voice-review/references/library-names-denylist.json` is seeded from programmatic JSON feeds so the provenance is reproducible. Every entry is a distinct proper-noun library name with low false-positive risk in English prose.

| Source | Role | URL |
|---|---|---|
| hugovk — *Top PyPI packages* (monthly) | Canonical JSON feed for Python popularity | https://hugovk.dev/top-pypi-packages/top-pypi-packages.min.json |
| tristan-f-r/npm-rank | Canonical JSON feed for npm popularity | https://github.com/tristan-f-r/npm-rank/releases/download/latest/raw.json |
| crates.io API | Rust popularity (CC0); reserved for future expansion | https://crates.io/api/v1/crates?sort=downloads&per_page=100 |
| libraries.io open dataset | Multi-ecosystem SourceRank (CC-BY-SA) | https://libraries.io/data |
| anthropics/skills | Calibrates which library names leak into AI-instruction prose | https://github.com/anthropics/skills |
| PatrickJS/awesome-cursorrules | Corpus of AI-coding-assistant instructions; informs frontend/state adds | https://github.com/PatrickJS/awesome-cursorrules |

Raw JSON downloads are checked in under `docs/library-research/` for provenance. To re-extract the top 200 names per ecosystem:

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

---

## What's coming

Plan 5 ships the benchmark runtime that consumes the eval-set and assertion skeletons emitted by `/skill-scope` and `/skill-design` and produces enriched per-skill behavioural results.

Components in `skills/skill-voice-review/`:

- `scripts/git-worktree-setup.sh` — materialises baseline + candidate worktrees at `<root>/<run-id>/{baseline,candidate}/`.
- `scripts/benchmark-plan-init.sh` — writes `benchmark-plan.json` + `benchmark-plan.md` (with Integrity Block) + SHA-256 sidecar.
- `scripts/run-eval.js` / `run-eval.sh` — spawns `claude -p --include-partial-messages`, watches the JSONL stream for skill activation, emits `{triggered, durationMs, totalTokens, streamEvents}`.
- `scripts/aggregate-benchmark.js` — folds N run-eval outputs into pass-rate + mean/stddev tokens + mean/stddev duration per ref.
- `agents/grader.md` / `comparator.md` / `analyzer.md` — subagent prompts ported from [anthropics/skills](https://github.com/anthropics/skills) under Apache 2.0 (see `NOTICE`).

Plan 6 wires `/skill-voice-review` phase 3 to this engine and ships the dashboard.

---

## Inspirations

- **Superpowers.** The originator of the gate-driven, review-separated, TDD-flavoured Claude-skill genre. The two-stage author / reviewer separation, the `writing-plans` discipline, and the `subagent-driven-development` pattern all come from there.
- **Spectral (Stoplight).** The reference architecture for typed-rule schema engines targeting structured-but-prose-shaped artifacts. The `kind` axis is borrowed straight from ESLint's `eslint:recommended` plus project overrides pattern.
- **CoNLL-2010 Shared Task on hedge cue detection.** The hedge-word denylist sits on Farkas et al.'s BioScope corpus and Hyland's metadiscourse work. Not vibes. Citations.
- **`anthropics/skills`.** Three grader / comparator / analyzer subagent prompts are ported under Apache 2.0. See `NOTICE`.
- **Fagan inspections (1976).** The author-cannot-self-review rule predates code review tooling by thirty years. It works because separation is the constraint, not the format.

---

## Contributing

Open invitation. If you have a better way of handling a stage, a lint rule the engine is missing, or a detector pattern that improves on what is here, I want to see it. See [CONTRIBUTING.md](CONTRIBUTING.md) for setup, the conventions skills follow, and the rule shape in `lint-rules.json`.

A standing offer: if you think a lint rule is wrong, open an issue with the counter-argument. The rules are versioned. They are also intentionally opinionated. Forks are fine.

---

## Licence

MIT. See [LICENSE](LICENSE) for the full text. Use it. Fork it. Build on it. Attribution welcome, not required.

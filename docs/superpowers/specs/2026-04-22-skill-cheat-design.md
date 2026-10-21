# skill-cheat — design spec

**Date:** 2026-04-22
**Status:** Design approved; awaiting user review before implementation plan.
**Prior art studied:** `model_trainer` (Personal_AI Projects/), `channelle_test` (Personal_AI Projects/), `runbug` (consulting/). `skill-cheat` ports methodology from these; it has zero runtime dependencies on any of them.

## 1. Purpose

`skill-cheat` is a Claude Code plugin that scaffolds other Claude Code skills in the imperative, gate-driven, contract-first style. It runs a 5-stage pipeline (`/skill-scope → /skill-design → /skill-author → /skill-voice-review → /skill-scaffold`) that forces the skill author (Claude, on behalf of the human user) through the same structural-distrust discipline demonstrated by `model_trainer`, without depending on `model_trainer` or any other plugin.

## 2. Core design rules (apply everywhere)

- **Contract-first, library-last.** Skills specify the shape of work (preconditions, verdicts, invariants), never which tools to use. Claude picks tools at target-project time.
- **Self-contained (plugin-level).** Zero cross-plugin dependencies. If a pattern is needed, it is written in `skill-cheat` in `skill-cheat`'s own voice, not referenced from another plugin.
- **Host-tool dependencies are explicit.** The lint layer uses `bash`, `openssl` (SHA-256), `node` (JSON/YAML parsing), and `dot` from graphviz (digraph validation). The README lists these as install prerequisites. No Python, no npm package manager dependency, no bundled runtimes.
- **File type allowlist.** `.md` (skills, references, prompts, docs), `.js` (lint helpers, authored-plugin references when a JS runtime constraint exists), `.sh` (hooks, scripts, tests), `.json` (manifests, lint rule manifests, lint reports, denylists). Nothing else.
- **Structural distrust.** No agent both produces and approves its own work. The voice-reviewer subagent is dispatched with a crafted context that excludes the authoring session history.
- **Integrity Block with SHA-256 sidecar.** Stage 2 locks the immutable decisions in a byte-exact delimited region. Stages 3, 4, 5 re-verify the hash before acting.
- **Imperative voice, ALL-CAPS verdicts, zero hedges.** Enforced mechanically by the lint layer.

### Canonical section order (referenced by LINT-010)

Every authored SKILL.md must present sections in this exact order:

1. YAML frontmatter (`name`, `description`)
2. H1 title
3. `<HARD-GATE>` blocks (one or more, stacked)
4. Anti-Pattern
5. Core Principle
6. Process Flow (dot digraph)
7. Checklist
8. Step Details
9. Gate Functions
10. Rationalization Table
11. Red Flags
12. Key Principles
13. Bottom Line (with executable fenced block)

Sections may be absent only if the skill declares (in its own `lint.json` overrides) a rule disabling that section's presence — never silently.

## 3. Plugin layout

```
skill_cheat/
├── .claude-plugin/
│   ├── plugin.json                                    (name, version, keywords)
│   └── marketplace.json                               (local marketplace descriptor)
├── CLAUDE.md                                          (contributor notes)
├── README.md                                          (end-user install + usage)
├── hooks/
│   ├── hooks.json                                     (SessionStart + UserPromptSubmit)
│   ├── session-start                                  (bash — injects using-skill-cheat)
│   ├── user-prompt-submit                             (bash — keyword self-trigger)
│   └── lib/
│       ├── emit-context.sh                            (JSON-safe context emitter)
│       └── detect-skill-intent.sh                     (keyword match helper)
├── config.sh                                          (trigger keywords; overridable)
├── agents/
│   └── voice-reviewer.md                              (written from scratch)
├── commands/
│   ├── skill-scope.md
│   ├── skill-design.md
│   ├── skill-author.md
│   ├── skill-voice-review.md
│   └── skill-scaffold.md
├── skills/
│   ├── using-skill-cheat/SKILL.md                     (bootstrap)
│   ├── skill-scope/
│   │   ├── SKILL.md
│   │   └── references/
│   │       └── trigger-vocabulary.md
│   ├── skill-design/
│   │   ├── SKILL.md
│   │   ├── references/
│   │   │   ├── integrity-block.md
│   │   │   ├── hard-gate-patterns.md
│   │   │   └── dot-digraph-template.md
│   │   └── scripts/
│   │       └── integrity-hash.sh
│   ├── skill-author/
│   │   ├── SKILL.md
│   │   └── references/
│   │       ├── canonical-anatomy.md
│   │       ├── rationalization-table-patterns.md
│   │       └── bottom-line-script-examples.md
│   ├── skill-voice-review/
│   │   ├── SKILL.md
│   │   ├── references/
│   │   │   ├── lint-rules.json
│   │   │   ├── lint-schema.json
│   │   │   ├── hedge-words-denylist.json
│   │   │   ├── library-names-denylist.json
│   │   │   └── canonical-anatomy.md
│   │   ├── prompts/
│   │   │   └── voice-reviewer.md
│   │   └── scripts/
│   │       ├── lint.sh
│   │       └── lint.js
│   ├── receiving-voice-review/SKILL.md
│   └── skill-scaffold/
│       ├── SKILL.md
│       └── references/
│           ├── plugin-skeleton.md
│           └── hook-templates.md
└── tests/
    ├── run-tests.sh
    ├── hooks/
    │   ├── test-session-start.sh
    │   └── test-user-prompt-submit.sh
    ├── lint/
    │   ├── primitives/                                (per-detector unit tests)
    │   └── fixtures/
    │       ├── good/                                  (skills that must pass)
    │       └── bad/                                   (skills that must fail specific rule ids)
    └── pipeline/
        ├── input/
        ├── expected/
        └── run.sh
```

**Intentional duplication rule:** applies only within `skill-cheat/` if any reference file is ever duplicated between two skills. Never across plugins.

## 4. The 5-stage pipeline

Working directory for in-flight skills: `docs/skill-cheat/skills-in-progress/<skill-name>/` in the target project's root. Final scaffold output lands at a user-specified path (asked at stage 1).

### Stage 1 — `/skill-scope`

- **Inputs:** natural-language description from user.
- **Gates:**
  - Do NOT proceed without a named concept and a declared target project path.
  - Do NOT proceed without a named Anti-Pattern phrase — the exact rationalization that would cause Claude to skip this skill.
- **Output:** `scope.md` with frontmatter (name, triggers, verdicts) + numbered refusals list.
- **Verdicts:** `SCOPE_LOCKED` / `SCOPE_INCOMPLETE: <gap>` / `BLOCKED_NEEDS_USER`.

### Stage 2 — `/skill-design`

- **Inputs:** `scope.md`.
- **Gates:**
  - Do NOT proceed without reading `scope.md` in this session.
  - Do NOT name libraries/frameworks in the HARD-GATE list.
  - Do NOT write the Integrity Block without all six fields present and ordered.
- **Process:** writes HARD-GATEs, Core Principle, dot digraph, Checklist, Gate Functions. Dispatches a design-reviewer subagent that FAILs on unreachable graph nodes, malformed Gate Functions, library names, over-long HARD-GATEs.
- **Output:** `design.md` with delimited Integrity Block + `design.md.sha256` sidecar.
- **Verdicts:** `DESIGN_LOCKED` / `DESIGN_REJECTED: <findings>` / `BLOCKED_REVIEWER` (3 consecutive reviewer failures).

### Stage 3 — `/skill-author`

- **Inputs:** `design.md` + valid sidecar.
- **Gates:**
  - Do NOT proceed without re-verifying the Integrity Block hash. Drift → `BLOCKED_TAMPER`.
  - Do NOT edit anything inside `<!-- integrity-block:start/end -->`.
  - Do NOT include library/framework names in SKILL.md.
- **Process:** fills Anti-Pattern, Step Details, Rationalization Table, Red Flags, Key Principles, Bottom Line script. Syntax-checks the Bottom Line script with `bash -n`.
- **Output:** draft `SKILL.md` alongside `design.md`.
- **Verdicts:** `AUTHOR_DONE` / `AUTHOR_INCOMPLETE: <gap>` / `BLOCKED_TAMPER`.

### Stage 4 — `/skill-voice-review`

Two layers.

**Layer A — mechanical lint (`scripts/lint.sh` + `lint.js`).** Reads the skill's own `lint.json` if present (see §5) and resolves any `extends` to the baseline `references/lint-rules.json`. Runs all rules. Emits a JSON report.

**Layer B — voice-reviewer subagent.** Dispatched only after lint passes. The agent definition lives at `agents/voice-reviewer.md` (persona, rubric loading instructions, output format). The prompt template fed to it at dispatch time lives at `skills/skill-voice-review/prompts/voice-reviewer.md` with placeholders (`{SKILL_PATH}`, `{DESIGN_SHA}`, `{LINT_REPORT_PATH}`). Fresh context; never sees authoring history. Returns severity-tiered findings.

- **Gates:**
  - Do NOT return ACCEPT without running `scripts/lint.sh` in the current session.
  - Do NOT return ACCEPT without dispatching the voice-reviewer subagent.
- **Verdicts:** `ACCEPT` / `REJECT_CRITICAL: <findings>` / `REJECT_IMPORTANT: <findings>` / `ACCEPT_WITH_MINOR: <findings>` / `INCONCLUSIVE: <reason>`.
- **Loop cap:** 3 consecutive rejects → `BLOCKED_VOICE`.

### Stage 5 — `/skill-scaffold`

- **Inputs:** `ACCEPT`-ed or `ACCEPT_WITH_MINOR` SKILL.md + scope's declared target project path.
- **Gates:**
  - Do NOT write to target if voice-review did not return ACCEPT or ACCEPT_WITH_MINOR.
  - Do NOT write any file with an extension outside `{.md, .js, .sh, .json}`.
  - Do NOT overwrite existing `plugin.json` without explicit confirmation.
- **Process:** branches on scope's "new plugin or add to existing". New plugin → full canonical tree (plugin.json, CLAUDE.md, README.md, hooks, bootstrap SKILL.md, the authored skill, commands, tests/run-tests.sh). Existing plugin → the authored skill only + append to bootstrap's Available Skills table.
- **Post-write:** runs the authored plugin's own Bottom Line script.
- **Verdicts:** `SCAFFOLD_COMPLETE: <paths-written>` / `SCAFFOLD_INCOMPLETE: <gap>` / `BLOCKED_OVERWRITE`.

### Stage-exit protocol

Every stage prints at the end:

```
STAGE: <name>
VERDICT: <TOKEN>
ARTIFACTS:
  - <path>
  - <path>
NEXT: /<next-slash-command>   (omitted on BLOCKED or terminal stages)
```

No automatic chaining. The user (or Claude on the user's behalf) runs the next command explicitly. Structural checkpoints are honored.

## 5. Voice-review mechanics (the structural-distrust core)

### Rule manifest — `references/lint-rules.json`

The 15 baseline rules as declarative data. Each rule has `id`, `description`, `severity`, `detector`. Detectors are the primitives implemented in `lint.sh` / `lint.js`:

| type | backed by | purpose |
|---|---|---|
| `find-extensions` | shell | allowlist over `find` output |
| `grep-denylist` | shell | word-boundary grep against denylist file |
| `grep-required` | shell | pattern must be present |
| `regex-line` | shell | per-line regex match/antimatch |
| `yaml-frontmatter` | node | YAML field presence + shape |
| `dot-parse` | shell → graphviz | `dot -Tcanon`, check exit |
| `bash-syntax` | shell | `bash -n` on fenced block |
| `section-order` | node | header walker vs canonical sequence |
| `cross-reference` | node | checklist numbers ↔ step details headings |

### The 15 baseline rules (all CRITICAL)

| id | description |
|---|---|
| LINT-001 | Plugin file extensions only `.md`, `.js`, `.sh`, `.json`. |
| LINT-002 | Every HARD-GATE sentence opens with an imperative (`Do NOT`, `Never`, `STOP`). |
| LINT-003 | Zero hedge words in SKILL.md body. |
| LINT-004 | Verdict tokens in frontmatter description are ALL-CAPS single words. |
| LINT-005 | Zero library/framework names in SKILL.md body (outside `references/`). |
| LINT-006 | HARD-GATE contents have no `because`/`since`/`in order to` and no sentence exceeds 2. |
| LINT-007 | Gate Functions bullets match `^- BEFORE .+: ".+\?"$`. |
| LINT-008 | Red Flags bullets are quoted fragments with no em-dash explanation tail. |
| LINT-009 | Bottom Line contains a fenced `bash`/`sh` block that passes `bash -n`. |
| LINT-010 | Section order matches canonical sequence. |
| LINT-011 | Process Flow block parses with `dot -Tcanon`. |
| LINT-012 | Frontmatter has `name` + `description`; description names ≥1 trigger and ≥1 verdict. |
| LINT-013 | Checklist numbers match Step Details headings 1:1. |
| LINT-014 | No third-person self-reference (`the skill`, `this skill`, `skill deviation`). |
| LINT-015 | Anti-Pattern section contains a quoted phrase in its first sentence. |
| LINT-016 | HARD-GATE blocks exist only inside the Integrity Block or the rendered SKILL.md, never in the design.md's editable region. |

### Denylists (data-driven)

`hedge-words-denylist.json` and `library-names-denylist.json` are JSON arrays. Editing the denylist changes lint behavior without touching rule code.

### Per-skill overrides

Any skill may ship a `lint.json` alongside its SKILL.md:

```json
{
  "extends": "skill-cheat:baseline",
  "rules": [
    { "id": "ML-IB-001", "severity": "CRITICAL", "detector": { ... } }
  ]
}
```

Resolution: skill-local `lint.json` overrides baseline rules by `id`. New ids append. `disable: ["LINT-014"]` removes a baseline rule (use sparingly; each disable must have a comment explaining why).

### JSON report shape

```json
{
  "skill": "skills/hypothesize/SKILL.md",
  "designSha": "a7981ec...",
  "runId": "2026-04-22T14:32:10Z",
  "summary": { "critical": 0, "important": 0, "minor": 1, "passed": 14 },
  "findings": [
    { "ruleId": "LINT-008", "severity": "MINOR", "location": {"line": 142, "column": 3},
      "message": "Red Flag bullet uses em-dash explanation",
      "excerpt": "- 'Accuracy' without checking class balance — explanatory tail" }
  ],
  "verdict": "ACCEPT_WITH_MINOR"
}
```

### Voice-reviewer prompt template

Lives at `skills/skill-voice-review/prompts/voice-reviewer.md`. Placeholders: `{SKILL_PATH}`, `{DESIGN_SHA}`, `{LINT_REPORT_PATH}`. Instructs the reviewer to catch what lint cannot (wrong-question Gate Functions, soft `Reality` rebuttals, duplicate Red Flags, contract/implementation confusion in the Core Principle, checklist ordering mistakes). Reviewer returns verdict + findings in a fixed format; does not rewrite.

## 6. Integrity Block mechanics

### Delimiters

Exact strings, each on their own line, no leading/trailing whitespace:

- Start: `<!-- integrity-block:start -->`
- End: `<!-- integrity-block:end -->`

### Immutable set (the six fields, in order)

1. Skill Name
2. Triggers (slash command + keywords)
3. Verdict Vocabulary
4. HARD-GATEs (one per bullet)
5. Core Principle (one sentence)
6. Gate Functions (one per bullet, `BEFORE X: "Y?"` form)

Nothing else lives between the markers.

### Hashing (`scripts/integrity-hash.sh`)

Extract bytes strictly between the two marker lines (exclusive), pipe to `openssl dgst -sha256`, write sidecar at `<design-path>.sha256` with format `<lowercase hex digest>  <basename>`.

### Verification contract

Every stage 3/4/5 entry calls `verify_integrity(design_path)`:

```
if sidecar missing           → BLOCKED_TAMPER: sidecar absent
if start marker missing      → BLOCKED_TAMPER: start marker absent
if end marker missing        → BLOCKED_TAMPER: end marker absent
if either marker duplicated  → BLOCKED_TAMPER: marker not unique
computed = sha256(bytes between markers)
recorded = read sidecar
if computed != recorded      → BLOCKED_TAMPER: hash drift
return OK
```

### Tamper rules (anti-gaming)

- Re-hash after in-block edit: caught by the voice-reviewer comparing block contents against `scope.md`'s declared triggers/verdicts.
- Moving HARD-GATEs outside the block: caught by LINT-016.

### Rendered SKILL.md does not retain the markers

Stage 5 inlines the locked fields into canonical sections. `design.md` + sidecar persist in `docs/skill-cheat/skills-in-progress/` as the audit trail. Exception: if the scope flags "authored-skill-has-its-own-runtime-integrity-block" (for skills like model_trainer's `hypothesize`), the markers carry through.

## 7. Hooks & wiring

### `hooks/hooks.json`

Registers SessionStart and UserPromptSubmit. No PreToolUse.

### SessionStart behavior

`hooks/session-start` reads `skills/using-skill-cheat/SKILL.md` and injects it as session context via `lib/emit-context.sh`. Matches channelle's proven pattern (written from scratch, not referenced).

### UserPromptSubmit behavior

`hooks/user-prompt-submit` sources `config.sh` and `lib/detect-skill-intent.sh`. On keyword match, injects a reminder to invoke `/skill-scope`.

### `config.sh`

```bash
SKILL_CHEAT_TRIGGER_KEYWORDS=(
  "author a skill"
  "build a skill"
  "new skill"
  "scaffold a skill"
  "make a skill"
  "write a skill"
  "author a plugin"
  "new plugin"
  "skill-cheat"
)
SKILL_CHEAT_WORK_DIR="docs/skill-cheat/skills-in-progress"
```

Target-project override: drop `.skill-cheat.sh` at the project root; hook sources it last so locals win.

### Slash commands

One stub per stage under `commands/`, matching the canonical two-line form (description frontmatter + one-line body that names the skill to invoke).

## 8. Testing strategy (4 layers)

All run by `bash tests/run-tests.sh`. Non-zero exit blocks commit.

1. **Hook tests** — fixtures exercise trigger match, no-match, malformed input.
2. **Lint primitive tests** — one test per detector type against synthetic fixtures.
3. **Lint rule tests** — rule-coverage invariant: every rule id has ≥1 `bad/<rule-id>.md` that fails with that rule and nothing else; every `good/*.md` passes all rules. A rule without a catching fixture is a bug.
4. **Pipeline tests** — one end-to-end run from `/skill-scope` through `/skill-scaffold` on a checked-in fixture. Expected outputs compared structurally.

Snapshot state: `tests/lint/__snapshots__/` stores last-run JSON reports per fixture; drift caught in CI.

## 9. Bootstrap plan

- **Phase 0** — the seven bootstrap skills (`using-skill-cheat`, `skill-scope`, `skill-design`, `skill-author`, `skill-voice-review`, `receiving-voice-review`, `skill-scaffold`) are hand-authored following the canonical anatomy the plugin will enforce.
- **Phase 1** — once functional, every bootstrap SKILL.md must pass its own `/skill-voice-review`. Violations are bugs.
- **Phase 2** — the eighth skill (the first user-domain skill scaffolded after plugin completion) is added via the pipeline itself (dogfooding).

Hard boundary: the seven bootstrap skills are **frozen** after Phase 1. Changes to them require manual edits + manual lint re-run. They are not regenerated by the pipeline — circular regeneration makes plugins unreadable.

## 10. Open items (non-blocking)

- Whether `PreToolUse` is eventually worth adding to refuse Edit/Write inside an Integrity Block (deferred; add if drift is seen in practice).
- Whether `config.sh` trigger keywords should be tunable per-stage (v2 concern).
- `.skill-cheat.sh` project-local override format — currently bash source; could move to JSON if future non-shell hook tooling is added.

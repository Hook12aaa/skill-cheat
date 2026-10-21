# Contributing

Open invitation. If you have a lint rule the engine is missing, a detector pattern that improves on what is here, a better way of handling a stage, or a skill pattern that improves on the anatomy, I want to see it.

A standing offer: if you think a lint rule is wrong, open an issue with the counter-argument. The rules are versioned. They are also intentionally opinionated. Forks are fine.

## Before you open a PR

File an issue first if the change is non-trivial. The cost of writing one paragraph about what you want to change and why is low. The cost of building something I cannot accept is higher. For typo fixes, prose tightening, or a clearly localised improvement, skip the issue and go straight to the PR.

## Getting set up locally

```bash
git clone https://github.com/Hook12aaa/skill-cheat.git
cd skill-cheat
```

Install the plugin against your local clone:

```
/plugin marketplace add /absolute/path/to/skill-cheat
/plugin install skill-cheat@skill-cheat-local
```

If the path has spaces, symlink it first:

```bash
ln -s "/path/with spaces/skill-cheat" ~/skill-cheat-dev
/plugin marketplace add ~/skill-cheat-dev
```

Restart Claude Code. The `SessionStart` hook will load your local copy.

Host tools you need on `PATH`: `bash`, `openssl`, `node`, `graphviz` (`dot`), `jq`.

## How to test a change

The plugin has a test runner. Use it.

```bash
bash tests/run-tests.sh
```

44 tests at the time of writing. Cover hooks, lint primitives, the QA orchestrator, integrity blocks, schema self-consistency. A change that breaks the suite does not get merged.

If your change touches a hook, add a test under `tests/hooks/`. If it touches the lint engine, add a test under `tests/lint/` or `tests/qa-harness/`. The convention is one test file per behaviour, named `test-<what-it-asserts>.sh`. Every hook has a test. Every script has a test.

If your change is documentation, dogfood it: run the stress-test harness against the repo itself.

```bash
node skills/skill-stress-test/scripts/qa-orchestrator.js --plugin .
```

The verdict should be `VALIDATION_CLEAN` against the harness's own SKILL.md files. If it is not, fix the SKILL.md before merging.

## Notes that save review time

- **Plain voice.** No third-person self-reference. No hedges ("could", "might", "would", "should", "may", "perhaps"). The denylist is enforced — your skill will not pass voice-review if it does not pass it.
- **Imperatives over examples.** Prompts say what to do, not what the output should look like. Examples seed hallucination.
- **`.md` + `.js` + `.sh` + `.json` only at runtime.** Generated artefacts (diagrams, PDFs) live under `docs/`. Do not introduce other formats to the runtime tree.
- **No agent both produces and approves its own work.** If you add a new pipeline stage, author and reviewer are separate prompts.
- **Anything numerical goes through a script.** Catch yourself writing `if a > b` inline in a skill — extract it.
- **Shared references live at `skills/shared/`** if cross-skill. Update every consumer when you change a shared file.
- **No comments in `.sh` and `.js` outside directives and invariants.** Read `CLAUDE.md` before adding a comment. If it is rationale, dev history, or a maintainer note, delete it.

## Adding a new lint rule

This is the most common contribution path. A lint rule is a JSON object in `skills/skill-voice-review/references/lint-rules.json`.

The minimum:

```json
{
  "id": "LINT-022",
  "kind": "skill-shape",
  "description": "One-sentence description of what the rule enforces",
  "severity": "CRITICAL",
  "detector": {
    "type": "regex-line",
    "section": "skill-body",
    "must-match": "^pattern$"
  }
}
```

Field rules:

- **`id`** — next in the LINT-NNN sequence. Sequential, no gaps.
- **`kind`** — `skill-shape` (universal: applies to any Claude Code skill anywhere) or `plugin-policy` (skill-cheat's local opinion: file-extension allowlist, directory layout). Get this right. Cross-plugin runs filter `plugin-policy` out.
- **`severity`** — `CRITICAL`, `IMPORTANT`, or `MINOR`. CRITICAL fails the verdict. IMPORTANT raises to `ACCEPT_WITH_MINOR`. MINOR is reported but does not change the verdict.
- **`detector.type`** — one of `grep-denylist`, `hard-gate-span`, `yaml-frontmatter`, `bash-syntax`, `regex-line`, `find-extensions`, `digraph-fence`. If none of these fit, you are adding a new detector type — open an issue first.
- **`detector.scope`** — where the rule applies. `skill-md` (whole file), `skill-body` (after frontmatter), `skill-body-outside-references` (excludes fenced references), `plugin-root` (filesystem), or section-specific (`hard-gate-blocks`, `design-editable-region`).

After adding the rule:

1. Add a regression test under `tests/lint/` that asserts the rule fires on a counterexample and stays quiet on a passing case.
2. Run `bash tests/run-tests.sh`. The suite must still pass.
3. Run the stress-test harness against the repo itself. Existing skills should still verdict `VALIDATION_CLEAN`. If a rule you added trips an existing skill, either fix the skill or argue the rule.

## Adding a new skill to the plugin

A skill is a directory under `skills/` containing a `SKILL.md` and any `references/` and `scripts/` it needs. The minimum:

```
skills/your-skill/
├── SKILL.md
└── references/
    └── (any reference docs the skill loads)
```

`SKILL.md` opens with YAML frontmatter:

```markdown
---
name: your-skill
description: Use when ... establishes ...
---
```

The body follows the canonical 13-section anatomy enforced by LINT-010: HARD-GATEs, Core Principle, Anti-Pattern, Process Flow (DOT digraph fence), Checklist, Step Details, Gate Functions, Rationalisation Table, Red Flags, Status Vocabulary, Key Principles, The Bottom Line, Cross-references.

Read two existing skills before writing your own. `skills/skill-voice-review/SKILL.md` is the densest example. `skills/using-skill-cheat/SKILL.md` is the most accessible.

Your new skill must pass its own voice-review:

```bash
bash skills/skill-voice-review/scripts/lint.sh --mode self skills/your-skill/SKILL.md
```

The verdict must be `ACCEPT`. `ACCEPT_WITH_MINOR` does not ship.

## Pull request guidelines

- One concern per PR. A bug fix and a refactor in the same branch get split before review.
- Branch name describes the change, not the area. `add-lint-rule-022-trailing-whitespace` is good. `lint-changes` is not.
- The PR description names what changed, why, and how you tested it. A bullet list is fine.
- If the PR touches the lint engine, the description includes the before/after verdict on a representative SKILL.md.
- If the PR changes a rule's `kind` (skill-shape ↔ plugin-policy) or severity, include the cross-plugin stress-test output before and after.

## Reporting bugs

Open an issue with:

- The command that reproduces the bug.
- The exact text of any blocking output.
- The relevant `report.json` from `.skill-cheat-qa/runs/<run-id>/` if the stress harness is involved, with sensitive paths redacted.
- What you expected to happen and what happened instead.

If the bug is "the linter said something I disagree with", that is a rule disagreement rather than a bug. Open it as an issue tagged `rule-debate` and include the exact rule ID and the counter-argument.

## Code of conduct

Be a person about it. If you would not say it to someone in the same room, do not say it in the issue thread.

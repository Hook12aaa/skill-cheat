# skill-cheat Plan 1 of 3 — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stand up the skill-cheat plugin skeleton: plugin manifests, SessionStart + UserPromptSubmit hooks with keyword self-trigger, config override mechanism, and a placeholder bootstrap SKILL.md. Exit state: the plugin installs via `/plugin install`, `SessionStart` injects bootstrap context, and `UserPromptSubmit` fires a reminder when the user types skill-authoring intent keywords. No lint engine yet. No pipeline skills yet.

**Architecture:** Pure POSIX shell for hooks. Plugin manifests as JSON. One library function per file under `hooks/lib/`. Tests are shell scripts that source the function under test, call it with crafted inputs, and assert on exit code + stdout. A top-level `tests/run-tests.sh` orchestrates.

**Tech Stack:** `bash` (≥4), `jq` (JSON emit/inspect in tests only), `diff` (output comparison in tests). No Node, no Python, no external dependencies at this phase.

**Comment discipline (applies to every `.sh` and `.js` code block in this plan):** comments are LLM-instructions only — directives and invariants. No change-history, no rationale, no maintainer notes. Omit comments entirely when no directive is load-bearing.

---

## File Structure

Files created in this plan (14 total):

```
skill_cheat/
├── .gitignore                                 ← Task 1
├── .claude-plugin/
│   ├── plugin.json                            ← Task 2
│   └── marketplace.json                       ← Task 2
├── README.md                                  ← Task 3
├── CLAUDE.md                                  ← Task 3
├── config.sh                                  ← Task 4
├── hooks/
│   ├── hooks.json                             ← Task 9
│   ├── session-start                          ← Task 7 (shell script, no extension)
│   ├── user-prompt-submit                     ← Task 8
│   └── lib/
│       ├── emit-context.sh                    ← Task 5
│       └── detect-skill-intent.sh             ← Task 6
├── skills/
│   └── using-skill-cheat/
│       └── SKILL.md                           ← Task 10 (placeholder)
└── tests/
    ├── run-tests.sh                           ← Task 11
    └── hooks/
        ├── test-emit-context.sh               ← Task 5 (TDD test)
        ├── test-detect-skill-intent.sh        ← Task 6 (TDD test)
        ├── test-session-start.sh              ← Task 7 (TDD test)
        └── test-user-prompt-submit.sh         ← Task 8 (TDD test)
```

**Responsibilities:**
- `.claude-plugin/plugin.json` — plugin manifest (installer reads this).
- `.claude-plugin/marketplace.json` — local marketplace descriptor for `claude plugins marketplace add`.
- `config.sh` — default trigger keywords; overridable per-project via `.skill-cheat.sh`.
- `hooks/lib/emit-context.sh` — one function: `emit_context "<text>"`. JSON-safe stdout for hook context injection.
- `hooks/lib/detect-skill-intent.sh` — one function: `detect_skill_intent "<prompt>" "<kw1>" "<kw2>" …` returning exit 0 on match.
- `hooks/session-start` — reads `skills/using-skill-cheat/SKILL.md` and emits it as context.
- `hooks/user-prompt-submit` — reads user prompt from stdin, matches against keywords, emits a reminder on match.
- `hooks/hooks.json` — wires both hooks.
- `skills/using-skill-cheat/SKILL.md` — placeholder bootstrap; expanded in Plan 3.
- `tests/run-tests.sh` — runs every `tests/**/test-*.sh` and fails on any non-zero exit.

---

### Task 1: Initialize git repository and directory skeleton

**Files:**
- Create: `.gitignore`
- Create (directories): `.claude-plugin/`, `hooks/lib/`, `skills/using-skill-cheat/`, `tests/hooks/`

- [ ] **Step 1: Initialize git**

Run from `/Users/hook/Documents/coding/python/Personal_AI  Projects/skill_cheat/`:

```bash
git init
```

Expected: `Initialized empty Git repository in .../skill_cheat/.git/`

- [ ] **Step 2: Create `.gitignore`**

```
.DS_Store
*.swp
*.swo
.skill-cheat.sh
tests/tmp/
```

- [ ] **Step 3: Create directory skeleton**

```bash
mkdir -p .claude-plugin hooks/lib skills/using-skill-cheat tests/hooks
```

- [ ] **Step 4: Verify structure**

Run: `find . -type d -not -path './.git*' -not -path './docs*' | sort`

Expected output:
```
.
./.claude-plugin
./hooks
./hooks/lib
./skills
./skills/using-skill-cheat
./tests
./tests/hooks
```

- [ ] **Step 5: Commit**

```bash
git add .gitignore
git commit -m "chore: initialize skill-cheat plugin skeleton"
```

---

### Task 2: Plugin manifests

**Files:**
- Create: `.claude-plugin/plugin.json`
- Create: `.claude-plugin/marketplace.json`

- [ ] **Step 1: Write `.claude-plugin/plugin.json`**

```json
{
  "name": "skill-cheat",
  "description": "Scaffolds Claude Code skills in the imperative, gate-driven, contract-first style. Self-triggers on skill-authoring prompts.",
  "version": "0.1.0",
  "author": { "name": "hook" },
  "license": "MIT",
  "homepage": "https://github.com/hook/skill-cheat",
  "repository": "https://github.com/hook/skill-cheat",
  "keywords": ["skills", "scaffolding", "plugin-authoring", "lint", "hooks"]
}
```

- [ ] **Step 2: Write `.claude-plugin/marketplace.json`**

```json
{
  "name": "skill-cheat-local",
  "description": "Local marketplace for the skill-cheat plugin during development.",
  "plugins": [
    {
      "name": "skill-cheat",
      "path": "."
    }
  ]
}
```

- [ ] **Step 3: Validate JSON**

Run: `python3 -m json.tool .claude-plugin/plugin.json >/dev/null && python3 -m json.tool .claude-plugin/marketplace.json >/dev/null && echo OK`

Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/
git commit -m "feat: add plugin.json and marketplace.json"
```

---

### Task 3: README and CLAUDE.md

**Files:**
- Create: `README.md`
- Create: `CLAUDE.md`

- [ ] **Step 1: Write `README.md`**

```markdown
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

1. `/skill-scope` — lock name, triggers, verdicts, Anti-Pattern.
2. `/skill-design` — write HARD-GATEs, Core Principle, flow, checklist; emit Integrity Block + SHA-256.
3. `/skill-author` — fill the skill body; verify Integrity Block unchanged.
4. `/skill-voice-review` — mechanical lint + voice-reviewer subagent; REJECT or ACCEPT.
5. `/skill-scaffold` — emit the plugin tree at the target path.

## Principles

- Contract-first, library-last.
- Imperative voice, ALL-CAPS verdicts, zero hedges.
- `.md` + `.js` + `.sh` + `.json` only.
- Structural distrust — no agent both produces and approves its own work.
- Self-contained — no plugin dependencies.
```

- [ ] **Step 2: Write `CLAUDE.md`**

```markdown
# CLAUDE.md — plugin contributor notes

End-user install lives in `README.md`. This file is for modifying skill-cheat itself.

## Layout

- `.claude-plugin/plugin.json` — plugin manifest.
- `.claude-plugin/marketplace.json` — local marketplace descriptor.
- `skills/using-skill-cheat/SKILL.md` — bootstrap; auto-loaded via SessionStart.
- `skills/<stage>/SKILL.md` — one per pipeline stage (added in Plan 3).
- `hooks/session-start` — injects bootstrap into context.
- `hooks/user-prompt-submit` — self-triggers gate reminder on skill-authoring prompts.
- `hooks/lib/*.sh` — small pure-shell helpers; one function per file.
- `config.sh` — default trigger keywords; override with `.skill-cheat.sh` in the target project.
- `tests/run-tests.sh` — runs every `tests/**/test-*.sh`. Must pass before commit.

## Testing

```bash
bash tests/run-tests.sh
```

Every hook has a test. Add one when you add a hook.

## Comment discipline

`.sh` and `.js` comments are LLM-instructions only — directives and invariants. No dev-history, no rationale, no maintainer notes. If a comment does not constrain behavior, delete it.

## Updating triggers

- Keyword list: edit `SKILL_CHEAT_TRIGGER_KEYWORDS` in `config.sh`.
- Re-run `bash tests/run-tests.sh`.
```

- [ ] **Step 3: Commit**

```bash
git add README.md CLAUDE.md
git commit -m "docs: add README and contributor notes"
```

---

### Task 4: Config with trigger keywords

**Files:**
- Create: `config.sh`

- [ ] **Step 1: Write `config.sh`**

```bash
#!/usr/bin/env bash

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

if [[ -f "${CLAUDE_PROJECT_DIR:-.}/.skill-cheat.sh" ]]; then
  # shellcheck source=/dev/null
  source "${CLAUDE_PROJECT_DIR:-.}/.skill-cheat.sh"
fi
```

- [ ] **Step 2: Syntax check**

Run: `bash -n config.sh && echo OK`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add config.sh
git commit -m "feat: add config.sh with trigger keyword defaults"
```

---

### Task 5: `emit-context.sh` (TDD)

**Files:**
- Create: `tests/hooks/test-emit-context.sh`
- Create: `hooks/lib/emit-context.sh`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "${HERE}/hooks/lib/emit-context.sh"

actual="$(emit_context "hello world")"
expected='{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"hello world"}}'

if [[ "$actual" != "$expected" ]]; then
  echo "FAIL: emit_context plain text"
  diff <(printf '%s\n' "$expected") <(printf '%s\n' "$actual") || true
  exit 1
fi

actual="$(emit_context 'line with "quotes" and \backslash')"
if ! printf '%s' "$actual" | jq -e . >/dev/null; then
  echo "FAIL: emit_context output is not valid JSON for tricky input"
  echo "$actual"
  exit 1
fi

echo "PASS: emit-context"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
chmod +x tests/hooks/test-emit-context.sh
bash tests/hooks/test-emit-context.sh
```

Expected: error, emit_context not defined (or similar).

- [ ] **Step 3: Write `hooks/lib/emit-context.sh`**

```bash
#!/usr/bin/env bash

emit_context() {
  local text="$1"
  # Invariant: stdout must be a single valid JSON object with additionalContext set.
  jq -nc --arg t "$text" \
    '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $t}}'
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/hooks/test-emit-context.sh
```

Expected: `PASS: emit-context`

- [ ] **Step 5: Commit**

```bash
git add hooks/lib/emit-context.sh tests/hooks/test-emit-context.sh
git commit -m "feat: add emit-context helper with JSON-safe output"
```

---

### Task 6: `detect-skill-intent.sh` (TDD)

**Files:**
- Create: `tests/hooks/test-detect-skill-intent.sh`
- Create: `hooks/lib/detect-skill-intent.sh`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=/dev/null
source "${HERE}/hooks/lib/detect-skill-intent.sh"

KEYWORDS=("author a skill" "build a skill" "new plugin")

# Match: exact keyword.
if ! detect_skill_intent "Let me author a skill for X" "${KEYWORDS[@]}"; then
  echo "FAIL: exact-keyword match missed"; exit 1
fi

# Match: case-insensitive.
if ! detect_skill_intent "I want to BUILD A SKILL now" "${KEYWORDS[@]}"; then
  echo "FAIL: case-insensitive match missed"; exit 1
fi

# No match.
if detect_skill_intent "debug the auth flow" "${KEYWORDS[@]}"; then
  echo "FAIL: false positive on unrelated prompt"; exit 1
fi

# Empty input.
if detect_skill_intent "" "${KEYWORDS[@]}"; then
  echo "FAIL: false positive on empty input"; exit 1
fi

# No keywords supplied.
if detect_skill_intent "author a skill"; then
  echo "FAIL: matched with empty keyword list"; exit 1
fi

echo "PASS: detect-skill-intent"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
chmod +x tests/hooks/test-detect-skill-intent.sh
bash tests/hooks/test-detect-skill-intent.sh
```

Expected: function-not-defined error.

- [ ] **Step 3: Write `hooks/lib/detect-skill-intent.sh`**

```bash
#!/usr/bin/env bash

detect_skill_intent() {
  local prompt="$1"; shift || true
  [[ -z "$prompt" ]] && return 1
  (( "$#" == 0 )) && return 1
  local lower_prompt
  lower_prompt="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"
  local kw lower_kw
  for kw in "$@"; do
    lower_kw="$(printf '%s' "$kw" | tr '[:upper:]' '[:lower:]')"
    if [[ "$lower_prompt" == *"$lower_kw"* ]]; then
      return 0
    fi
  done
  return 1
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/hooks/test-detect-skill-intent.sh
```

Expected: `PASS: detect-skill-intent`

- [ ] **Step 5: Commit**

```bash
git add hooks/lib/detect-skill-intent.sh tests/hooks/test-detect-skill-intent.sh
git commit -m "feat: add detect-skill-intent keyword matcher"
```

---

### Task 7: `hooks/session-start` (TDD)

**Files:**
- Create: `tests/hooks/test-session-start.sh`
- Create: `hooks/session-start`
- Create (stub): `skills/using-skill-cheat/SKILL.md` (minimal content to let the test pass; real content in Task 10)

- [ ] **Step 1: Write a minimal bootstrap stub so the hook has something to read**

Create `skills/using-skill-cheat/SKILL.md`:

```markdown
---
name: using-skill-cheat
description: Bootstrap placeholder. Real content added in Task 10.
---

# using-skill-cheat (stub)
```

- [ ] **Step 2: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export CLAUDE_PLUGIN_ROOT="$HERE"

out="$(bash "${HERE}/hooks/session-start" </dev/null)"

if ! printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null; then
  echo "FAIL: session-start did not emit JSON with additionalContext"
  echo "$out"
  exit 1
fi

content="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext')"

if [[ "$content" != *"using-skill-cheat"* ]]; then
  echo "FAIL: bootstrap content not injected"
  exit 1
fi

echo "PASS: session-start"
```

- [ ] **Step 3: Run test to verify it fails**

```bash
chmod +x tests/hooks/test-session-start.sh
bash tests/hooks/test-session-start.sh
```

Expected: no `hooks/session-start` script found.

- [ ] **Step 4: Write `hooks/session-start`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Invariant: fail silent if bootstrap missing — never block session start.

BOOTSTRAP="${CLAUDE_PLUGIN_ROOT}/skills/using-skill-cheat/SKILL.md"
[[ -f "$BOOTSTRAP" ]] || exit 0

# shellcheck source=../hooks/lib/emit-context.sh
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/emit-context.sh"

emit_context "$(cat "$BOOTSTRAP")"
```

- [ ] **Step 5: Make executable and run test**

```bash
chmod +x hooks/session-start
bash tests/hooks/test-session-start.sh
```

Expected: `PASS: session-start`

- [ ] **Step 6: Commit**

```bash
git add hooks/session-start tests/hooks/test-session-start.sh skills/using-skill-cheat/SKILL.md
git commit -m "feat: add session-start hook that injects bootstrap"
```

---

### Task 8: `hooks/user-prompt-submit` (TDD)

**Files:**
- Create: `tests/hooks/test-user-prompt-submit.sh`
- Create: `hooks/user-prompt-submit`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export CLAUDE_PLUGIN_ROOT="$HERE"

# Match case: injects reminder.
payload='{"prompt":"I want to author a skill for frontend debugging"}'
out="$(printf '%s' "$payload" | bash "${HERE}/hooks/user-prompt-submit")"

if ! printf '%s' "$out" | jq -e '.hookSpecificOutput.additionalContext' >/dev/null; then
  echo "FAIL: did not emit JSON on matching prompt"
  echo "$out"; exit 1
fi

content="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext')"
if [[ "$content" != *"/skill-scope"* ]]; then
  echo "FAIL: reminder does not name /skill-scope"; exit 1
fi

# No-match case: silent (zero-length stdout).
payload='{"prompt":"help me debug this python error"}'
out="$(printf '%s' "$payload" | bash "${HERE}/hooks/user-prompt-submit")"
if [[ -n "$out" ]]; then
  echo "FAIL: non-empty output on no-match prompt"
  echo "$out"; exit 1
fi

# Malformed input: exit zero, no output.
out="$(printf 'not json at all' | bash "${HERE}/hooks/user-prompt-submit")"
if [[ -n "$out" ]]; then
  echo "FAIL: non-empty output on malformed input"
  echo "$out"; exit 1
fi

echo "PASS: user-prompt-submit"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
chmod +x tests/hooks/test-user-prompt-submit.sh
bash tests/hooks/test-user-prompt-submit.sh
```

Expected: no `hooks/user-prompt-submit` script found.

- [ ] **Step 3: Write `hooks/user-prompt-submit`**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Invariant: never fail the prompt-submit path. On any error, exit silent.

# shellcheck source=/dev/null
source "${CLAUDE_PLUGIN_ROOT}/config.sh"
# shellcheck source=lib/emit-context.sh
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/emit-context.sh"
# shellcheck source=lib/detect-skill-intent.sh
source "${CLAUDE_PLUGIN_ROOT}/hooks/lib/detect-skill-intent.sh"

payload="$(cat)"
prompt="$(printf '%s' "$payload" | jq -r '.prompt // empty' 2>/dev/null || true)"
[[ -z "$prompt" ]] && exit 0

if detect_skill_intent "$prompt" "${SKILL_CHEAT_TRIGGER_KEYWORDS[@]}"; then
  emit_context "SKILL-AUTHORING INTENT DETECTED. Invoke /skill-scope before any other action when building or scaffolding a skill."
fi
```

- [ ] **Step 4: Make executable and run test**

```bash
chmod +x hooks/user-prompt-submit
bash tests/hooks/test-user-prompt-submit.sh
```

Expected: `PASS: user-prompt-submit`

- [ ] **Step 5: Commit**

```bash
git add hooks/user-prompt-submit tests/hooks/test-user-prompt-submit.sh
git commit -m "feat: add user-prompt-submit hook with keyword self-trigger"
```

---

### Task 9: `hooks/hooks.json`

**Files:**
- Create: `hooks/hooks.json`

- [ ] **Step 1: Write `hooks/hooks.json`**

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|clear|compact",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/session-start\"",
            "async": false
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/user-prompt-submit\"",
            "async": false
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 2: Validate JSON**

Run: `python3 -m json.tool hooks/hooks.json >/dev/null && echo OK`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add hooks/hooks.json
git commit -m "feat: wire hooks.json for SessionStart and UserPromptSubmit"
```

---

### Task 10: Expand `using-skill-cheat` bootstrap

**Files:**
- Modify: `skills/using-skill-cheat/SKILL.md`

Replace the placeholder stub with the full bootstrap content.

- [ ] **Step 1: Replace file contents**

```markdown
---
name: using-skill-cheat
description: Bootstrap context for the skill-cheat plugin. Auto-loaded at session start. Directs Claude to invoke /skill-scope before authoring any new Claude Code skill. Not a runtime-triggered skill — use the pipeline stages for the actual work.
---

# Using skill-cheat

Treat every new skill as gated by the skill-cheat pipeline. **Every skill ships through the 5-stage pipeline** before it is written to disk.

## The Rule

> **Contract-first, library-last. Imperative voice. ALL-CAPS verdicts. No hedges.**

Every skill specifies the shape of work (preconditions, verdicts, invariants), never which tools to use. Claude picks tools at target-project time.

## When to Invoke

Invoke `/skill-scope` **BEFORE** writing any new Claude Code skill, including:

- Any new SKILL.md file in any plugin.
- Any rewrite of an existing SKILL.md that changes its HARD-GATEs, Core Principle, or verdict vocabulary.
- Any "quick skill" for a one-off workflow — the pipeline is cheap; skipping it is expensive.

Skip the pipeline for: reference file edits, test fixtures, CLAUDE.md notes, documentation.

## Hard Stop Rule

**Do NOT write a SKILL.md until `/skill-voice-review` returns ACCEPT or ACCEPT_WITH_MINOR.** REJECT_CRITICAL or REJECT_IMPORTANT means the skill fails — fix or drop.

## Available Skills

| Skill | Trigger | Verdicts |
|---|---|---|
| skill-scope | `/skill-scope` | SCOPE_LOCKED, SCOPE_INCOMPLETE, BLOCKED_NEEDS_USER |
| skill-design | `/skill-design` | DESIGN_LOCKED, DESIGN_REJECTED, BLOCKED_REVIEWER |
| skill-author | `/skill-author` | AUTHOR_DONE, AUTHOR_INCOMPLETE, BLOCKED_TAMPER |
| skill-voice-review | `/skill-voice-review` | ACCEPT, ACCEPT_WITH_MINOR, REJECT_CRITICAL, REJECT_IMPORTANT, INCONCLUSIVE, BLOCKED_VOICE |
| skill-scaffold | `/skill-scaffold` | SCAFFOLD_COMPLETE, SCAFFOLD_INCOMPLETE, BLOCKED_OVERWRITE |
| receiving-voice-review | (internal) | — |

## Core Principles

1. **Contract-first, library-last.** The skill names the shape; Claude picks the tools.
2. **Structural distrust.** No agent both produces and approves its own work.
3. **Integrity Block is immutable.** Stage 2 locks six fields; stages 3-5 re-verify SHA-256.
4. **Self-contained.** skill-cheat has zero plugin dependencies. Every pattern is written here, not referenced.

## Status Vocabulary

Verdicts are ALL-CAPS single words emitted on a line prefixed `VERDICT:`. See the stage table above for the full set.

## Red Flags

Stop and invoke `/skill-scope` the moment you notice any of these:

| Red flag | Why |
|---|---|
| "I'll just write the SKILL.md directly" | The pipeline exists to prevent exactly this. |
| "This skill is too simple for the full pipeline" | Simple skills are where unexamined assumptions cause the most drift. |
| Library or framework names in the SKILL.md body | Contract-first means never naming tools. |
| Hedge words in HARD-GATEs | Imperative voice only. |
| A HARD-GATE with a `because` clause | Rationale lives in prose, not in gates. |

## The Bottom Line

Before writing any new skill, invoke `/skill-scope`. The pipeline returns a verdict. Only SHIP — here, `SCAFFOLD_COMPLETE` — means the skill is written to disk.
```

- [ ] **Step 2: Re-run session-start test to confirm nothing broke**

```bash
bash tests/hooks/test-session-start.sh
```

Expected: `PASS: session-start`

- [ ] **Step 3: Commit**

```bash
git add skills/using-skill-cheat/SKILL.md
git commit -m "feat: expand using-skill-cheat bootstrap with pipeline vocabulary"
```

---

### Task 11: `tests/run-tests.sh` orchestrator

**Files:**
- Create: `tests/run-tests.sh`

- [ ] **Step 1: Write the orchestrator**

```bash
#!/usr/bin/env bash
set -euo pipefail

# Invariant: any non-zero exit from a test must fail the suite.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/.." && pwd)"
export CLAUDE_PLUGIN_ROOT="$ROOT"

fail=0
pass=0
failed_tests=()

while IFS= read -r -d '' test_file; do
  if bash "$test_file"; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    failed_tests+=("$test_file")
  fi
done < <(find "$HERE" -type f -name 'test-*.sh' -print0 | sort -z)

echo "----"
echo "Passed: $pass"
echo "Failed: $fail"

if (( fail > 0 )); then
  printf 'FAILED:\n'
  printf '  %s\n' "${failed_tests[@]}"
  exit 1
fi

echo "ALL TESTS PASSED"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tests/run-tests.sh
```

- [ ] **Step 3: Run full suite**

```bash
bash tests/run-tests.sh
```

Expected final line:
```
ALL TESTS PASSED
```

- [ ] **Step 4: Commit**

```bash
git add tests/run-tests.sh
git commit -m "feat: add tests/run-tests.sh orchestrator"
```

---

### Task 12: End-to-end installability check

**Files:** none (verification only)

- [ ] **Step 1: Verify structure matches the expected layout**

Run:
```bash
find . -type f -not -path './.git/*' -not -path './docs/*' | sort
```

Expected output:
```
./.claude-plugin/marketplace.json
./.claude-plugin/plugin.json
./.gitignore
./CLAUDE.md
./README.md
./config.sh
./hooks/hooks.json
./hooks/lib/detect-skill-intent.sh
./hooks/lib/emit-context.sh
./hooks/session-start
./hooks/user-prompt-submit
./skills/using-skill-cheat/SKILL.md
./tests/hooks/test-detect-skill-intent.sh
./tests/hooks/test-emit-context.sh
./tests/hooks/test-session-start.sh
./tests/hooks/test-user-prompt-submit.sh
./tests/run-tests.sh
```

- [ ] **Step 2: Run the full test suite once more**

```bash
bash tests/run-tests.sh
```

Expected: `ALL TESTS PASSED`.

- [ ] **Step 3: Simulate install into Claude Code**

From any directory OTHER than the plugin root:

```bash
echo "Run inside Claude Code to install:"
echo "  /plugin marketplace add /Users/hook/Documents/coding/python/Personal_AI\\ \\ Projects/skill_cheat"
echo "  /plugin install skill-cheat"
```

Expected: the user installs the plugin manually. No programmatic assertion here — the install is a Claude Code action, not a shell operation.

- [ ] **Step 4: Hook smoke test (manual, after install)**

In a fresh Claude Code session after install:
1. Confirm `using-skill-cheat` context appears in the SessionStart-injected content.
2. Type: `I want to build a skill for parsing CSV headers`.
3. Confirm the UserPromptSubmit hook injects the reminder naming `/skill-scope`.

If both happen, Plan 1 is complete. If either fails, the hook wiring is wrong — return to Task 9.

- [ ] **Step 5: Commit a phase-complete marker**

```bash
git commit --allow-empty -m "chore: Plan 1 foundation complete"
git tag plan-1-complete
```

---

## Self-Review

**Spec coverage:**
- §3 plugin layout: every file in Plan 1's scope mapped to a task. Files deferred to Plans 2 and 3 are not in this plan (lint engine, pipeline SKILL.md files, agent definition, commands, references) — by design.
- §2 core design rules: file-type allowlist (only `.md`, `.sh`, `.json` appear in Plan 1 — no `.js` yet, that starts in Plan 2). Self-contained: no cross-plugin references. Host-tool deps: `bash`, `jq`, `python3` (JSON validation only).
- §7 hooks & wiring: `hooks.json` (Task 9), `session-start` (Task 7), `user-prompt-submit` (Task 8), `config.sh` (Task 4), keyword-match library (Task 6), emit-context library (Task 5) — all covered.
- §8 testing strategy layer 1 (hook tests): Tasks 5, 6, 7, 8 each include a test. Orchestrator in Task 11.
- Deferred to Plan 2: lint engine, denylists, integrity-hash. Deferred to Plan 3: pipeline skills, agent, commands, pipeline tests.

**Placeholder scan:** no TBD / TODO / "implement appropriate error handling" / "similar to Task N" phrases. Every shell script body is fully written.

**Type consistency:** `emit_context` signature (Task 5) matches callers (Tasks 7 and 8). `detect_skill_intent` signature (Task 6) matches caller (Task 8). `SKILL_CHEAT_TRIGGER_KEYWORDS` array defined in `config.sh` (Task 4) matches usage (Task 8).

**Comment discipline audit:** every `.sh` and `.json` code block in this plan was reviewed. Comments appearing in the plan's shell scripts are all directive (`Invariant:`) — no dev history, no maintainer notes. `.md` files contain prose by design.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-04-22-skill-cheat-plan-1-foundation.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — one fresh subagent per task, two-stage review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session using executing-plans, batch checkpoints every 3 tasks.

**Which approach?**

Plans 2 and 3 will be written in subsequent sessions once Plan 1 is in the bag.

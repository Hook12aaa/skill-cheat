# skill-cheat Plan 5 of 6 — Benchmarking Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the runtime that consumes `evals/eval-set-skeleton.json` + `evals/assertion-skeleton.json` from any authored skill and produces an enriched `benchmark-plan.json` with per-case trigger/timing/token measurements and per-assertion grading. Built as JS + SH + MD to match model_trainer/report's stack (no Python). Plan 6 wires this into `/skill-voice-review` phase 3 and adds the Node dashboard UI.

**Architecture:** Three ported subagent prompts (grader / comparator / analyzer) adapted from anthropics/skills (Apache 2.0, attribution preserved in a top-level NOTICE). Four new scripts: `git-worktree-setup.sh` materializes baseline + candidate worktrees; `benchmark-plan-init.sh` writes the initial plan-as-log with an Integrity Block and SHA-256 sidecar (mirrors model_trainer's plan contract); `run-eval.js` streams a single `claude -p --include-partial-messages` invocation, detects skill activation via `content_block_start`, and captures timing + token usage; `aggregate-benchmark.js` folds N run outputs into mean ± stddev per ref. Test strategy: every JS and SH primitive has a paired `test-*.sh` fixture. `run-eval.js` takes a `--mock-stream-file` arg so tests can feed canned JSONL streams without needing the real `claude` CLI on CI.

**Tech Stack:** node.js ESM (matches existing `skills/skill-voice-review/scripts/package.json`), bash (POSIX sh + jq), git worktree, openssl (SHA-256), markdown for subagent prompts.

**Comment discipline (applies to every `.sh` and `.js` file touched):** comments are LLM-instructions only — directives and invariants. No dev-history, no rationale, no maintainer notes. SKILL.md files are prose; comment rule does not apply there. Vendored agent `.md` files carry a short attribution line at the top; that is a licence notice, not a dev-history comment, and is permitted.

---

## File Structure

**Modify:**
- `README.md` — add a "Benchmark engine" section pointing at the new scripts and agent prompts, plus the attribution notice.

**Create — attribution:**
- `NOTICE` (top-level) — Apache 2.0 attribution covering the vendored agent prompts and any code segments derived from anthropics/skills.

**Create — agent prompt ports (adapted to imperative voice; header line attributes):**
- `skills/skill-voice-review/agents/grader.md`
- `skills/skill-voice-review/agents/comparator.md`
- `skills/skill-voice-review/agents/analyzer.md`

**Create — scripts (in `skills/skill-voice-review/scripts/`):**
- `git-worktree-setup.sh` — materialize baseline + candidate worktrees under `.skill-cheat/worktrees/<run-NN>/{baseline,candidate}/`.
- `benchmark-plan-init.sh` — read scope.json + eval-set + assertion-skeleton + refs, emit initial `benchmark-plan.json` + `benchmark-plan.md` companion + `.sha256` sidecar.
- `benchmark-integrity-hash.sh` — wrapper that computes the SHA-256 of the integrity block inside `benchmark-plan.md` (byte range strictly between `<!-- integrity-block:start -->` and `<!-- integrity-block:end -->`), mirroring `skills/skill-design/scripts/integrity-hash.sh`.
- `run-eval.js` — the stream-watch driver. Accepts `--skill-path`, `--query`, `--mock-stream-file` (for tests), optional `--model`. Emits one JSON line to stdout describing the run.
- `run-eval.sh` — bash wrapper for dispatch; passes args through to `run-eval.js`.
- `aggregate-benchmark.js` — fold N run-eval JSON outputs into per-ref aggregate stats (pass-rate, meanTokens, stddevTokens, meanDurationMs, stddevDurationMs).

**Create — tests:**
- `tests/integration/test-git-worktree-setup.sh`
- `tests/integration/test-benchmark-plan-init.sh`
- `tests/integration/test-benchmark-integrity-hash.sh`
- `tests/integration/test-run-eval-mock.sh`
- `tests/integration/test-aggregate-benchmark.sh`
- `tests/integration/fixtures/mock-stream-triggered.jsonl`
- `tests/integration/fixtures/mock-stream-no-trigger.jsonl`

---

## Cross-Task Invariants (referenced in later tasks)

**run-eval.js output shape** (fixed throughout Plan 5, Plan 6):
```json
{
  "skillName": "<name>",
  "query": "<case query>",
  "triggered": true,
  "durationMs": 4200,
  "totalTokens": 12345,
  "streamEvents": 42,
  "mock": false
}
```
(`mock: true` when `--mock-stream-file` was used; the flag is for test harnesses, never production.)

**benchmark-plan.json initial shape (before results enrichment):**
```json
{
  "schemaVersion": "1.0",
  "skillName": "<name>",
  "runId": "<ISO-8601 UTC>",
  "integrityBlock": {"sha256": "<hex>", "path": "benchmark-plan.md"},
  "baselineRef": "HEAD",
  "candidateRef": "working-copy",
  "worktrees": {"baseline": "<abs>", "candidate": "<abs>"},
  "cases": [...],
  "assertions": [...],
  "results": [],
  "aggregate": null
}
```
Matches `skills/skill-voice-review/references/benchmark-plan-schema.md`.

**Exit codes (shared across new scripts):**
- `64` — usage error (bad args).
- `65` — schema violation (missing/empty required field).
- `66` — input file not found.
- `67` — git operation failed (worktree / ref).

---

### Task 1: NOTICE file + Apache 2.0 attribution

**Files:**
- Create: `NOTICE`

- [ ] **Step 1: Write the NOTICE file**

Create `NOTICE` at repo root:

```
skill-cheat
Copyright 2026 The skill-cheat Authors.

This product includes subagent prompt templates adapted from the
anthropics/skills repository (https://github.com/anthropics/skills),
licensed under the Apache License, Version 2.0.

The following files are derivative works of anthropics/skills
(skill-creator skill, commit b9e19e6 "Fill in Apache 2.0 copyright
notice in claude-api LICENSE.txt"):

- skills/skill-voice-review/agents/grader.md
  (adapted from skill-creator/agents/grader.md)
- skills/skill-voice-review/agents/comparator.md
  (adapted from skill-creator/agents/comparator.md)
- skills/skill-voice-review/agents/analyzer.md
  (adapted from skill-creator/agents/analyzer.md)

Adaptations: prose rewritten for imperative voice; Inputs/Outputs
sections reshaped to the dispatch-prompt template used by the
skill-cheat voice-reviewer.

A copy of the Apache 2.0 license text is available at
https://www.apache.org/licenses/LICENSE-2.0.
```

- [ ] **Step 2: Commit**

```bash
git add NOTICE
git commit -m "$(cat <<'EOF'
chore: add NOTICE for Apache 2.0 attribution

Plans 5-6 port three subagent prompts from anthropics/skills
(grader, comparator, analyzer). This NOTICE captures the
attribution required by the upstream Apache 2.0 licence.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Port `grader.md` (adapt to imperative voice)

**Files:**
- Create: `skills/skill-voice-review/agents/grader.md`

- [ ] **Step 1: Read the upstream prompt**

Run: `cat "/Users/hook/Documents/coding/python/dumbing ground/skills/skills/skill-creator/agents/grader.md" | wc -l`
Expect: 223 lines.

- [ ] **Step 2: Write the adapted prompt**

Create `skills/skill-voice-review/agents/grader.md`:

```markdown
<!-- Derived from anthropics/skills/skills/skill-creator/agents/grader.md (Apache 2.0). See /NOTICE. -->

# Grader subagent

Evaluate each assertion against an execution transcript and the output files produced by a single benchmark run. Return PASS, FAIL, or NEEDS_CONTEXT per assertion with concrete evidence.

## Inputs (inline via dispatch prompt)

- `skillName` — the skill under test.
- `assertions` — list of `{id, type, pattern, evidence}` entries from `evals/assertion-skeleton.json` (or its enriched form).
- `transcriptPath` — absolute path to the transcript markdown captured by `run-eval.js`.
- `outputsDir` — absolute path to the directory of artefacts the skill produced (may be empty).

## Process

1. Read the transcript in full. Do NOT skim.
2. List `outputsDir`. Read each artefact relevant to an assertion. Do NOT rely on the transcript's paraphrase — open the files.
3. For each assertion:
   - Search for evidence in the transcript and the outputs.
   - Assign PASS only when the evidence demonstrates real task completion, not surface compliance.
   - Assign FAIL on contradicted, missing, or superficial evidence.
   - Assign NEEDS_CONTEXT when the assertion is under-specified or the transcript is incomplete.
4. Flag evals that passed trivially (assertion wording too weak) or important outcomes no assertion covers.

## Output format (single JSON object to stdout)

```json
{
  "skillName": "<name>",
  "results": [
    {"assertionId": 1, "verdict": "PASS", "evidence": "transcript line 42: `assert X`"},
    {"assertionId": 2, "verdict": "FAIL", "evidence": "outputsDir/foo.md missing required heading"}
  ],
  "evalCritique": [
    {"assertionId": 2, "issue": "assertion pattern is too vague; a trivial echo would satisfy it"}
  ]
}
```

## Hard rules

- Never return more `results[]` entries than there were input assertions.
- Never invent assertion ids.
- Never mark PASS on evidence-by-absence. "I did not see a failure" is NEEDS_CONTEXT, not PASS.
- Never interpret — only grade. Leave pattern-level improvement suggestions to the analyzer subagent.
```

- [ ] **Step 3: Commit**

```bash
git add skills/skill-voice-review/agents/grader.md
git commit -m "$(cat <<'EOF'
feat(voice-review): port grader subagent from anthropics/skills

Adapted to imperative voice. Grades one assertion at a time against
the transcript + outputs produced by a single benchmark run. Apache 2.0
attribution preserved in header + NOTICE.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Port `comparator.md`

**Files:**
- Create: `skills/skill-voice-review/agents/comparator.md`

- [ ] **Step 1: Write the adapted prompt**

Create `skills/skill-voice-review/agents/comparator.md`:

```markdown
<!-- Derived from anthropics/skills/skills/skill-creator/agents/comparator.md (Apache 2.0). See /NOTICE. -->

# Blind comparator subagent

Judge which of two outputs better accomplishes the benchmark case. You do NOT know which output came from the baseline and which from the candidate — that information is withheld to prevent bias.

## Inputs (inline via dispatch prompt)

- `caseId` — integer.
- `query` — the original user prompt for this case.
- `outputAPath` — absolute path to output A (file or directory).
- `outputBPath` — absolute path to output B (file or directory).
- `expectations` — optional list of expectation strings; may be empty.

## Process

1. Read both outputs in full. If a path is a directory, read every file.
2. Note type, structure, content of each.
3. Judge solely on task completion and output quality. Do NOT weigh length, verbosity, or confidence tone.
4. Choose a winner, or declare TIE when the outputs are genuinely equivalent.

## Output format (single JSON object to stdout)

```json
{
  "caseId": 42,
  "winner": "A",
  "reasoning": "B produced the required header hierarchy; A omitted the H2 under 'Results'.",
  "scores": {"A": 6, "B": 8},
  "tiebreakers": []
}
```

- `winner` ∈ `{"A", "B", "TIE"}`.
- `scores` on a 0-10 scale. Equal scores with `winner != "TIE"` is forbidden.

## Hard rules

- Never peek at skill paths or commit hashes. If you can infer which side is baseline vs candidate, report that as a leakage bug and STOP.
- Never weight style preferences over task completion. A concise correct answer beats a verbose correct answer only if the verbosity adds no information the query asked for.
- Never TIE to avoid judgment. TIE requires genuine equivalence, not uncertainty.
```

- [ ] **Step 2: Commit**

```bash
git add skills/skill-voice-review/agents/comparator.md
git commit -m "$(cat <<'EOF'
feat(voice-review): port blind comparator subagent

Adapted to imperative voice. Judges A vs B without knowing which side
came from baseline vs candidate. Apache 2.0 attribution preserved.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Port `analyzer.md`

**Files:**
- Create: `skills/skill-voice-review/agents/analyzer.md`

- [ ] **Step 1: Write the adapted prompt**

Create `skills/skill-voice-review/agents/analyzer.md`:

```markdown
<!-- Derived from anthropics/skills/skills/skill-creator/agents/analyzer.md (Apache 2.0). See /NOTICE. -->

# Post-hoc analyzer subagent

Unblind the blind-comparator verdict and extract actionable insights. Read both skills, both transcripts, and the comparator's output to explain WHY the winner won and what the loser should change.

## Inputs (inline via dispatch prompt)

- `winner` — `"A"` or `"B"` (from the comparator).
- `winnerSkillPath` — absolute path to the skill directory that produced the winning output.
- `winnerTranscriptPath` — absolute path to the winner's transcript markdown.
- `loserSkillPath` — absolute path.
- `loserTranscriptPath` — absolute path.
- `comparisonResultPath` — absolute path to the blind comparator's JSON output.
- `outputPath` — absolute path to write the analysis JSON.

## Process

1. Read the comparator's result in full; note the reasoning.
2. Read both SKILL.md files. Diff them mentally — what's structurally different?
3. Read both transcripts. Where did the loser's transcript diverge from the winner's? Missing steps, swallowed errors, wrong tool use, overbuilt output.
4. Attribute the win to specific SKILL.md differences when possible. "Winner's HARD-GATE blocked the degenerate path" is actionable; "winner was better" is not.
5. Write a short improvement list for the loser.

## Output format (single JSON object written to `outputPath`)

```json
{
  "caseId": 42,
  "winner": "A",
  "attribution": [
    {"skillLine": "HARD-GATE: Do NOT proceed without X.", "observedEffect": "blocked degenerate path at transcript line 12"}
  ],
  "loserFailureModes": [
    {"mode": "swallowed error", "transcriptLine": 34, "suggestion": "tighten Gate Function 3 to assert `exit != 0`"}
  ],
  "nonDiscriminatingAssertions": [1, 4],
  "highVarianceEvals": []
}
```

## Hard rules

- Never invent transcript line numbers. Cite only lines you verified.
- Never propose changes outside the loser's SKILL.md (scope, design, scaffold stages are not yours to touch).
- Never judge the comparator — analysis assumes the verdict. If the verdict looks wrong, STOP and escalate with status NEEDS_CONTEXT.
```

- [ ] **Step 2: Commit**

```bash
git add skills/skill-voice-review/agents/analyzer.md
git commit -m "$(cat <<'EOF'
feat(voice-review): port post-hoc analyzer subagent

Adapted to imperative voice. Unblinds the comparator verdict and
attributes the win to specific SKILL.md differences. Apache 2.0
attribution preserved.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: `git-worktree-setup.sh` (TDD)

**Files:**
- Create: `skills/skill-voice-review/scripts/git-worktree-setup.sh`
- Create: `tests/integration/test-git-worktree-setup.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/integration/test-git-worktree-setup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SETUP="${HERE}/skills/skill-voice-review/scripts/git-worktree-setup.sh"

tmp="$(mktemp -d)"
cleanup() { rm -rf "$tmp"; git -C "$HERE" worktree prune 2>/dev/null || true; }
trap cleanup EXIT

# Invariant: two worktrees materialized; baseline first in output; non-zero exit on unknown ref.
out="$(bash "$SETUP" --baseline HEAD --candidate HEAD --root "$tmp/worktrees" --run-id test-run)"
bpath="$(printf '%s' "$out" | jq -r '.worktrees.baseline')"
cpath="$(printf '%s' "$out" | jq -r '.worktrees.candidate')"

[[ -d "$bpath" ]] || { echo "FAIL: baseline worktree missing: $bpath"; exit 1; }
[[ -d "$cpath" ]] || { echo "FAIL: candidate worktree missing: $cpath"; exit 1; }
[[ -f "$bpath/README.md" ]] || { echo "FAIL: baseline worktree looks empty"; exit 1; }

# Invariant: bad ref exits 67.
if bash "$SETUP" --baseline no-such-ref --candidate HEAD --root "$tmp/bad" --run-id bad 2>/dev/null; then
  echo "FAIL: setup accepted bad ref"; exit 1
fi

echo "PASS: git-worktree-setup"
```

- [ ] **Step 2: Run test to verify it fails (script absent)**

Run: `bash tests/integration/test-git-worktree-setup.sh`
Expect failure.

- [ ] **Step 3: Write the setup script**

Create `skills/skill-voice-review/scripts/git-worktree-setup.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Invariant: materializes baseline + candidate worktrees at <root>/<run-id>/{baseline,candidate}/; baseline first.
# Invariant: stdout is a single JSON object; exit 67 on git failure; exit 64 on bad args.

BASELINE=""
CANDIDATE=""
ROOT=""
RUN_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --baseline)  BASELINE="$2";  shift 2 ;;
    --candidate) CANDIDATE="$2"; shift 2 ;;
    --root)      ROOT="$2";      shift 2 ;;
    --run-id)    RUN_ID="$2";    shift 2 ;;
    *) echo "git-worktree-setup: unknown arg $1" >&2; exit 64 ;;
  esac
done
[[ -n "$BASELINE" && -n "$CANDIDATE" && -n "$ROOT" && -n "$RUN_ID" ]] \
  || { echo "git-worktree-setup: --baseline --candidate --root --run-id all required" >&2; exit 64; }

git rev-parse --verify "$BASELINE" >/dev/null 2>&1 \
  || { echo "git-worktree-setup: baseline ref not resolvable: $BASELINE" >&2; exit 67; }
git rev-parse --verify "$CANDIDATE" >/dev/null 2>&1 \
  || { echo "git-worktree-setup: candidate ref not resolvable: $CANDIDATE" >&2; exit 67; }

BASE_PATH="${ROOT}/${RUN_ID}/baseline"
CAND_PATH="${ROOT}/${RUN_ID}/candidate"
mkdir -p "$(dirname "$BASE_PATH")"

git worktree add --detach "$BASE_PATH" "$BASELINE" >/dev/null 2>&1 \
  || { echo "git-worktree-setup: baseline worktree add failed" >&2; exit 67; }
git worktree add --detach "$CAND_PATH" "$CANDIDATE" >/dev/null 2>&1 \
  || { echo "git-worktree-setup: candidate worktree add failed" >&2; exit 67; }

jq -n \
  --arg base "$BASE_PATH" \
  --arg cand "$CAND_PATH" \
  --arg bref "$BASELINE" \
  --arg cref "$CANDIDATE" \
  --arg run "$RUN_ID" \
  '{runId: $run, baselineRef: $bref, candidateRef: $cref, worktrees: {baseline: $base, candidate: $cand}}'
```

- [ ] **Step 4: Make executable + run test**

```bash
chmod +x skills/skill-voice-review/scripts/git-worktree-setup.sh
bash tests/integration/test-git-worktree-setup.sh
```
Expect: `PASS: git-worktree-setup`.

- [ ] **Step 5: Commit**

```bash
git add skills/skill-voice-review/scripts/git-worktree-setup.sh tests/integration/test-git-worktree-setup.sh
git commit -m "$(cat <<'EOF'
feat(voice-review): git-worktree-setup for benchmark isolation

Materializes baseline + candidate worktrees under a user-supplied root
keyed by run-id. Baseline first (invariant from model_trainer).
Exits 67 on any git failure so partial setups never proceed silently.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: `benchmark-integrity-hash.sh` (companion to design-stage integrity-hash)

**Files:**
- Create: `skills/skill-voice-review/scripts/benchmark-integrity-hash.sh`
- Create: `tests/integration/test-benchmark-integrity-hash.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/integration/test-benchmark-integrity-hash.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HASH="${HERE}/skills/skill-voice-review/scripts/benchmark-integrity-hash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "${tmp}/benchmark-plan.md" <<'EOF'
<!-- integrity-block:start -->
skillName: demo
baselineRef: HEAD
candidateRef: working-copy
<!-- integrity-block:end -->

free-form notes below
EOF

bash "$HASH" "${tmp}/benchmark-plan.md"
[[ -f "${tmp}/benchmark-plan.md.sha256" ]] || { echo "FAIL: sidecar missing"; exit 1; }

# Invariant: sidecar is 64-char hex + two spaces + filename.
line="$(cat "${tmp}/benchmark-plan.md.sha256")"
[[ "$line" =~ ^[a-f0-9]{64}\ \ benchmark-plan\.md$ ]] || { echo "FAIL: sidecar format wrong: $line"; exit 1; }

# Invariant: altering content OUTSIDE the integrity block does NOT change the hash.
before="$(awk '{print $1}' "${tmp}/benchmark-plan.md.sha256")"
echo "extra line" >> "${tmp}/benchmark-plan.md"
bash "$HASH" "${tmp}/benchmark-plan.md"
after="$(awk '{print $1}' "${tmp}/benchmark-plan.md.sha256")"
[[ "$before" == "$after" ]] || { echo "FAIL: hash changed when extra-block content was edited"; exit 1; }

# Invariant: altering content INSIDE the integrity block DOES change the hash.
sed -i.bak 's/baselineRef: HEAD/baselineRef: main/' "${tmp}/benchmark-plan.md"
bash "$HASH" "${tmp}/benchmark-plan.md"
changed="$(awk '{print $1}' "${tmp}/benchmark-plan.md.sha256")"
[[ "$before" != "$changed" ]] || { echo "FAIL: hash unchanged when in-block content was edited"; exit 1; }

echo "PASS: benchmark-integrity-hash"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/integration/test-benchmark-integrity-hash.sh`
Expect: failure (script absent).

- [ ] **Step 3: Write the hasher**

Create `skills/skill-voice-review/scripts/benchmark-integrity-hash.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Invariant: writes a 64-char sha256 sidecar at <file>.sha256 covering the byte range strictly between the integrity-block markers.
# Invariant: markers `<!-- integrity-block:start -->` / `<!-- integrity-block:end -->` themselves are NOT included in the hash.

if [[ $# -lt 1 ]]; then
  echo "usage: benchmark-integrity-hash.sh <benchmark-plan.md>" >&2
  exit 64
fi

src="$1"
[[ -f "$src" ]] || { echo "benchmark-integrity-hash: file not found: $src" >&2; exit 66; }

basename="$(basename "$src")"
digest="$(awk '
    /<!-- integrity-block:start -->/ { emit=1; next }
    /<!-- integrity-block:end -->/   { emit=0; next }
    emit { print }
  ' "$src" | openssl dgst -sha256 | awk '{print $NF}')"

[[ ${#digest} -eq 64 ]] || { echo "benchmark-integrity-hash: digest not 64 hex chars" >&2; exit 65; }

printf '%s  %s\n' "$digest" "$basename" > "${src}.sha256"
```

- [ ] **Step 4: Make executable + run test**

```bash
chmod +x skills/skill-voice-review/scripts/benchmark-integrity-hash.sh
bash tests/integration/test-benchmark-integrity-hash.sh
```
Expect: `PASS: benchmark-integrity-hash`.

- [ ] **Step 5: Commit**

```bash
git add skills/skill-voice-review/scripts/benchmark-integrity-hash.sh tests/integration/test-benchmark-integrity-hash.sh
git commit -m "$(cat <<'EOF'
feat(voice-review): benchmark-integrity-hash companion

SHA-256 sidecar for benchmark-plan.md's integrity block. Mirrors
the skill-design integrity-hash.sh contract (byte range strictly
between the markers; changes inside = hash shift, changes outside
= hash stable).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: `benchmark-plan-init.sh` (TDD)

**Files:**
- Create: `skills/skill-voice-review/scripts/benchmark-plan-init.sh`
- Create: `tests/integration/test-benchmark-plan-init.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/integration/test-benchmark-plan-init.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INIT="${HERE}/skills/skill-voice-review/scripts/benchmark-plan-init.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

SCOPE="${HERE}/tests/integration/fixtures/sample-scope.json"
cat > "${tmp}/eval-set.json" <<'EOF'
{"skillName":"my-skill","cases":[{"id":1,"query":"q1","shouldTrigger":true,"note":"n"}]}
EOF
cat > "${tmp}/assertions.json" <<'EOF'
{"skillName":"my-skill","assertions":[{"id":1,"type":"hard-gate-violation-absent","pattern":"Do NOT X","evidence":"e"}]}
EOF

bash "$INIT" \
  --scope "$SCOPE" \
  --eval-set "${tmp}/eval-set.json" \
  --assertions "${tmp}/assertions.json" \
  --baseline-ref HEAD \
  --candidate-ref working-copy \
  --baseline-path "${tmp}/b" \
  --candidate-path "${tmp}/c" \
  --out-dir "${tmp}/plan"

PJSON="${tmp}/plan/benchmark-plan.json"
PMD="${tmp}/plan/benchmark-plan.md"
PSHA="${tmp}/plan/benchmark-plan.md.sha256"

for f in "$PJSON" "$PMD" "$PSHA"; do
  [[ -f "$f" ]] || { echo "FAIL: missing $f"; exit 1; }
done

# Invariant: baseline-first in worktrees.
[[ "$(jq -r '.worktrees.baseline' "$PJSON")" == "${tmp}/b" ]] || { echo "FAIL: baseline path wrong"; exit 1; }
[[ "$(jq -r '.worktrees.candidate' "$PJSON")" == "${tmp}/c" ]] || { echo "FAIL: candidate path wrong"; exit 1; }

# Invariant: integrityBlock.sha256 is 64 hex.
sha="$(jq -r '.integrityBlock.sha256' "$PJSON")"
[[ "$sha" =~ ^[a-f0-9]{64}$ ]] || { echo "FAIL: sha256 shape wrong: $sha"; exit 1; }

# Invariant: cases + assertions counts propagate from inputs.
[[ "$(jq '.cases | length' "$PJSON")" == "1" ]] || { echo "FAIL: cases count"; exit 1; }
[[ "$(jq '.assertions | length' "$PJSON")" == "1" ]] || { echo "FAIL: assertions count"; exit 1; }

# Invariant: results empty, aggregate null before enrichment.
[[ "$(jq '.results | length' "$PJSON")" == "0" ]] || { echo "FAIL: results not empty"; exit 1; }
[[ "$(jq '.aggregate' "$PJSON")" == "null" ]] || { echo "FAIL: aggregate not null"; exit 1; }

echo "PASS: benchmark-plan-init"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/integration/test-benchmark-plan-init.sh`
Expect: failure.

- [ ] **Step 3: Write the init script**

Create `skills/skill-voice-review/scripts/benchmark-plan-init.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Invariant: emits benchmark-plan.json + benchmark-plan.md + benchmark-plan.md.sha256 into --out-dir.
# Invariant: baselineRef recorded before candidateRef; results=[], aggregate=null at init.
# Invariant: integrity block in benchmark-plan.md is byte-identical between runs given the same inputs.

SCOPE="" EVAL_SET="" ASSERTIONS="" BREF="" CREF="" BPATH="" CPATH="" OUT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --scope)          SCOPE="$2";      shift 2 ;;
    --eval-set)       EVAL_SET="$2";   shift 2 ;;
    --assertions)     ASSERTIONS="$2"; shift 2 ;;
    --baseline-ref)   BREF="$2";       shift 2 ;;
    --candidate-ref)  CREF="$2";       shift 2 ;;
    --baseline-path)  BPATH="$2";      shift 2 ;;
    --candidate-path) CPATH="$2";      shift 2 ;;
    --out-dir)        OUT="$2";        shift 2 ;;
    *) echo "benchmark-plan-init: unknown arg $1" >&2; exit 64 ;;
  esac
done
for name in SCOPE EVAL_SET ASSERTIONS BREF CREF BPATH CPATH OUT; do
  [[ -n "${!name}" ]] || { echo "benchmark-plan-init: --${name,,} required" >&2; exit 64; }
done
for f in "$SCOPE" "$EVAL_SET" "$ASSERTIONS"; do
  [[ -f "$f" ]] || { echo "benchmark-plan-init: file not found: $f" >&2; exit 66; }
done

mkdir -p "$OUT"
PMD="${OUT}/benchmark-plan.md"
PJSON="${OUT}/benchmark-plan.json"

skill_name="$(jq -r '.name' "$SCOPE")"
run_id="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Integrity block content: skillName, baselineRef, candidateRef, cases[].query, assertions[].pattern.
ib_content="$(jq -cn \
  --arg name "$skill_name" \
  --arg bref "$BREF" \
  --arg cref "$CREF" \
  --slurpfile es "$EVAL_SET" \
  --slurpfile as "$ASSERTIONS" \
  '{
    skillName: $name,
    baselineRef: $bref,
    candidateRef: $cref,
    caseQueries: [$es[0].cases[].query],
    assertionPatterns: [$as[0].assertions[].pattern]
  }')"

{
  echo "<!-- integrity-block:start -->"
  printf '%s\n' "$ib_content"
  echo "<!-- integrity-block:end -->"
  echo ""
  echo "# benchmark-plan"
  echo ""
  echo "skill: ${skill_name}"
  echo "run: ${run_id}"
} > "$PMD"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${HERE}/benchmark-integrity-hash.sh" "$PMD"
sha="$(awk '{print $1}' "${PMD}.sha256")"

jq -n \
  --arg name "$skill_name" \
  --arg run "$run_id" \
  --arg sha "$sha" \
  --arg bref "$BREF" \
  --arg cref "$CREF" \
  --arg bp "$BPATH" \
  --arg cp "$CPATH" \
  --slurpfile es "$EVAL_SET" \
  --slurpfile as "$ASSERTIONS" \
  '{
    schemaVersion: "1.0",
    skillName: $name,
    runId: $run,
    integrityBlock: {sha256: $sha, path: "benchmark-plan.md"},
    baselineRef: $bref,
    candidateRef: $cref,
    worktrees: {baseline: $bp, candidate: $cp},
    cases: $es[0].cases,
    assertions: $as[0].assertions,
    results: [],
    aggregate: null
  }' > "$PJSON"
```

- [ ] **Step 4: Make executable + run test**

```bash
chmod +x skills/skill-voice-review/scripts/benchmark-plan-init.sh
bash tests/integration/test-benchmark-plan-init.sh
```
Expect: `PASS: benchmark-plan-init`.

- [ ] **Step 5: Commit**

```bash
git add skills/skill-voice-review/scripts/benchmark-plan-init.sh tests/integration/test-benchmark-plan-init.sh
git commit -m "$(cat <<'EOF'
feat(voice-review): benchmark-plan-init writes the plan-as-log

Takes scope.json + eval-set + assertion-skeleton + refs, produces
benchmark-plan.json, benchmark-plan.md (with integrity block), and
SHA-256 sidecar. Enforces baseline-first; results=[] and aggregate=null
until Plan 5's runtime fills them in.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Extend run-eval's `package.json` for new scripts

**Files:**
- Modify: `skills/skill-voice-review/scripts/package.json`

- [ ] **Step 1: Verify current state**

Run: `cat skills/skill-voice-review/scripts/package.json`
Expected current: `{"type":"module"}` (already present from Plan 2 lint.js).

- [ ] **Step 2: Keep the file as-is**

No change required — `"type": "module"` covers `lint.js`, `run-eval.js`, and `aggregate-benchmark.js` alike.

(This task is a deliberate no-op to document the invariant — subsequent JS files ride on the same package.json. No commit needed. Proceed to Task 9.)

---

### Task 9: `run-eval.js` with mock-stream mode (TDD)

**Files:**
- Create: `skills/skill-voice-review/scripts/run-eval.js`
- Create: `skills/skill-voice-review/scripts/run-eval.sh`
- Create: `tests/integration/test-run-eval-mock.sh`
- Create: `tests/integration/fixtures/mock-stream-triggered.jsonl`
- Create: `tests/integration/fixtures/mock-stream-no-trigger.jsonl`

- [ ] **Step 1: Write the two mock JSONL streams**

Create `tests/integration/fixtures/mock-stream-triggered.jsonl`:

```jsonl
{"type":"system","subtype":"init","session_id":"test-sess-1"}
{"type":"stream_event","event":{"type":"content_block_start","content_block":{"type":"tool_use","name":"Skill","input":{"name":"my-skill"}}}}
{"type":"assistant","message":{"content":[{"type":"text","text":"Running the my-skill workflow..."}]}}
{"type":"result","subtype":"success","duration_ms":4200,"total_tokens":12345}
```

Create `tests/integration/fixtures/mock-stream-no-trigger.jsonl`:

```jsonl
{"type":"system","subtype":"init","session_id":"test-sess-2"}
{"type":"assistant","message":{"content":[{"type":"text","text":"Direct answer without invoking a skill."}]}}
{"type":"result","subtype":"success","duration_ms":1100,"total_tokens":800}
```

- [ ] **Step 2: Write the failing test**

Create `tests/integration/test-run-eval-mock.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUN="${HERE}/skills/skill-voice-review/scripts/run-eval.js"
FIX_HIT="${HERE}/tests/integration/fixtures/mock-stream-triggered.jsonl"
FIX_MISS="${HERE}/tests/integration/fixtures/mock-stream-no-trigger.jsonl"

# Invariant: triggered stream → triggered=true, durationMs=4200, totalTokens=12345.
out="$(node "$RUN" --skill-path /fake --query 'do the thing' --skill-name my-skill --mock-stream-file "$FIX_HIT")"
[[ "$(printf '%s' "$out" | jq -r '.triggered')" == "true" ]] || { echo "FAIL: hit.triggered"; exit 1; }
[[ "$(printf '%s' "$out" | jq -r '.durationMs')" == "4200" ]] || { echo "FAIL: hit.durationMs"; exit 1; }
[[ "$(printf '%s' "$out" | jq -r '.totalTokens')" == "12345" ]] || { echo "FAIL: hit.totalTokens"; exit 1; }
[[ "$(printf '%s' "$out" | jq -r '.mock')" == "true" ]] || { echo "FAIL: hit.mock"; exit 1; }

# Invariant: non-triggered stream → triggered=false.
out="$(node "$RUN" --skill-path /fake --query 'unrelated' --skill-name my-skill --mock-stream-file "$FIX_MISS")"
[[ "$(printf '%s' "$out" | jq -r '.triggered')" == "false" ]] || { echo "FAIL: miss.triggered"; exit 1; }
[[ "$(printf '%s' "$out" | jq -r '.durationMs')" == "1100" ]] || { echo "FAIL: miss.durationMs"; exit 1; }

echo "PASS: run-eval mock"
```

- [ ] **Step 3: Write the implementation**

Create `skills/skill-voice-review/scripts/run-eval.js`:

```javascript
#!/usr/bin/env node
// Invariant: accepts --skill-path --query --skill-name [--mock-stream-file | --model]; emits one JSON object to stdout.
// Invariant: --mock-stream-file reads a pre-recorded JSONL stream instead of spawning claude; never used in production runs.
// Invariant: triggered=true iff the stream contains a content_block_start whose tool_use input name matches --skill-name.

import { readFileSync } from "node:fs";
import { argv, exit, stderr, stdout } from "node:process";

function parseArgs(args) {
  const out = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith("--")) {
      out[args[i].slice(2)] = args[i + 1];
      i++;
    }
  }
  return out;
}

function fail(msg, code = 64) {
  stderr.write(`run-eval: ${msg}\n`);
  exit(code);
}

function analyseStream(lines, skillName) {
  let triggered = false;
  let durationMs = 0;
  let totalTokens = 0;
  let events = 0;
  for (const raw of lines) {
    const line = raw.trim();
    if (!line) continue;
    let ev;
    try { ev = JSON.parse(line); } catch { continue; }
    events += 1;
    if (ev.type === "stream_event"
        && ev.event?.type === "content_block_start"
        && ev.event.content_block?.type === "tool_use"
        && ev.event.content_block.input?.name === skillName) {
      triggered = true;
    }
    if (ev.type === "result" && ev.subtype === "success") {
      durationMs = ev.duration_ms ?? 0;
      totalTokens = ev.total_tokens ?? 0;
    }
  }
  return { triggered, durationMs, totalTokens, streamEvents: events };
}

const args = parseArgs(argv.slice(2));
for (const required of ["skill-path", "query", "skill-name"]) {
  if (!args[required]) fail(`--${required} required`);
}

let streamLines;
let mock = false;
if (args["mock-stream-file"]) {
  mock = true;
  streamLines = readFileSync(args["mock-stream-file"], "utf8").split("\n");
} else {
  fail("production mode not implemented in Plan 5 Task 9; use --mock-stream-file. Plan 5 Task 10 wires real claude subprocess.", 65);
}

const analysis = analyseStream(streamLines, args["skill-name"]);

stdout.write(JSON.stringify({
  skillName: args["skill-name"],
  query: args.query,
  ...analysis,
  mock,
}) + "\n");
```

- [ ] **Step 4: Write the sh wrapper (thin)**

Create `skills/skill-voice-review/scripts/run-eval.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Invariant: thin wrapper around run-eval.js; passes all args through unchanged.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec node "${HERE}/run-eval.js" "$@"
```

- [ ] **Step 5: Make wrapper executable + run test**

```bash
chmod +x skills/skill-voice-review/scripts/run-eval.sh
bash tests/integration/test-run-eval-mock.sh
```
Expect: `PASS: run-eval mock`.

- [ ] **Step 6: Commit**

```bash
git add skills/skill-voice-review/scripts/run-eval.js skills/skill-voice-review/scripts/run-eval.sh tests/integration/test-run-eval-mock.sh tests/integration/fixtures/mock-stream-triggered.jsonl tests/integration/fixtures/mock-stream-no-trigger.jsonl
git commit -m "$(cat <<'EOF'
feat(voice-review): run-eval.js with mock-stream mode

Parses claude -p --include-partial-messages stream JSONL, detects skill
activation via content_block_start + tool_use name match, captures
durationMs + totalTokens from the terminal result event. Mock-stream
mode unblocks CI without needing claude on PATH. Production mode
(real subprocess) lands in Task 10.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: `run-eval.js` production mode (real `claude -p` subprocess)

**Files:**
- Modify: `skills/skill-voice-review/scripts/run-eval.js`

- [ ] **Step 1: Extend run-eval.js to spawn `claude -p`**

Replace the `fail("production mode not implemented...")` line in `run-eval.js` with a real subprocess path. Also import `spawn` from `node:child_process`.

Add at the top (with the other imports):

```javascript
import { spawn } from "node:child_process";
```

Replace the mock-vs-prod branch with:

```javascript
let streamLines;
let mock = false;
if (args["mock-stream-file"]) {
  mock = true;
  streamLines = readFileSync(args["mock-stream-file"], "utf8").split("\n");
} else {
  const claudeArgs = [
    "-p", args.query,
    "--include-partial-messages",
    "--output-format", "stream-json",
  ];
  if (args.model) claudeArgs.push("--model", args.model);
  const child = spawn("claude", claudeArgs, {
    cwd: args["skill-path"],
    env: process.env,
  });
  let buf = "";
  child.stdout.setEncoding("utf8");
  await new Promise((resolve, reject) => {
    child.stdout.on("data", (chunk) => { buf += chunk; });
    child.on("error", reject);
    child.on("close", resolve);
  });
  streamLines = buf.split("\n");
}
```

(Add `import process from "node:process";` at the top if needed for `process.env`.)

- [ ] **Step 2: Manual smoke-test**

If `claude` is on PATH, run (on a throwaway skill):

```bash
node skills/skill-voice-review/scripts/run-eval.js \
  --skill-path /tmp \
  --skill-name nonexistent \
  --query "this should not trigger anything"
```

Expected: `triggered=false`, a non-zero `durationMs`, no error. If `claude` is not on PATH, skip this step; the mock-mode test from Task 9 still passes.

- [ ] **Step 3: Run the full suite**

```bash
bash tests/run-tests.sh
```

Expect: all tests from Task 9 still pass. No new test required — production-mode behaviour is environment-dependent.

- [ ] **Step 4: Commit**

```bash
git add skills/skill-voice-review/scripts/run-eval.js
git commit -m "$(cat <<'EOF'
feat(voice-review): run-eval.js production mode

Spawns `claude -p --include-partial-messages --output-format stream-json`
with the skill-path as cwd, streams stdout, analyses the JSONL with the
same activation detector used in mock mode. Mock mode remains the
CI-safe path; production mode activates when --mock-stream-file is
absent.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: `aggregate-benchmark.js` (TDD)

**Files:**
- Create: `skills/skill-voice-review/scripts/aggregate-benchmark.js`
- Create: `tests/integration/test-aggregate-benchmark.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/integration/test-aggregate-benchmark.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AGG="${HERE}/skills/skill-voice-review/scripts/aggregate-benchmark.js"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Three baseline runs: all triggered, tokens 100/120/140, durations 1000/1200/1400
# Three candidate runs: all triggered, tokens  80/ 90/100, durations  800/ 900/1000
cat > "${tmp}/runs.jsonl" <<'EOF'
{"ref":"baseline","caseId":1,"triggered":true,"totalTokens":100,"durationMs":1000}
{"ref":"baseline","caseId":1,"triggered":true,"totalTokens":120,"durationMs":1200}
{"ref":"baseline","caseId":1,"triggered":true,"totalTokens":140,"durationMs":1400}
{"ref":"candidate","caseId":1,"triggered":true,"totalTokens":80,"durationMs":800}
{"ref":"candidate","caseId":1,"triggered":true,"totalTokens":90,"durationMs":900}
{"ref":"candidate","caseId":1,"triggered":true,"totalTokens":100,"durationMs":1000}
EOF

out="$(node "$AGG" --runs "${tmp}/runs.jsonl")"

# Invariant: baseline mean tokens = 120 (100+120+140)/3.
[[ "$(printf '%s' "$out" | jq '.baseline.meanTokens')" == "120" ]] || { echo "FAIL: baseline.meanTokens"; exit 1; }
# Invariant: candidate mean tokens = 90.
[[ "$(printf '%s' "$out" | jq '.candidate.meanTokens')" == "90" ]] || { echo "FAIL: candidate.meanTokens"; exit 1; }
# Invariant: pass rates = 1.0.
[[ "$(printf '%s' "$out" | jq '.baseline.passRate')" == "1" ]] || { echo "FAIL: baseline.passRate"; exit 1; }
[[ "$(printf '%s' "$out" | jq '.candidate.passRate')" == "1" ]] || { echo "FAIL: candidate.passRate"; exit 1; }
# Invariant: delta.meanTokens = -30 (candidate - baseline).
[[ "$(printf '%s' "$out" | jq '.delta.meanTokens')" == "-30" ]] || { echo "FAIL: delta.meanTokens"; exit 1; }

echo "PASS: aggregate-benchmark"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/integration/test-aggregate-benchmark.sh`
Expect: failure.

- [ ] **Step 3: Write the aggregator**

Create `skills/skill-voice-review/scripts/aggregate-benchmark.js`:

```javascript
#!/usr/bin/env node
// Invariant: consumes a JSONL file of run-eval outputs tagged with a `ref` field; emits one aggregate JSON object to stdout.
// Invariant: refs are the literal strings "baseline" and "candidate"; any other ref is a schema violation.

import { readFileSync } from "node:fs";
import { argv, exit, stderr, stdout } from "node:process";

function parseArgs(args) {
  const out = {};
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith("--")) {
      out[args[i].slice(2)] = args[i + 1];
      i++;
    }
  }
  return out;
}

function fail(msg, code = 65) {
  stderr.write(`aggregate-benchmark: ${msg}\n`);
  exit(code);
}

function mean(nums) {
  if (nums.length === 0) return 0;
  return nums.reduce((a, b) => a + b, 0) / nums.length;
}

function stddev(nums) {
  if (nums.length < 2) return 0;
  const m = mean(nums);
  return Math.sqrt(mean(nums.map((n) => (n - m) ** 2)));
}

function stats(runs) {
  const passed = runs.filter((r) => r.triggered).length;
  const tokens = runs.map((r) => r.totalTokens ?? 0);
  const durations = runs.map((r) => r.durationMs ?? 0);
  return {
    runs: runs.length,
    passRate: runs.length === 0 ? 0 : passed / runs.length,
    meanTokens: mean(tokens),
    stddevTokens: stddev(tokens),
    meanDurationMs: mean(durations),
    stddevDurationMs: stddev(durations),
  };
}

const args = parseArgs(argv.slice(2));
if (!args.runs) fail("--runs <jsonl-file> required", 64);

const lines = readFileSync(args.runs, "utf8").split("\n").filter((l) => l.trim());
const all = lines.map((l, i) => {
  try { return JSON.parse(l); }
  catch { fail(`line ${i + 1} is not valid JSON`); }
});
for (const r of all) {
  if (r.ref !== "baseline" && r.ref !== "candidate") {
    fail(`unexpected ref: ${r.ref}`);
  }
}

const baseline = stats(all.filter((r) => r.ref === "baseline"));
const candidate = stats(all.filter((r) => r.ref === "candidate"));

stdout.write(JSON.stringify({
  baseline,
  candidate,
  delta: {
    passRate: candidate.passRate - baseline.passRate,
    meanTokens: candidate.meanTokens - baseline.meanTokens,
    meanDurationMs: candidate.meanDurationMs - baseline.meanDurationMs,
  },
}) + "\n");
```

- [ ] **Step 4: Run the test**

```bash
bash tests/integration/test-aggregate-benchmark.sh
```

Expect: `PASS: aggregate-benchmark`.

- [ ] **Step 5: Commit**

```bash
git add skills/skill-voice-review/scripts/aggregate-benchmark.js tests/integration/test-aggregate-benchmark.sh
git commit -m "$(cat <<'EOF'
feat(voice-review): aggregate-benchmark.js folds runs to stats

Consumes the JSONL of run-eval outputs tagged by ref, emits
pass-rate + mean/stddev for tokens and duration per ref, plus a
delta block. Rejects any ref outside {baseline, candidate}.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 12: End-to-end integration test (mock-stream pipeline)

**Files:**
- Create: `tests/integration/test-engine-end-to-end.sh`

- [ ] **Step 1: Write the test**

Create `tests/integration/test-engine-end-to-end.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INIT="${HERE}/skills/skill-voice-review/scripts/benchmark-plan-init.sh"
RUN="${HERE}/skills/skill-voice-review/scripts/run-eval.js"
AGG="${HERE}/skills/skill-voice-review/scripts/aggregate-benchmark.js"
SCOPE="${HERE}/tests/integration/fixtures/sample-scope.json"
HIT="${HERE}/tests/integration/fixtures/mock-stream-triggered.jsonl"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Invariant: benchmark-plan-init produces a plan whose cases + assertions drive the run-eval + aggregate pipeline without any hand-editing.

cat > "${tmp}/eval.json" <<'EOF'
{"skillName":"my-skill","cases":[{"id":1,"query":"do the thing","shouldTrigger":true,"note":"n"}]}
EOF
cat > "${tmp}/assert.json" <<'EOF'
{"skillName":"my-skill","assertions":[{"id":1,"type":"gate-function-question","pattern":"BEFORE X: \"Y?\"","evidence":"e"}]}
EOF

bash "$INIT" \
  --scope "$SCOPE" \
  --eval-set "${tmp}/eval.json" \
  --assertions "${tmp}/assert.json" \
  --baseline-ref HEAD \
  --candidate-ref working-copy \
  --baseline-path "${tmp}/b" \
  --candidate-path "${tmp}/c" \
  --out-dir "${tmp}/plan"

PJSON="${tmp}/plan/benchmark-plan.json"
[[ -f "$PJSON" ]] || { echo "FAIL: no benchmark-plan.json"; exit 1; }

# Drive the case through run-eval mock mode for each ref; tag with ref; write to runs.jsonl.
: > "${tmp}/runs.jsonl"
for ref in baseline candidate; do
  node "$RUN" --skill-path "${tmp}/${ref:0:1}" --skill-name my-skill --query "do the thing" --mock-stream-file "$HIT" \
    | jq --arg ref "$ref" --argjson caseId 1 '. + {ref:$ref, caseId:$caseId}' \
    >> "${tmp}/runs.jsonl"
done

lines="$(wc -l < "${tmp}/runs.jsonl" | tr -d ' ')"
[[ "$lines" == "2" ]] || { echo "FAIL: runs.jsonl should have 2 lines, got $lines"; exit 1; }

agg="$(node "$AGG" --runs "${tmp}/runs.jsonl")"
[[ "$(printf '%s' "$agg" | jq '.baseline.passRate')" == "1" ]] || { echo "FAIL: baseline.passRate"; exit 1; }
[[ "$(printf '%s' "$agg" | jq '.candidate.passRate')" == "1" ]] || { echo "FAIL: candidate.passRate"; exit 1; }

echo "PASS: engine end-to-end"
```

- [ ] **Step 2: Run the test**

```bash
bash tests/integration/test-engine-end-to-end.sh
```

Expect: `PASS: engine end-to-end`.

- [ ] **Step 3: Run the full suite**

```bash
bash tests/run-tests.sh
```

Expect: 30/30 pass (Plan 4 landed at 23; Plan 5 adds 7 new tests: worktree-setup, integrity-hash, plan-init, run-eval mock, aggregate, engine end-to-end, plus any extras).

- [ ] **Step 4: Commit**

```bash
git add tests/integration/test-engine-end-to-end.sh
git commit -m "$(cat <<'EOF'
test(engine): end-to-end mock-stream pipeline

Wires benchmark-plan-init → run-eval (mock mode) → aggregate into
one test that verifies the engine contract holds without touching
claude, git worktrees, or the network.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 13: README + `plan-5-complete` tag

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Append a "Benchmark engine" section to README**

Append to `README.md`:

```markdown
## Benchmark engine

Plan 5 ships the runtime that consumes the eval and assertion skeletons emitted by `/skill-scope` and `/skill-design` and produces enriched per-skill benchmark results.

Components in `skills/skill-voice-review/`:

- `scripts/git-worktree-setup.sh` — materializes baseline + candidate worktrees at `.skill-cheat/worktrees/<run-id>/{baseline,candidate}/`.
- `scripts/benchmark-plan-init.sh` — writes `benchmark-plan.json` + `benchmark-plan.md` (with Integrity Block) + SHA-256 sidecar from scope.json + eval-set + assertion-skeleton + refs.
- `scripts/benchmark-integrity-hash.sh` — companion hasher for benchmark-plan.md's integrity block.
- `scripts/run-eval.js` / `run-eval.sh` — spawns `claude -p --include-partial-messages`, watches the JSONL stream for skill activation (`content_block_start` with matching tool_use name), emits `{triggered, durationMs, totalTokens, streamEvents}`. Mock-stream mode (`--mock-stream-file`) unblocks CI.
- `scripts/aggregate-benchmark.js` — folds N run-eval outputs into pass-rate + mean/stddev tokens + mean/stddev duration per ref, plus delta.
- `agents/grader.md` / `comparator.md` / `analyzer.md` — subagent prompts (ported from [anthropics/skills](https://github.com/anthropics/skills) under Apache 2.0; see `/NOTICE`).

Plan 6 wires `/skill-voice-review` phase 3 to this engine and adds the Node dashboard UI (mirrors model_trainer/report's `dashboard/` layout).
```

- [ ] **Step 2: Final full-suite run**

```bash
bash tests/run-tests.sh
```

Expect: all Plan 5 tests pass, bootstrap self-audit still green.

- [ ] **Step 3: Commit + tag**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
chore: Plan 5 benchmark engine complete

Ships the runtime (git-worktree-setup, benchmark-plan-init, run-eval.js
with mock + production modes, aggregate-benchmark.js) plus the three
ported subagent prompts. Plan 6 wires this into voice-review phase 3
and adds the Node dashboard.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
git tag plan-5-complete
```

---

## Self-Review

**Spec coverage:**
- "Port grader/comparator/analyzer" → Tasks 2, 3, 4. ✓
- "Apache 2.0 attribution preserved" → Task 1 (NOTICE) + header comment in each of 2, 3, 4. ✓
- "git-worktree-setup.sh for isolation" → Task 5. ✓
- "benchmark-plan.json with Integrity Block + SHA-256" → Tasks 6 + 7. ✓
- "run-eval.js stream-watch" → Tasks 9 + 10 (mock + production). ✓
- "aggregate-benchmark.js" → Task 11. ✓
- "Integration test end-to-end" → Task 12. ✓
- "README documents the engine" → Task 13. ✓
- "voice-review phase 3 integration" → explicitly deferred to Plan 6. ✓
- "Node dashboard" → explicitly deferred to Plan 6. ✓

**Placeholder scan:** every step has concrete code or a concrete command. No "TBD", "implement later", or "similar to Task N". ✓

**Type consistency:**
- `run-eval.js` output fields: `skillName`, `query`, `triggered`, `durationMs`, `totalTokens`, `streamEvents`, `mock` — used identically in Tasks 9, 10, 12.
- `aggregate-benchmark.js` output fields: `baseline/candidate` each with `{runs, passRate, meanTokens, stddevTokens, meanDurationMs, stddevDurationMs}`, plus `delta` — consistent across Tasks 11 and 12.
- `benchmark-plan.json` shape matches Plan 4's `benchmark-plan-schema.md` (verified in Task 7 test invariants).
- Exit codes (64 = usage, 65 = schema, 66 = file, 67 = git) used consistently in Tasks 5, 6, 7, 9, 11.

**Known risks / tradeoffs:**
- Task 10's production mode depends on `claude` being on PATH at runtime. The mock-mode test in Task 9 is the always-green gate; production mode is smoke-tested manually.
- Task 12's end-to-end test runs the engine through mock mode only; it does not materialize real worktrees or call a real claude. That's a deliberate scope boundary — real-worktree integration lands in Plan 6's voice-review phase 3 wiring.

# D-benchmark-engine-flow

Companion note for `D-benchmark-engine-flow.png` — the Plan 5 benchmark engine in skill-cheat.

## What the engine does

The benchmark engine is the behavioural-evaluation layer that sits downstream of `skill-scope` and `skill-design`. It takes an already-scoped, already-designed skill and answers one question with numbers: *does the candidate revision actually behave better than the baseline?* It does so in four phases, each with its own artefacts and its own failure domain.

**Phase 0 (seeding)** turns declarative upstream inputs into testable skeletons. `emit-eval-skeleton.sh` reads `scope.json`, walks `.triggers[]`, and writes one `shouldTrigger: true` positive per trigger plus five `shouldTrigger: false` adversarial placeholders (trigger-collision, instruction-injection, degenerate-prompt, keyword-without-context, cross-skill-ambiguity) — the set is derived from published prompt-injection literature. `emit-assertion-skeleton.sh` reads `design.json` and emits `hard-gate-violation-absent` assertions per `hardGates[]` plus `gate-function-question` assertions per `gateFunctions[]`.

**Phase 1 (plan init)** is where the run becomes reproducible. `benchmark-plan-init.sh` writes `benchmark-plan.md` with an explicit integrity block (`skillName`, `baselineRef`, `candidateRef`, `caseQueries[]`, `assertionPatterns[]`) bracketed by `<!-- integrity-block:start -->` / `<!-- integrity-block:end -->` markers. `benchmark-integrity-hash.sh` then awk-extracts the byte range *strictly between* those markers (the markers themselves never enter the hash) and writes a 64-hex-char SHA-256 sidecar. That digest is embedded into `benchmark-plan.json`'s `integrityBlock.sha256`. In parallel, `git-worktree-setup.sh` materialises two detached worktrees under `<root>/<run-id>/{baseline,candidate}/` — and always `baseline` first, because every other stage reads them in that order and the plan-as-log schema enforces `baselineRef` before `candidateRef`.

**Phase 2 (per-case execution)** iterates `cases × {baseline, candidate} × N samples` and dispatches `run-eval.js`. The script forks on one flag. In **mock** mode (`--mock-stream-file`), a pre-recorded JSONL fixture is `readFileSync`'d — this is what CI uses, because it is free and deterministic. In **production** mode, the script `spawn`s `claude -p --include-partial-messages --output-format stream-json` with `cwd` set to the worktree skill path. Both lanes converge on `analyseStream()`, which does a single thing that matters: it looks for a `stream_event` whose `content_block_start` is a `tool_use` with `input.name === skillName`. That one match sets `triggered = true`. A `result/success` event contributes `durationMs` and `totalTokens`. Each run emits one line of JSON tagged with `ref`.

**Phase 3 (aggregation + grading)** folds the JSONL. `aggregate-benchmark.js` partitions by `ref` (any ref that is not literally `"baseline"` or `"candidate"` is a schema violation and exits 65) and produces `{runs, passRate, meanTokens, stddevTokens, meanDurationMs, stddevDurationMs}` per side plus a `delta` block. Then three subagents dispatch: **grader** reads transcripts + assertions and returns tri-state `PASS / FAIL / NEEDS_CONTEXT` per assertion with concrete evidence; **comparator** does a blind A/B judgement — it *must not* know which output came from which ref and is required to STOP if it can infer the mapping; **analyzer** unblinds the comparator, reads both SKILL.md files, and attributes the win to specific skill-text differences.

## Why worktree isolation + SHA-256 are load-bearing

Worktrees guarantee that baseline and candidate runs cannot bleed state. No shared scratch, no shared settings, no "oh, the candidate saw the baseline's cache." The SHA-256 over the integrity block is the anti-drift contract: if any of `skillName`, `baselineRef`, `candidateRef`, the case queries, or the assertion patterns are silently edited mid-run, the digest changes and any stage that re-verifies will halt. Integrity violation = STOP.

## Structural distrust

The three subagents are not redundant — they are adversarial by construction. Grader cannot judge quality; comparator cannot see origins; analyzer cannot overturn the verdict. No single agent holds all of (assertions, blind outputs, skill texts). That separation makes it structurally hard for one judgement to contaminate another.

## Mode split pays for CI

The `--mock-stream-file` path exists precisely so that pull-request CI can replay a recorded stream and verify the analysis logic, the aggregation maths, and the plan schema without ever spawning the real Claude CLI. Production runs flip one flag.

# B — Hook & Trigger Dispatch Flow

Companion to `B-trigger-dispatch-flow.png` / `.dot`. Canvas: 17×11 in landscape @ 300 dpi (~5196×3510 px), built for iPad pinch-zoom along swimlanes.

## What the diagram shows

The atlas traces every path by which skill-cheat self-triggers and ultimately routes a prompt into the 5-stage pipeline. Three coloured entry paths on the left converge on Claude's context window in the middle, then fan out right into the five slash commands and the five stage skills they load. Read it left-to-right as time; read top-to-bottom as entry path.

**Entry A (blue) — cold SessionStart.** The harness fires on `startup | clear | compact` (yellow diamond matcher node). `hooks/session-start` reads `skills/using-skill-cheat/SKILL.md` and pipes it through `lib/emit-context.sh`, which `jq`-builds the envelope `{hookSpecificOutput:{hookEventName:"SessionStart", additionalContext:"<body>"}}` on stdout. The harness merges that into Claude's context before the first turn.

**Entry B (orange) — every user prompt.** `UserPromptSubmit` has no matcher, so `hooks/user-prompt-submit` runs for every submission. It reads JSON stdin, extracts `.prompt` with `jq`, sources `config.sh` (with the project-local `.skill-cheat.sh` override check next to it), then calls `detect_skill_intent` which lowercases both sides and substring-matches each keyword. On hit, it emits the same envelope shape but with an "INTENT DETECTED" reminder. On miss, the dashed grey silent-fallthrough branch shows the prompt reaching Claude unadorned — no additionalContext, no error, `trap 'exit 0' ERR` eating any failure.

**Entry C (green) — explicit slash.** `/skill-scope` and siblings bypass intent detection entirely: each `commands/*.md` file is a one-line wrapper that tells Claude to "Invoke the `skill-cheat:skill-<stage>` skill." (A dotted green edge shows that slash input still traverses `UserPromptSubmit` — it just wouldn't match a keyword.)

All three paths land on the Claude-context cluster, where the `using-skill-cheat` bootstrap (already resident from path A) plus the optional INTENT reminder (from path B) constrain the decision node. The HARD-GATE routing forces skill-authoring intent through `/skill-scope`, and pipeline chaining edges show how verdicts (`SCOPE_LOCKED → DESIGN_LOCKED → AUTHOR_DONE → ACCEPT → SCAFFOLD_COMPLETE`) walk downstream. Only `skill-scaffold` writes to disk — the cylinder on the far right.

## Key insights

1. **Self-triggering is a two-layer lock.** The bootstrap (`using-skill-cheat`) is the persistent rule; the UserPromptSubmit hook is the just-in-time re-reminder. Either alone would work; together they make skipping `/skill-scope` nearly impossible.
2. **Both hooks emit the same envelope shape.** Even though the orange path fires on `UserPromptSubmit`, the JSON it writes still names `"hookEventName": "SessionStart"` — the plugin deliberately piggybacks on SessionStart's additionalContext channel.
3. **The silent path is load-bearing.** `trap 'exit 0' ERR`, `|| true` on `jq`, and unconditional `exit 0` on missing bootstrap guarantee the plugin never blocks a user's prompt. Failure mode is invisibility, not error.
4. **Config override is last-writer-wins.** `config.sh` ships defaults, then `.skill-cheat.sh` (if present in `$CLAUDE_PROJECT_DIR`) is sourced after it, redefining `SKILL_CHEAT_TRIGGER_KEYWORDS` / `SKILL_CHEAT_WORK_DIR` without the plugin needing to know the project exists.
5. **Slash commands and hook triggers converge, they don't compete.** The same five stage skills are reachable via explicit slash OR via Claude following the bootstrap's routing rule after a keyword match. The `rank=same` row for commands and the row for stage skills makes this convergence visually obvious.

## What the reader should take away

skill-cheat does not police the user — it rigs the context. SessionStart plants the rule; UserPromptSubmit re-surfaces it exactly when a keyword appears; slash commands offer a clean fast-path for users who already know the pipeline. The hook runtime is deliberately dumb (shell + `jq`), the intelligence sits in Claude's interpretation of the injected bootstrap. That is what "hooks make the plugin self-triggering" means in practice: no agent code, just a reliable whisper at the right moment.

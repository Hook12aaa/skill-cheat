# Trigger Vocabulary

Every skill declares its triggers and verdicts. This reference names the vocabulary.

## Trigger kinds

- **Slash command** — the explicit user-invoked command (`/skill-scope`). Every pipeline skill MUST declare one.
- **Keyword** — a phrase in user prose that fires a SessionStart or UserPromptSubmit hook. Optional; only for gates that must never be missed.
- **Upstream verdict** — the skill fires when the prior stage emits a specific token (e.g., `/skill-design` fires when `/skill-scope` emits `SCOPE_LOCKED`).

## Verdict tokens

Verdict tokens are ALL-CAPS single words or underscore-joined compounds. Emit at stage exit on a line prefixed `VERDICT:`.

### Common token shapes

- `<VERB>_LOCKED` — a stage produced an immutable artifact (e.g., `SCOPE_LOCKED`, `DESIGN_LOCKED`).
- `<VERB>_DONE` — a stage finished its work (e.g., `AUTHOR_DONE`).
- `ACCEPT` / `REJECT_CRITICAL` / `REJECT_IMPORTANT` / `ACCEPT_WITH_MINOR` / `INCONCLUSIVE` — voice-review verdicts.
- `SCAFFOLD_COMPLETE` / `SCAFFOLD_INCOMPLETE` — scaffold-stage verdicts.
- `BLOCKED_<REASON>` — escalate to human (e.g., `BLOCKED_REVIEWER`, `BLOCKED_TAMPER`, `BLOCKED_VOICE`, `BLOCKED_NEEDS_USER`).

### Verdict ladder (for voice-review aggregation)

```
any CRITICAL   → REJECT_CRITICAL
else IMPORTANT → REJECT_IMPORTANT
else MINOR     → ACCEPT_WITH_MINOR
else           → ACCEPT
```

## Naming rule

Verdicts from DIFFERENT stages MUST NOT collide. Prefix with a stage verb when ambiguity is possible (`SCOPE_LOCKED`, not just `LOCKED`).

## Description-authoring pattern

The frontmatter `description` is where triggers live. Write it as a short pushy paragraph, not a summary. Three moves per description:

1. Verdict sentence — name the stage, the slash command, and the VERDICT tokens the skill emits.
2. `Use when...` sentence — list 3-4 real user phrasings in quotes.
3. Contract sentence — name the upstream verdict this skill waits on and what it produces.

### User-phrasing examples

Phrase triggers as things users actually type, in quotes:

- `"I want to build a skill for X"`
- `"scaffold a new plugin"`
- `"turn this into a skill"`
- `"lock the scope before we design"`

Claude matches on literal phrasings when the user prose mirrors the description. Generic verbs (`make`, `build`, `do`) dilute coverage — pair them with a noun the skill owns.

### Terse vs pushy

Take `/skill-scope`. Terse form:

> Trigger /skill-scope. Stage 1 of the pipeline. Locks skill name, trigger vocabulary, verdict tokens, Anti-Pattern, and target project path before any design work. Emits SCOPE_LOCKED, SCOPE_INCOMPLETE, or BLOCKED_NEEDS_USER.

Pushy form:

> Stage 1 of the skill-cheat pipeline. Trigger /skill-scope. Use this skill whenever the user says "I want to build a skill for X", "scaffold a new plugin", "turn this into a skill", or "lock the scope before we design". Locks skill name, trigger vocabulary, verdict tokens, Anti-Pattern, and target project path before any design work. Emits SCOPE_LOCKED, SCOPE_INCOMPLETE, or BLOCKED_NEEDS_USER.

The pushy form catches near-miss phrasings. The terse form under-triggers and forces the user to name the slash command.

## Rationalization Table

| You think... | Reality |
|---|---|
| "`/do` or `/run` is fine — users will know what it means" | Reject one-verb slash commands. Name the command after the stage (`/skill-scope`), not the action. |
| "A big keyword list catches more intents — add `build`, `make`, `create`" | Strip generic verbs. Keyword triggers fire hooks; an overbroad list drags unrelated prompts into the gate. Lock the list to phrases that cannot plausibly mean anything else. |
| "`locked` reads cleaner than `SCOPE_LOCKED` in the log" | Reject lowercase verdicts. Emit ALL-CAPS tokens prefixed with the stage verb so the downstream regex matches exactly one stage. |
| "The description is metadata — keep it short and factual" | Write a pushy description. Name trigger phrasings in quotes and include every verdict token. Terse descriptions under-trigger. |

## Red Flags

- "Let's just call it `/do`"
- "Add `build` and `make` to the trigger list"
- "Lowercase verdicts read cleaner"
- "We can skip the slash command — the keyword alone will fire it"

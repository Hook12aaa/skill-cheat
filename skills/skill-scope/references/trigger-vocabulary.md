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

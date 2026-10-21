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

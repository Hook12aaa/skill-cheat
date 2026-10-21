# Plugin Skeleton

The canonical tree a new plugin scaffold emits. Used by `/skill-scaffold` to know what files to write.

## New-plugin tree (emitted when scope declares "new plugin")

```
<target-root>/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── CLAUDE.md
├── README.md
├── config.sh
├── hooks/
│   ├── hooks.json
│   ├── session-start
│   ├── user-prompt-submit           (only if scope declares keyword triggers)
│   └── lib/
│       ├── emit-context.sh
│       └── detect-skill-intent.sh   (only if scope declares keyword triggers)
├── skills/
│   ├── using-<plugin-name>/
│   │   └── SKILL.md                 (bootstrap)
│   └── <authored-skill-name>/
│       └── SKILL.md                 (the skill authored by this pipeline run)
├── commands/
│   └── <authored-skill-name>.md     (slash stub invoking the authored skill)
└── tests/
    ├── run-tests.sh
    └── hooks/
        ├── test-session-start.sh
        └── test-user-prompt-submit.sh   (only if keyword triggers declared)
```

## Existing-plugin delta (emitted when scope declares "existing plugin")

Only these files are written; the rest of the tree is assumed present:

- `skills/<authored-skill-name>/SKILL.md`
- `commands/<authored-skill-name>.md`
- One line appended to `skills/using-<plugin-name>/SKILL.md`'s Available Skills table.

## File type allowlist

Every file the scaffold writes MUST have extension `.md`, `.js`, `.sh`, or `.json`. Refuse to write anything else.

## Overwrite rule

If `.claude-plugin/plugin.json` already exists at the target path, STOP and ask the user whether to overwrite. Do NOT silently clobber.

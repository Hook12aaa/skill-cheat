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

## `skills/<authored-skill-name>/SKILL.md` frontmatter template

The scaffold emits authored SKILL.md files with a pushy description. Name the stage, list user phrasings in quotes, and include every VERDICT token.

```
---
name: <authored-skill-name>
description: <One-sentence role statement>. Trigger /<slash-command>. Use this skill whenever the user says "<phrasing 1>", "<phrasing 2>", or "<phrasing 3>". <One-sentence contract — what this skill waits on and what it produces>. Emits <VERDICT_TOKEN_1>, <VERDICT_TOKEN_2>, or <BLOCKED_TOKEN>.
---
```

Substitute every `<placeholder>` before writing. The description MUST name at least one ALL-CAPS verdict token and at least one quoted user phrasing. Terse descriptions ship broken triggering.

## File type allowlist

Every file the scaffold writes MUST have extension `.md`, `.js`, `.sh`, or `.json`. Refuse to write anything else.

## Overwrite rule

If `.claude-plugin/plugin.json` already exists at the target path, STOP and ask the user whether to overwrite. Do NOT silently clobber.

## Rationalization Table

| You think... | Reality |
|---|---|
| "SessionStart hook is optional — the bootstrap can load on demand" | Emit the SessionStart hook. Without it the bootstrap never reaches context and the plugin is inert. |
| "I'll leave `<PLUGIN_NAME>` in the manifest; the author will fill it in later" | Substitute every token before writing. Unsubstituted placeholders ship broken plugins. |
| "The directory is called `skill` — same thing, shorter" | Name the directory `skills/`. The singular form is not discovered and the plugin loads nothing. |

## Red Flags

- "Let me drop a .py helper next to the hook"
- "I'll commit the .env so the reviewer can reproduce"
- "Adding a top-level PLUGIN_SPEC.yaml for clarity"
- "Placeholder TODO in plugin.json is fine for now"

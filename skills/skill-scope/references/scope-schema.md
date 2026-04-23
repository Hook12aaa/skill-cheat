# scope.json schema

`scope.json` is the machine-parseable twin of `scope.md`. Both files land in
`docs/skill-cheat/skills-in-progress/<skill-name>/` at Step 6 of /skill-scope.
Downstream stages (design, voice-review, scaffold) read `scope.json`, not `scope.md`.

## Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `schemaVersion` | string | yes | Literal `"1.0"`. |
| `name` | string | yes | Skill identifier, kebab-case. |
| `slashCommand` | string | yes | Primary slash command, starts with `/`. |
| `triggers` | array | yes | At least one entry. Each `{kind, value}`. |
| `triggers[].kind` | string | yes | One of `slash`, `phrase`, `upstream-verdict`. |
| `triggers[].value` | string | yes | The literal trigger string. |
| `verdicts` | array[string] | yes | ALL-CAPS verdict tokens emitted at exit. |
| `antiPattern` | string | yes | First-sentence quoted-phrase from Anti-Pattern section. |
| `targetPath` | string | yes | Absolute path to the target project. |
| `pluginMode` | string | yes | `new` or `existing`. |

## Example

```json
{
  "schemaVersion": "1.0",
  "name": "my-skill",
  "slashCommand": "/my-skill",
  "triggers": [
    {"kind": "slash", "value": "/my-skill"},
    {"kind": "phrase", "value": "I want to build X"}
  ],
  "verdicts": ["READY", "REJECTED", "BLOCKED_NEEDS_USER"],
  "antiPattern": "\"I can skip this step because X\"",
  "targetPath": "/Users/hook/projects/foo",
  "pluginMode": "new"
}
```

## Invariants

- `slashCommand` MUST equal the first `triggers[]` entry with `kind == "slash"`.
- `antiPattern` MUST contain a double-quoted phrase (downstream lint enforces).
- `verdicts` length >= 2 (at least one happy + one reject/blocked token).

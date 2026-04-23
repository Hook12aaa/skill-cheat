# design.json schema

`design.json` is the machine-parseable twin of `design.md`. Both files land in
`docs/skill-cheat/skills-in-progress/<skill-name>/` at the end of /skill-design.
Downstream stages (voice-review, scaffold) read `design.json`, not `design.md`.

## Fields

| Field | Type | Required | Description |
|---|---|---|---|
| `schemaVersion` | string | yes | Literal `"1.0"`. |
| `hardGates` | array | yes | At least 1 entry. Each `{id, body}`. |
| `hardGates[].id` | integer | yes | 1-indexed ordinal. |
| `hardGates[].body` | string | yes | Full text between `<HARD-GATE>` and `</HARD-GATE>`. |
| `gateFunctions` | array | yes | Each `{before, question}`. |
| `gateFunctions[].before` | string | yes | Predicate after `BEFORE `, before `:`. |
| `gateFunctions[].question` | string | yes | Quoted question after `:`. |
| `antiPatternFirstSentence` | string | yes | First sentence of Anti-Pattern section. |
| `checklistSteps` | array[string] | yes | Ordered checklist item texts. |

## Example

```json
{
  "schemaVersion": "1.0",
  "hardGates": [
    {"id": 1, "body": "Do NOT proceed without a named scope. STOP and invoke /skill-scope."}
  ],
  "gateFunctions": [
    {"before": "asking questions", "question": "Am I about to ask more than one thing at once?"}
  ],
  "antiPatternFirstSentence": "\"I can skip the gate this once\" — every invocation goes through the gate.",
  "checklistSteps": [
    "Verify hard gates",
    "Load the next unstarted batch"
  ]
}
```

## Invariants

- `hardGates` count >= 1 (lint enforces this already via LINT-002).
- `gateFunctions[].question` MUST end with `?` and be double-quoted in source.
- `checklistSteps` order MUST match the SKILL.md `## Checklist` order (cross-reference lint).

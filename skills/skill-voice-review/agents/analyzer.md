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

---
name: using-skill-cheat
description: Bootstrap context for skill-cheat, auto-loaded at session start via SessionStart hook and never user-triggered. Stay in context whenever a user says "I want to build a skill", "let's make a new plugin", "scaffold a Claude Code skill", or "turn this workflow into a skill", and route every such request through skill-cheat's 5-stage pipeline starting with /skill-scope. Downstream stages return SCOPE_LOCKED, DESIGN_LOCKED, AUTHOR_DONE, ACCEPT, and SCAFFOLD_COMPLETE — only SCAFFOLD_COMPLETE writes a SKILL.md to disk.
---
<!-- design-region-clean-of-hard-gates -->

# Using skill-cheat

<HARD-GATE>
Do NOT write a SKILL.md without running /skill-scope first. STOP and invoke /skill-scope.
</HARD-GATE>

<HARD-GATE>
Do NOT write a SKILL.md until /skill-voice-review returns ACCEPT or ACCEPT_WITH_MINOR. STOP and rerun voice-review.
</HARD-GATE>

Treat every new skill as gated by skill-cheat. **Every skill ships through the 5-stage pipeline** before it is written to disk.

## The Rule

> **Contract-first, library-last. Imperative voice. ALL-CAPS verdicts. No hedges.**

Every skill specifies the shape of work (preconditions, verdicts, invariants), never which tools to use. Claude picks tools at target-project time.

## When to Invoke

Invoke `/skill-scope` **BEFORE** writing any new Claude Code skill, including:

- Any new SKILL.md file in any plugin.
- Any rewrite of an existing SKILL.md that changes its HARD-GATEs, Core Principle, or verdict vocabulary.
- Any "quick skill" for a one-off workflow — the pipeline is cheap; skipping it is expensive.

Skip the pipeline for: reference file edits, test fixtures, CLAUDE.md notes, documentation.

## Available Skills

| Skill | Trigger | Verdicts |
|---|---|---|
| skill-scope | `/skill-scope` | SCOPE_LOCKED, SCOPE_INCOMPLETE, BLOCKED_NEEDS_USER |
| skill-design | `/skill-design` | DESIGN_LOCKED, DESIGN_REJECTED, BLOCKED_REVIEWER |
| skill-author | `/skill-author` | AUTHOR_DONE, AUTHOR_INCOMPLETE, BLOCKED_TAMPER |
| skill-voice-review | `/skill-voice-review` | ACCEPT, ACCEPT_WITH_MINOR, REJECT_CRITICAL, REJECT_IMPORTANT, INCONCLUSIVE, BLOCKED_VOICE |
| skill-scaffold | `/skill-scaffold` | SCAFFOLD_COMPLETE, SCAFFOLD_INCOMPLETE, BLOCKED_OVERWRITE |
| receiving-voice-review | (internal) | — |

## Core Principles

1. **Contract-first, library-last.** Name the shape; Claude picks the tools at target-project time.
2. **Structural distrust.** No agent both produces and approves its own work.
3. **Integrity Block is immutable.** Stage 2 locks six fields; stages 3-5 re-verify SHA-256.
4. **Self-contained.** skill-cheat has zero plugin dependencies. Every pattern is written here, not referenced.

## Status Vocabulary

Verdicts are ALL-CAPS single words emitted on a line prefixed `VERDICT:`. See the stage table above for the full set.

## Red Flags

- "I'll just author a SKILL.md directly"
- "A simple one-off needs no pipeline"
- "Library names are just details"
- "Hedge words in HARD-GATEs are fine"
- "A HARD-GATE with a because clause reads better"

## The Bottom Line

Invoke `/skill-scope` before authoring any new skill. The pipeline returns a verdict. Only `SCAFFOLD_COMPLETE` writes files to disk.

```bash
echo "VERDICT: BOOTSTRAP_READY"
```

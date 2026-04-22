---
name: using-skill-cheat
description: Bootstrap context for the skill-cheat plugin. Auto-loaded at session start. Directs Claude to invoke /skill-scope before authoring any new Claude Code skill. Not a runtime-triggered skill — use the pipeline stages for the actual work.
---

# Using skill-cheat

Treat every new skill as gated by the skill-cheat pipeline. **Every skill ships through the 5-stage pipeline** before it is written to disk.

## The Rule

> **Contract-first, library-last. Imperative voice. ALL-CAPS verdicts. No hedges.**

Every skill specifies the shape of work (preconditions, verdicts, invariants), never which tools to use. Claude picks tools at target-project time.

## When to Invoke

Invoke `/skill-scope` **BEFORE** writing any new Claude Code skill, including:

- Any new SKILL.md file in any plugin.
- Any rewrite of an existing SKILL.md that changes its HARD-GATEs, Core Principle, or verdict vocabulary.
- Any "quick skill" for a one-off workflow — the pipeline is cheap; skipping it is expensive.

Skip the pipeline for: reference file edits, test fixtures, CLAUDE.md notes, documentation.

## Hard Stop Rule

**Do NOT write a SKILL.md until `/skill-voice-review` returns ACCEPT or ACCEPT_WITH_MINOR.** REJECT_CRITICAL or REJECT_IMPORTANT means the skill fails — fix or drop.

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

1. **Contract-first, library-last.** The skill names the shape; Claude picks the tools.
2. **Structural distrust.** No agent both produces and approves its own work.
3. **Integrity Block is immutable.** Stage 2 locks six fields; stages 3-5 re-verify SHA-256.
4. **Self-contained.** skill-cheat has zero plugin dependencies. Every pattern is written here, not referenced.

## Status Vocabulary

Verdicts are ALL-CAPS single words emitted on a line prefixed `VERDICT:`. See the stage table above for the full set.

## Red Flags

Stop and invoke `/skill-scope` the moment you notice any of these:

| Red flag | Why |
|---|---|
| "I'll just write the SKILL.md directly" | The pipeline exists to prevent exactly this. |
| "This skill is too simple for the full pipeline" | Simple skills are where unexamined assumptions cause the most drift. |
| Library or framework names in the SKILL.md body | Contract-first means never naming tools. |
| Hedge words in HARD-GATEs | Imperative voice only. |
| A HARD-GATE with a `because` clause | Rationale lives in prose, not in gates. |

## The Bottom Line

Before writing any new skill, invoke `/skill-scope`. The pipeline returns a verdict. Only SHIP — here, `SCAFFOLD_COMPLETE` — means the skill is written to disk.

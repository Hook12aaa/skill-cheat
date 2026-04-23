# Canonical Skill Anatomy

Every SKILL.md produced by this plugin must present these sections in this exact order.

## Frontmatter description

The `description` field is the primary triggering signal. Claude consults skills from a flat list keyed on `name` + `description` only. A terse one-liner under-triggers.

Push the description. Every description MUST:

- Name the stage in the pipeline (or the skill's role if non-pipeline).
- List real user phrasings that should fire it, in the form `Trigger /<cmd> whenever the user says "X", "Y", "Z"` or `Fire whenever the user says "X", "Y", "Z"`. AVOID the bigrams `the skill` and `this skill` — LINT-014 rejects those as third-person self-reference.
- Contain at least one ALL-CAPS verdict token the skill emits.
- Run 2-4x longer than a terse summary. Length buys trigger coverage.

### Before / after

Before (terse, under-triggers):

> Trigger /skill-author. Stage 3 of the pipeline. Fills SKILL.md body under the locked Integrity Block. Emits AUTHOR_DONE, AUTHOR_INCOMPLETE, or BLOCKED_TAMPER.

After (pushy, covers trigger surface):

> Stage 3 of skill-cheat's five-stage pipeline. Trigger /skill-author whenever the user says "author my SKILL.md", "fill in my SKILL.md body", "write my checklist and step details", or "finish my draft after design locked". Fills SKILL.md body under the locked Integrity Block once DESIGN_LOCKED is in hand. Emits AUTHOR_DONE, AUTHOR_INCOMPLETE, or BLOCKED_TAMPER.

### Triggers live in description, not in body

The canonical 13-section order below does NOT include `## Triggers`. Trigger phrasings belong in the `description` field. A body section labeled Triggers is documentation scaffold, not a triggering contract — Claude never reads body sections during trigger selection.

## Section order

1. YAML frontmatter (`name`, `description`).
2. H1 title matching the skill name.
3. `<HARD-GATE>` blocks — one or more, stacked immediately under the H1. Each block contains one or two imperative sentences, no rationale.
4. Anti-Pattern — names the quoted rationalization that would cause Claude to skip the skill. First sentence MUST contain a quoted phrase.
5. Core Principle — one sentence. Describes the shape of the work, never a library or framework.
6. Process Flow — a dot digraph that parses under `dot -Tcanon`. Every node must be reachable.
7. Checklist — numbered bullets. Backtracking allowed but must be explicit.
8. Step Details — per checklist item, numbered to match.
9. Gate Functions — every bullet matches `- BEFORE <action>: "<question>?"`.
10. Rationalization Table — two columns: `You think...` | `Reality`. Each row's Reality must be stricter than its You-think.
11. Red Flags — bulleted quoted fragments, no em-dash explanation tail.
12. Key Principles — bolded, imperative.
13. Bottom Line — imperative close, contains an executable fenced `bash` or `sh` block that prints a VERDICT token.

## Voice

- Imperative verb starts every prohibition: `Do NOT …`, `Never …`, `STOP and …`.
- Zero hedge words (see `hedge-words-denylist.json`).
- Zero library / framework names in the body (see `library-names-denylist.json`). Tool names live only in `references/`.
- Verdict tokens are ALL-CAPS single words. No verbose descriptions.

## What does NOT belong

- Prose rationale inside a `<HARD-GATE>` block.
- `because` / `since` / `in order to` inside a HARD-GATE.
- Third-person self-reference: "the skill", "this skill mandates", "skill deviation".
- Comments in JSON / JS / SH that describe history, intent, or personal notes.

## Rationalization Table

| You think... | Reality |
|---|---|
| "My skill is simple, Anti-Pattern is overkill." | Emit the Anti-Pattern section. The simpler the skill, the faster it gets skipped without the quoted rationalization. |
| "Core Principles (plural) reads better with three bullets." | Rename to Core Principle, singular, one sentence. Three bullets means three skills. Split or collapse. |
| "Process Flow is obvious for this trivial flow — I'll drop it." | Keep the digraph. "Trivial" is the author's view, not Claude's. Every section is mandatory. |

## Red Flags

- "My skill is simple"
- "Core Principles"
- "We can fold Rationalization Table into Red Flags"
- "Bottom Line first, it's the most important part"

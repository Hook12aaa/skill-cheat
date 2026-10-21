# Canonical Skill Anatomy

Every SKILL.md produced by this plugin must present these sections in this exact order.

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

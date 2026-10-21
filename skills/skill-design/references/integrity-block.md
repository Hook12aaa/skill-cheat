# The Integrity Block

A byte-exact delimited region inside a design document. Stages downstream of design re-hash the region and fail if it drifts.

## Delimiters

Exact strings, each on their own line, no leading or trailing whitespace.

- Start: `<!-- integrity-block:start -->`
- End: `<!-- integrity-block:end -->`

## Immutable fields (six, in this order)

1. `## Skill Name` — matches the SKILL.md frontmatter `name`.
2. `## Triggers` — slash command + any keyword triggers.
3. `## Verdict Vocabulary` — ALL-CAPS tokens the skill emits.
4. `## HARD-GATEs` — one per bullet, imperative (`Do NOT …`).
5. `## Core Principle` — one sentence.
6. `## Gate Functions` — one per bullet, `BEFORE <action>: "<question>?"` form.

Nothing else lives between the markers. Rationale, Red Flags, Rationalization Table, and prose discussion live OUTSIDE the markers elsewhere in the design document.

## SHA-256 sidecar

After the design document is saved, compute SHA-256 of the bytes **strictly between** the two marker lines (exclusive of the markers themselves), and write a sidecar file at `<design-path>.sha256`.

Sidecar format (one line):

```
<lowercase hex digest>  <basename>
```

Example:

```
a7981ec3c2b1d0f9e8...  design.md
```

## Verification contract

Every downstream stage calls `verify_integrity(design_path)` as its first action after confirming inputs exist.

```
if sidecar missing           → BLOCKED_TAMPER: sidecar absent
if start marker missing      → BLOCKED_TAMPER: start marker absent
if end marker missing        → BLOCKED_TAMPER: end marker absent
if either marker duplicated  → BLOCKED_TAMPER: marker not unique
computed = sha256(bytes between markers)
recorded = read sidecar
if computed != recorded      → BLOCKED_TAMPER: hash drift
return OK
```

## Anti-gaming

Two tamper patterns, both rejected by downstream stages:

1. Author re-hashes after editing in-block → voice-review cross-checks block contents against scope.md's declared triggers/verdicts. Divergence → REJECT_CRITICAL.
2. Author moves a HARD-GATE outside the markers to edit it freely → LINT-016 catches HARD-GATE blocks appearing in a design.md's editable region.

## Rendered SKILL.md does not retain markers

The scaffold stage inlines locked fields into canonical sections. The design.md + sidecar persist as the audit trail. Exception: skills that declare `authored-skill-has-its-own-runtime-integrity-block` in scope (e.g. ML-training skills that need per-run integrity) keep the markers in their rendered output.

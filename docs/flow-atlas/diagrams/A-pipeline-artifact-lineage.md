# A — Pipeline Artifact Lineage

Landscape 11×17 in at 300 dpi. Source: `A-pipeline-artifact-lineage.dot`. Render: `A-pipeline-artifact-lineage.png` (4562×2850 px).

## What the diagram shows

Five horizontal bands, one per pipeline stage — `skill-scope`, `skill-design`, `skill-author`, `skill-voice-review`, `skill-scaffold` — stacked top-to-bottom so the reader sees the full pipeline at a glance. Inside each band, the stage box sits on the left and everything it touches (emitters, subagents, on-disk artifacts, verdicts) flows left-to-right out of it. The happy path is a bold green chain of verdict batons (`SCOPE_LOCKED → DESIGN_LOCKED → AUTHOR_DONE → ACCEPT → SCAFFOLD_COMPLETE`) that crosses the bands vertically. Every `BLOCKED_*` escape is colored red and exits its stage sideways. Artifacts are drawn as note-shapes; scripts that emit artifacts (`emit-eval-skeleton.sh`, `emit-assertion-skeleton.sh`, `integrity-hash.sh`, `lint.sh`, `run-eval.js`) are drawn as component boxes; dispatched subagents use the 3-D box shape.

## Key insights

1. **scope.json is the keystone, not scope.md.** scope.md is the human trace; scope.json is what every downstream stage actually reads. It alone carries `plugin-mode` to Stage 5 and `skillName` to the Stage 4 benchmark engine. Edit scope.md by hand and you invalidate nothing; edit scope.json and the pipeline breaks.

2. **The SHA-256 integrity loop is a single thin red line.** Stage 2's `integrity-hash.sh` produces `design.md.sha256`. Stage 3's first action is to re-hash the bytes between the integrity-block markers and compare against that sidecar. Any drift drops straight into `BLOCKED_TAMPER` — the only BLOCKED state in the pipeline that is self-diagnosed by a cryptographic test rather than a heuristic.

3. **Two parallel "skeleton" emitters seed the benchmark engine.** `emit-eval-skeleton.sh` (Stage 1) writes `eval-set-skeleton.json`; `emit-assertion-skeleton.sh` (Stage 2) writes `assertion-skeleton.json`. Both feed into Stage 4's `run-eval.js` as `cases[]` and `assertions[]` respectively. Without either, the Plan-5 benchmark engine has nothing to run against.

4. **Voice-review's ACCEPT is a hard lock on Stage 5.** The red edge from Stage 5's `verdict == ACCEPT?` diamond to `SCAFFOLD_INCOMPLETE` is the single choke point between passing voice-review and shipping to disk. `ACCEPT_WITH_MINOR` is drawn looping back into Stage 4 because the scaffold stage rejects it as not-quite-ACCEPT and forces a rerun.

5. **Three "fresh subagent" dispatches, all authored-context-free.** The design reviewer (Stage 2, pre-lock), the voice-reviewer (Stage 4), and the benchmark-engine runs (Stage 4) all run in isolated contexts. This is the "structural distrust" principle made concrete in the diagram: no stage ever grades its own output with its own memory.

## Surprising dependencies / single points of failure

- **`design.md.sha256` is the single artifact whose absence is catastrophic across two stages**: Stage 3 refuses to start without it (BLOCKED_TAMPER on missing sidecar) and Stage 2 refuses to emit `DESIGN_LOCKED` without writing it. One file gates two stages.
- **`scope.json.pluginMode` is the only thing that tells Stage 5 whether to write a full tree or a skill-only delta.** If scope.json is missing or `pluginMode` is unrecognized, Stage 5 emits `SCAFFOLD_INCOMPLETE` — not `BLOCKED_*`. The diagram labels this "not found → SCAFFOLD_INCOMPLETE" to make the distinction visible.
- **lint.sh runs before the voice-reviewer subagent.** Any critical lint finding short-circuits the whole stage to `REJECT_CRITICAL` without the subagent ever being dispatched — a cost-saving structural gate.

## How to read the legend

Top-left panel. Row 1 = node styles (stage box, artifact note, emitter script, subagent 3-D box, gate diamond, happy verdict double-circle, BLOCKED_* double-circle, SHA-256 tamper-seal note). Row 2 = edge semantics (solid = produces, dashed = reads, dotted = invokes, bold green = verdict baton, bold red = BLOCKED_* escape). The dashed red edge from `design.md.sha256` into Stage 3's `re-hash & compare` diamond is the tamper-seal verification loop — that one edge is the entire integrity contract visualized.

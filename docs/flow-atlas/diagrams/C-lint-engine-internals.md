# Flow C — Lint Engine Internals

Diagram: `C-lint-engine-internals.png` (4970×3300 px, 300 dpi, landscape tabloid).

## What the diagram shows

The diagram traces one invocation of `lint.sh <SKILL.md>` from the bash entrypoint to the JSON verdict report emitted on stdout. Eight clusters read top-to-bottom: **Entrypoint**, **Rule Loader**, the central **dispatcher hexagon**, two detector clusters (**shell detectors** from `lint.sh`, **JS detectors** spawned via `node lint.js`), a **data-dependencies** strip of reference JSON files feeding specific detectors, the **findings aggregation** row with four severity/pass buckets, and finally the **verdict-ladder** decision chain that collapses the buckets into one of four verdict tokens before the report is serialized.

## Detector dispatch as the architectural spine

The centerpiece is `dispatch_detector(rule)` — a `case $dtype in …` switch that reads the rule's `detector.type` discriminator and routes to exactly one of eleven detector functions. Six types (`find-extensions`, `grep-denylist`, `grep-required`, `regex-line`, `bash-syntax`, `dot-parse`) execute inline in bash using `jq`, `grep`, `awk`, `find`, `bash -n`, and `dot -Tcanon`. Five types that need richer string parsing (`yaml-frontmatter`, `section-order`, `cross-reference`, `hard-gate-span`, `rationalization-table-cells`) are delegated to a spawned `node lint.js --detector <type> --skill <path> --config <cfg>` process, which emits `{findings:[…]}` on stdout and exits non-zero only on detector error (not on rule failure). Every detector obeys the same contract: read config + artifact, return a JSON array of `{location, message, excerpt}` findings. The dispatcher then stamps each finding with the rule's `ruleId` and `severity` before concatenating it into the running `findings_json` array.

## Declarative rule JSON + mechanical detector separation

The core design win is that rules are **data, not code**. `references/lint-rules.json` carries 21 rules where each rule is a tuple of `{id, description, severity, detector}` and the detector block is just a type tag plus typed parameters (`section`, `allowlist`, `expected-order`, `forbidden-tokens`, etc.). Authors of new lint rules never write detector logic — they pick an existing type and parametrize it. New detector **kinds** require one case-branch in the dispatcher plus one function; once added, any number of rules can reuse them. The denylist / allowlist JSON files (`hedge-words-denylist.json`, `library-names-denylist.json`, `imperative-verbs-allowlist.json`) are referenced by path from the rule's `detector.source`, so corpus updates are pure-data edits.

## Extends / disable cascade

`resolve_manifest()` runs before dispatch. It reads `<skill-dir>/lint.json`; if `.extends == "skill-cheat:baseline"` it performs a `jq` merge that (1) drops every baseline rule whose `id` appears in the local `rules[]` (local override wins), (2) drops every baseline rule whose `id` appears in the local `disable[]`, (3) concatenates the kept baseline rules with the local rules. The voice-review skill itself ships `lint.json = {extends: "skill-cheat:baseline", disable: ["LINT-001"]}` — suppressing the plugin-wide file-extension check because the skill inspects individual skill files, not the plugin root. If `extends` is absent, the local manifest is used verbatim (full override).

## Verdict-ladder semantics

The four severity counters drive a strictly monotonic ladder: `critical > 0 → REJECT_CRITICAL` (the only exit-1 path); else `important > 0 → REJECT_IMPORTANT`; else `minor > 0 → ACCEPT_WITH_MINOR`; else `ACCEPT`. Higher severity always masks lower — a single CRITICAL finding rejects the skill regardless of minor count. This is why the severity color-code (red → amber → gray → green) in the diagram maps directly to the ladder: you read the diamonds top-to-bottom and take the first `yes` branch. The final JSON report preserves full detail under `summary` (per-severity counts plus a `passed` count of zero-finding rules) and `findings[]` (every tagged finding), giving downstream reviewers both the verdict and the evidence trail.

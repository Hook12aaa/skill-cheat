# Sub-verdict vocabulary

Every layer emits a sub-verdict alongside its findings. The orchestrator's verdict-resolver consumes all sub-verdicts and emits a single headline.

## Static layer (reuses voice-review)

- `ACCEPT` — every SKILL.md returned ACCEPT.
- `ACCEPT_WITH_MINOR` — at least one SKILL.md returned ACCEPT_WITH_MINOR; none returned REJECT_*.
- `REJECT_IMPORTANT` — at least one SKILL.md returned REJECT_IMPORTANT; none returned REJECT_CRITICAL.
- `REJECT_CRITICAL` — at least one SKILL.md returned REJECT_CRITICAL.

## Behavioral layer (Plan 2)

- `TRIGGER_CLEAN` — every declared trigger phrase fired the expected skill above the configured threshold.
- `TRIGGER_MISS` — at least one trigger phrase failed to fire above threshold.
- `TRIGGER_BAIT_FOUND` — at least one adversarial phrase fired a skill that should not have triggered.
- `TRIGGER_INCONCLUSIVE` — the layer could not complete (claude binary missing, all runs errored).

## E2E layer (Plan 3)

- `CONTRACT_HOLDS` — every stage handoff matched its schema.
- `CONTRACT_BREAK` — at least one handoff violated its schema.
- `PIPELINE_INAPPLICABLE` — the target is not a pipeline-style plugin.

## Evolutionary layer (Plan 4)

- `LANDSCAPE_CLEAN` — every mutation was caught by its targeted layer.
- `BLIND_SPOT_DETECTED` — at least one mutation escaped detection across multiple baselines.
- `EVOLUTION_INCOMPLETE` — the loop ran out of budget or hit max-generation before convergence.

## Headline precedence (worst wins)

`BLOCKED_NO_TARGET > VALIDATION_INCONCLUSIVE > HARNESS_GAP > PLUGIN_DRIFT > VALIDATION_CLEAN`

In Plan 1 (Layer 1 only), the resolver collapses any non-ACCEPT static sub-verdict to `PLUGIN_DRIFT` and any incomplete/blocked condition to `VALIDATION_INCONCLUSIVE` or `BLOCKED_NO_TARGET`.

## Rationalization Table

| You think... | Reality |
|---|---|
| "Layer sub-verdicts are internal; skip writing them down" | Write them down. The vocabulary anchors the resolver, the report schema, and every test fixture. |
| "ACCEPT_WITH_MINOR maps to VALIDATION_CLEAN" | Map ACCEPT_WITH_MINOR to PLUGIN_DRIFT. Minor findings are still drift owned by the author. |
| "TRIGGER_INCONCLUSIVE rolls up to PLUGIN_DRIFT" | Roll inconclusive sub-verdicts up to VALIDATION_INCONCLUSIVE. Drift requires a layer that ran. |

## Red Flags

- "We can rename verdicts later"
- "Sub-verdicts are noise — the headline is enough"
- "TRIGGER_INCONCLUSIVE means the skill is broken"

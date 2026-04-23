# benchmark-plan.json schema

`benchmark-plan.json` is the plan-as-log file produced by the Plan 5 engine
and enriched in place with results. Structure borrows from model_trainer's
plan file (integrity block, baseline-first invariant) and skill-creator's
benchmark.json (metrics shape).

Plan 4 defines only the schema. Plan 5 implements the engine that writes it.
Plan 6 wires voice-review phase 3 to enrich and consume it.

## Top-level fields

| Field | Type | Required | Description |
|---|---|---|---|
| `schemaVersion` | string | yes | Literal `"1.0"`. |
| `skillName` | string | yes | From scope.json. |
| `runId` | string | yes | ISO-8601 UTC timestamp. |
| `integrityBlock` | object | yes | See "Integrity block". |
| `baselineRef` | string | yes | Git ref for baseline (`HEAD`, branch, or literal `no-skill`). |
| `candidateRef` | string | yes | Git ref for candidate (branch, tag, or literal `working-copy`). |
| `worktrees` | object | yes | `{baseline: <abs-path>, candidate: <abs-path>}`. |
| `cases` | array | yes | From eval-set-skeleton.json, optionally expanded. |
| `assertions` | array | yes | From assertion-skeleton.json, optionally expanded. |
| `results` | array | enriched | One entry per (case, ref) pair. Filled in Phase 2. |
| `aggregate` | object | enriched | Pass-rate, tokens, duration means ± stddev. Filled in Phase 3. |

## Integrity block

Byte range between `<!-- integrity-block:start -->` and `<!-- integrity-block:end -->` lines inside the companion benchmark-plan.md. SHA-256 stored in `<plan>.sha256` sidecar. Contents:
- `skillName`
- `baselineRef`
- `candidateRef`
- `cases[].query`
- `assertions[].pattern`

Integrity violation = STOP. Matches model_trainer's integrity contract.

## Results entry

```json
{
  "caseId": 1,
  "ref": "baseline",
  "triggered": true,
  "totalTokens": 12345,
  "durationMs": 4200,
  "assertionResults": [
    {"assertionId": 1, "passed": true, "evidence": "..."}
  ]
}
```

## Aggregate entry

```json
{
  "baseline": {"passRate": 0.7, "meanTokens": 11000, "stddevTokens": 800},
  "candidate": {"passRate": 0.85, "meanTokens": 9500, "stddevTokens": 600},
  "delta": {"passRate": 0.15, "meanTokens": -1500}
}
```

## Invariants

- `baselineRef` MUST be set before `candidateRef` in `worktrees` — baseline-first.
- `results` length MUST equal `cases.length * 2` (one per ref per case) before aggregation.
- `aggregate` MUST NOT be written until every `results` entry has a non-null `passed` field.

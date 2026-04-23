# HARD-GATE Patterns

Every HARD-GATE block is one or two imperative sentences. Each sentence starts with an imperative verb (`Do NOT`, `Never`, `STOP`). No rationale, no `because`, no `since`, no `in order to`.

## Canonical shapes

**Precondition gate** — blocks until an upstream artifact exists.

```
<HARD-GATE>
Do NOT proceed without a data-check PASS report. STOP and invoke /data-check.
</HARD-GATE>
```

**Content gate** — forbids a specific pattern in the output.

```
<HARD-GATE>
Do NOT name libraries or frameworks in the HARD-GATE list. STOP and rewrite the gate.
</HARD-GATE>
```

**Integrity gate** — protects a locked artifact from silent mutation.

```
<HARD-GATE>
Never edit content inside `<!-- integrity-block:start/end -->` markers. STOP if drift is suspected.
</HARD-GATE>
```

## Rationalization Table

| You think... | Reality |
|---|---|
| "The author will not remember why this gate exists unless I add `because` here" | Strip the rationale out of the gate. Put the `why` in prose outside the `<HARD-GATE>` block. |
| "One more sentence clarifies the follow-up action and makes the gate safer" | Keep the gate at one or two imperative sentences. Rewrite the third sentence as a checklist item elsewhere. |
| "Saying `Should not proceed` sounds less hostile than `Do NOT proceed`" | Rewrite the opener as `Do NOT`, `Never`, or `STOP`. Hedged voice is not a gate. |

## Red Flags

- "because"
- "since"
- "Should not proceed"
- "in order to"

## Rule

Each gate: one or two sentences. Each sentence starts with an imperative. No rationale in the gate. If rationale is needed, put it in prose OUTSIDE the gate.

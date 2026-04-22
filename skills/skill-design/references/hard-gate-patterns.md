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

## Anti-patterns

NOT this (rationale inside gate):
```
<HARD-GATE>
Do NOT proceed without scope because the scope lock is load-bearing.
</HARD-GATE>
```

NOT this (too many sentences):
```
<HARD-GATE>
Do NOT proceed without scope. STOP and invoke /skill-scope. Then confirm nothing else is pending.
</HARD-GATE>
```

NOT this (library name inside gate):
```
<HARD-GATE>
Do NOT use React without declaring its version. STOP if unspecified.
</HARD-GATE>
```

## Rule

Each gate: one or two sentences. Each sentence starts with an imperative. No rationale in the gate. If rationale is needed, put it in prose OUTSIDE the gate.

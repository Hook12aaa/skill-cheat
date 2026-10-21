# Dot Digraph Template

The Process Flow section's dot block must parse under `dot -Tcanon` or LINT-011 fires.

## Skeleton

```dot
digraph <skill_name> {
    rankdir=TB;

    "Entry state" [shape=box];
    "Decision point" [shape=diamond];
    "Next state" [shape=box];
    "Terminal verdict" [shape=doublecircle];

    "Entry state" -> "Decision point";
    "Decision point" -> "Next state" [label="condition true"];
    "Decision point" -> "Entry state" [label="retry"];
    "Next state" -> "Terminal verdict";
}
```

## Node shape conventions

- `box` — an action or step.
- `diamond` — a decision or gate.
- `doublecircle` — a terminal verdict (SCOPE_LOCKED, DESIGN_LOCKED, READY, SHIP).

## Edge conventions

- Unlabeled edges mark direct flow.
- Labeled edges distinguish branches: `[label="yes"]`, `[label="no, retry"]`, `[label="on REJECT"]`.

## Required properties

- Every node named in the graph has at least one incoming OR outgoing edge.
- Every path reaches a terminal (doublecircle) or a declared backtrack loop.
- The graph parses under `dot -Tcanon` — no syntax errors, no unresolved references.

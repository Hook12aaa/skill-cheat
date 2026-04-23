# Rationalization Table Patterns

Every skill has a Rationalization Table: two columns, `You think...` and `Reality`. Each row names a specific drift the author is tempted toward, then rebuts it.

## Row anatomy

Left column: quoted fragment of the actual self-talk, not a paraphrase. Use the author's voice.

Right column: imperative rebuttal. Shorter than the left. Names the concrete consequence or corrective action.

## Canonical rows (reusable across skills)

| You think... | Reality |
|---|---|
| "The reader will figure it out" | Readers read what is written, not what is meant. Rewrite until ambiguity is gone. |
| "This is just a v1; we can fix later" | V1 sets the mental model users learn. There is no clean redo. |
| "One more review pass after I commit" | Commits are the review boundary. Commit clean or do not commit. |
| "The library makes this obvious" | Library choice is downstream of contract. Name the contract first. |

## Anti-patterns

NOT this (Reality softer than You-think):

```
| "We can iterate on the schema" | Iteration is fine when users are patient. |
```

The Reality above does not rebut; it agrees. Rewrite so Reality states the hard consequence.

NOT this (paraphrased You-think):

```
| "Let me check the spec later" | Check it now. |
```

Better:

```
| "I'll pull up the spec when I need it" | The spec is needed before the first line is written. Read it now. |
```

## Rule

Every row's Reality is STRICTER than its You-think. If Reality is softer or equivocal, delete the row.

## Rationalization Table

| You think... | Reality |
|---|---|
| "The Reality cell just needs to explain the nuance" | Rewrite it as an imperative. Explanation without a verb is a hedge. |
| "Opening with 'You might want to consider' sounds balanced" | Strip the hedge. Reality leads with an imperative or it fails LINT-019. |
| "The row reads fine with a generic 'this is simple' on the left" | Quote the actual self-talk verbatim. Generic You-think produces generic Reality. |

## Red Flags

- "Consider revising the approach here"
- "You may want to rethink this"
- "It's generally better to"
- "This might be worth reconsidering"

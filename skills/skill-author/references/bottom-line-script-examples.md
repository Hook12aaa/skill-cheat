# Bottom Line Script Examples

The Bottom Line is an executable fenced block at the end of every SKILL.md. LINT-009 requires it to pass `bash -n`. The script emits a VERDICT token.

## Example 1: Simple emit

```bash
echo "VERDICT: READY"
```

## Example 2: Conditional on file presence

```bash
if [[ -f docs/scope.md ]]; then
  echo "VERDICT: READY"
else
  echo "VERDICT: BLOCKED_MISSING_INPUT"
  exit 1
fi
```

## Example 3: Stage-exit protocol (full)

```bash
STAGE="skill-scope"
VERDICT="SCOPE_LOCKED"
ARTIFACTS=(
  "docs/skill-cheat/skills-in-progress/<name>/scope.md"
)
NEXT="/skill-design"

echo "STAGE: $STAGE"
echo "VERDICT: $VERDICT"
echo "ARTIFACTS:"
printf '  - %s\n' "${ARTIFACTS[@]}"
echo "NEXT: $NEXT"
```

## Rule

The Bottom Line is the only inter-stage IPC. If it breaks, the whole pipeline breaks. Keep it tight. Keep it executable. Pass `bash -n` every time.

## Rationalization Table

| You think... | Reality |
|---|---|
| "`set -euo pipefail` is overkill for a three-line script." | Emit it on line one. A pipe that silently returns zero ships a false PASS. |
| "Prose like 'looks ready' reads better than `VERDICT: READY`." | Print the exact token `VERDICT: <TOKEN>`. The next stage parses bytes, not vibes. |
| "Returning `exit 0` on the error branch keeps the pipeline moving." | Return non-zero on every failure path. A zero exit on error corrupts every downstream gate. |

## Red Flags

- "I'll add `set -e` later once the script settles."
- "The grep at the end will fail, so the whole pipeline will fail."
- "No need for an else branch, the happy path is obvious."
- "Hardcoding `/Users/me/skills/...` is fine, it runs on my box."

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

#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "${HERE}/skills/skill-voice-review/scripts/lint.sh" --source-only

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

cat > "${TMP}/good.md" <<'EOF'
## Gate Functions

- BEFORE acting: "Is scope locked?"
- BEFORE committing: "Did tests pass?"
EOF

cfg='{"section":"gate-functions","must-match":"^- BEFORE .+: \".+\\?\"$"}'
findings="$(detect_regex_line "${TMP}/good.md" "$cfg")"
if ! printf '%s' "$findings" | jq -e 'length == 0' >/dev/null; then
  echo "FAIL: good section flagged: $findings"; exit 1
fi

cat > "${TMP}/bad.md" <<'EOF'
## Gate Functions

- Before acting, ask whether scope is locked
- BEFORE committing: "Did tests pass?"
EOF

findings="$(detect_regex_line "${TMP}/bad.md" "$cfg")"
count="$(printf '%s' "$findings" | jq 'length')"
if [[ "$count" != "1" ]]; then
  echo "FAIL: expected 1 finding, got $count"
  echo "$findings"; exit 1
fi

cat > "${TMP}/antipattern.md" <<'EOF'
## Anti-Pattern

This has no quoted phrase in its first sentence.
EOF

cfg='{"section":"anti-pattern","first-sentence-must-match":"\".+\""}'
findings="$(detect_regex_line "${TMP}/antipattern.md" "$cfg")"
if ! printf '%s' "$findings" | jq -e 'length == 1' >/dev/null; then
  echo "FAIL: first-sentence-must-match did not fire"
  echo "$findings"; exit 1
fi

cat > "${TMP}/redflags.md" <<'EOF'
## Red Flags

- "I already know this"
- "It is obvious" — to everyone who has worked here
EOF

cfg='{"section":"red-flags","must-not-match":" — "}'
findings="$(detect_regex_line "${TMP}/redflags.md" "$cfg")"
if ! printf '%s' "$findings" | jq -e 'length == 1' >/dev/null; then
  echo "FAIL: must-not-match did not flag em-dash explanation"
  echo "$findings"; exit 1
fi

cat > "${TMP}/hardgate.md" <<'EOF'
<HARD-GATE>
Do NOT proceed without a named scope.
</HARD-GATE>

<HARD-GATE>
The scope should really be named before proceeding.
</HARD-GATE>
EOF

cfg='{"section":"hard-gate-blocks","must-match":"^(Do NOT|Never|STOP|NEVER) "}'
findings="$(detect_regex_line "${TMP}/hardgate.md" "$cfg")"
count="$(printf '%s' "$findings" | jq 'length')"
if [[ "$count" != "1" ]]; then
  echo "FAIL: hard-gate must-match expected 1 finding, got $count"
  echo "$findings"; exit 1
fi

echo "PASS: regex-line"

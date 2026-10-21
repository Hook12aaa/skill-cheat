#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HASH="${HERE}/skills/skill-voice-review/scripts/benchmark-integrity-hash.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "${tmp}/benchmark-plan.md" <<'EOF'
<!-- integrity-block:start -->
skillName: demo
baselineRef: HEAD
candidateRef: working-copy
<!-- integrity-block:end -->

free-form notes below
EOF

bash "$HASH" "${tmp}/benchmark-plan.md"
[[ -f "${tmp}/benchmark-plan.md.sha256" ]] || { echo "FAIL: sidecar missing"; exit 1; }

# Invariant: sidecar is 64-char hex + two spaces + filename.
line="$(cat "${tmp}/benchmark-plan.md.sha256")"
[[ "$line" =~ ^[a-f0-9]{64}\ \ benchmark-plan\.md$ ]] || { echo "FAIL: sidecar format wrong: $line"; exit 1; }

# Invariant: altering content OUTSIDE the integrity block does NOT change the hash.
before="$(awk '{print $1}' "${tmp}/benchmark-plan.md.sha256")"
echo "extra line" >> "${tmp}/benchmark-plan.md"
bash "$HASH" "${tmp}/benchmark-plan.md"
after="$(awk '{print $1}' "${tmp}/benchmark-plan.md.sha256")"
[[ "$before" == "$after" ]] || { echo "FAIL: hash changed when extra-block content was edited"; exit 1; }

# Invariant: altering content INSIDE the integrity block DOES change the hash.
sed -i.bak 's/baselineRef: HEAD/baselineRef: main/' "${tmp}/benchmark-plan.md"
bash "$HASH" "${tmp}/benchmark-plan.md"
changed="$(awk '{print $1}' "${tmp}/benchmark-plan.md.sha256")"
[[ "$before" != "$changed" ]] || { echo "FAIL: hash unchanged when in-block content was edited"; exit 1; }

echo "PASS: benchmark-integrity-hash"

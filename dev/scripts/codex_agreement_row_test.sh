#!/bin/sh
# Offline tests for dev/scripts/codex_agreement_row.sh (issue #2905).
set -eu
HERE=$(dirname "$0")
CODEX_AGREEMENT_LIB=1
export CODEX_AGREEMENT_LIB
. "$HERE/codex_agreement_row.sh"
TIP=7dc57cc06aa1b2c3d4e5f60718293a4b5c6d7e8f
fails=0; total=0
D=$(mktemp -d); trap 'rm -rf "$D"' EXIT
check() {
  _name=$1; _want=$2; _got=$3
  total=$((total + 1))
  if [ "$_got" = "$_want" ]; then printf 'ok   %s\n' "$_name"
  else printf 'FAIL %s: want %s, got %s\n' "$_name" "$_want" "$_got"; fails=$((fails + 1)); fi
}
body() { printf 'Reviewed SHA: %s\n\n## %s\n\n| # | Check |\n|---|---|\n\n## Verdict\n\n%s\n%s' "$TIP" "$1" "$2" "${3:-}"; }
ITEMS='
## NEEDS_REWORK Items

### CP2: test plan names a test that does not exist
- Finding: x

### CP3: docstring drift
- Finding: y
'
S_OK=$(body "Structural QC — thing" APPROVED)
B_OK=$(body "Behavioral QC — thing" APPROVED)
B_RW=$(body "Behavioral QC — thing" NEEDS_REWORK "$ITEMS")
C_OK=$(body "Codex review — thing" APPROVED)
C_RW=$(body "Codex review — thing" NEEDS_REWORK "$ITEMS")
J3() { jq -nc --arg a "$1" --arg b "$2" --arg c "$3" '[{body: $a}, {body: $b}, {body: $c}]'; }

check "claude_combined: either rework wins" rework "$(claude_combined ok rework)"
check "claude_combined: both ok" ok "$(claude_combined ok ok)"
check "claude_combined: missing gate is pending" pending "$(claude_combined none ok)"
check "agree: n/a without a codex verdict" n/a "$(agree ok none)"
check "agree: yes on ok/ok" yes "$(agree ok ok)"
check "agree: no on rework/ok" no "$(agree rework ok)"
check "rework_items: counts ### under NEEDS_REWORK Items" 2 "$(rework_items "$(J3 "$S_OK" "$B_RW" "$C_OK")" behavioral)"
check "rework_items: zero when the body has no items" 0 "$(rework_items "$(J3 "$S_OK" "$B_OK" "$C_OK")" behavioral)"
check "rework_items: zero when no body names the kind" 0 "$(rework_items "$(J3 "$S_OK" "$B_OK" "$B_OK")" codex)"
# CP1-A (#2907 rework 1): a body whose FIRST heading is structural but which
# quotes a behavioral heading further down must count as structural only.
S_QUOTING=$(printf 'Reviewed SHA: %s\n\n## Structural QC — thing\n\nSee also:\n\n## Behavioral QC — quoted\n\n## Verdict\n\nNEEDS_REWORK\n%s' "$TIP" "$ITEMS")
check "rework_items: first heading only -- quoted behavioral heading does not count" 0 "$(rework_items "$(J3 "$S_QUOTING" "$C_OK" "$C_OK")" behavioral)"
check "rework_items: ... and the same body still counts as structural" 2 "$(rework_items "$(J3 "$S_QUOTING" "$C_OK" "$C_OK")" structural)"
row=$(agreement_row 42 "$TIP" "$(J3 "$S_OK" "$B_OK" "$C_OK")")
check "row: all-ok agrees" "| ok | ok | ok | yes | 0 | 0" "$(printf '%s' "$row" | cut -d'|' -f5-10 | sed 's/^ */| /; s/ *$//')"
row=$(agreement_row 42 "$TIP" "$(J3 "$S_OK" "$B_RW" "$C_OK")")
check "row: codex ok vs claude rework disagrees, claude items counted" "| ok | rework | ok | no | 0 | 2" "$(printf '%s' "$row" | cut -d'|' -f5-10 | sed 's/^ */| /; s/ *$//')"
row=$(agreement_row 42 "$TIP" "$(J3 "$S_OK" "$B_OK" "$C_RW")")
check "row: codex rework vs claude ok disagrees, codex items counted" "| ok | ok | rework | no | 2 | 0" "$(printf '%s' "$row" | cut -d'|' -f5-10 | sed 's/^ */| /; s/ *$//')"
row=$(agreement_row 42 "$TIP" "$(J3 "$S_OK" "$B_OK" "$B_OK")")
check "row: no codex review -> codex none, agree n/a" "| ok | ok | none | n/a | 0 | 0" "$(printf '%s' "$row" | cut -d'|' -f5-10 | sed 's/^ */| /; s/ *$//')"
check "row: PR and short tip" "| #42 | 7dc57cc06" "$(printf '%s' "$row" | cut -d'|' -f3-4 | sed 's/^ */| /; s/ *$//')"
ensure_header "$D/agree.md"; ensure_header "$D/agree.md"
check "ensure_header: writes the table header exactly once" 1 "$(grep -c '^| date | PR |' "$D/agree.md")"
rc=0; out=$(CODEX_AGREEMENT_LIB= sh "$HERE/codex_agreement_row.sh" 2>&1) || rc=$?
check "no PR argument exits 2" 2 "$rc"
if [ "$fails" -gt 0 ]; then printf 'FAIL: codex_agreement_row -- %d test(s) failed.\n' "$fails"; exit 1; fi
printf 'OK: codex_agreement_row -- %d tests clean.\n' "$total"

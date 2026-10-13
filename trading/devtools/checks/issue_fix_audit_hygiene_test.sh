#!/bin/sh
# issue_fix_audit_hygiene_test.sh -- fixture-driven test for the issue-hygiene
# sections of dev/scripts/issue_fix_audit.sh (issue #3275,
# .claude/rules/issue-hygiene.md). No network: ISSUE_FIX_AUDIT_FIXTURE_DIR
# feeds canned gh JSON and ISSUE_FIX_AUDIT_NOW fixes the clock at 2026-10-13.
#
# Pins, on fixtures/issue_fix_audit_hygiene (9 open issues):
#   - header: the open count and the cap (default 20; over-cap note at cap 5);
#   - (c) lists only #202 (a state label but no owner label);
#   - (d) dates #203 from its LAST verify/pending label event (2026-09-01, 42
#     days), read across two concatenated timeline pages, not from its recent
#     update; falls back to updatedAt for #205 (no timeline, 23 days); omits
#     #204 (label added 8 days ago);
#   - (e) lists #206 (42 days, fractional-second timestamp) and not #207
#     (exactly 30 days: the threshold is strict);
#   - (f) shows #208's latest comment's first non-blank line, not an earlier
#     comment, and flags #209 as having no comment.
#
# Run: sh trading/devtools/checks/issue_fix_audit_hygiene_test.sh
set -eu
. "$(dirname "$0")/_check_lib.sh"
ROOT="$(repo_root)"
SCRIPT="${ROOT}/dev/scripts/issue_fix_audit.sh"
export ISSUE_FIX_AUDIT_FIXTURE_DIR="${ROOT}/trading/devtools/checks/fixtures/issue_fix_audit_hygiene"
export ISSUE_FIX_AUDIT_NOW="2026-10-13T00:00:00Z"
[ -f "$SCRIPT" ] || { echo "FAIL: script not found: $SCRIPT" >&2; exit 1; }
OUT="$(sh "$SCRIPT")"
section() { printf '%s\n' "$OUT" | sed -n "/^== ($1)/,/^== ($2)/p"; }
HEAD=$(printf '%s\n' "$OUT" | sed -n '1p')
C=$(section c d)
D=$(section d e)
E=$(section e f)
F=$(printf '%s\n' "$OUT" | sed -n '/^== (f)/,$p')
FAILED=0
check() { # label, haystack, pattern, expected-count
  n=$(printf '%s\n' "$2" | grep -c -- "$3" || true)
  if [ "$n" = "$4" ]; then echo "OK: $1"; else
    echo "FAIL: $1: expected $4 match(es) of '$3', got $n" >&2; FAILED=$((FAILED + 1)); fi
}
check "header: open count and default cap" "$HEAD" '^open issues: 9 (cap 20)$' 1
CAPPED=$(AUDIT_ISSUE_CAP=5 sh "$SCRIPT" | sed -n '1p')
check "header: over-cap note" "$CAPPED" '^open issues: 9 (cap 5, over by 4)$' 1
check "(c) lists #202 (no owner label)" "$C" '^#202 No owner label$' 1
check "(c) lists nothing else" "$C" '^#' 1
check "(d) #203 dated from its last label event" "$D" '^#203 .* -- 42 days (since 2026-09-01, label added)$' 1
check "(d) #205 falls back to last update" "$D" '^#205 .* -- 23 days (since 2026-09-20, last update, no label event)$' 1
check "(d) omits #204 (label added 8 days ago)" "$D" '^#204 ' 0
check "(d) lists nothing else" "$D" '^#' 2
check "(e) lists #206 (fractional-second timestamp)" "$E" '^#206 .* -- 42 days (last update 2026-09-01)$' 1
check "(e) omits #207 (exactly 30 days)" "$E" '^#207 ' 0
check "(e) lists nothing else" "$E" '^#' 1
check "(f) lists both owner/user issues" "$F" '^#20[89] ' 2
check "(f) #208: latest comment's first non-blank line" "$F" '^    Should we keep X or adopt Y?$' 1
check "(f) #208: earlier comment not shown" "$F" 'earlier note' 0
check "(f) #209: no comment flagged" "$F" '^    (no comment' 1
[ "$FAILED" = 0 ] || exit 1
echo "issue_fix_audit_hygiene_test: all passed"

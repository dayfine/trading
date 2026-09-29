#!/bin/sh
# issue_fix_audit_test.sh -- fixture-driven test for dev/scripts/issue_fix_audit.sh
# (issue #3019). No network: ISSUE_FIX_AUDIT_FIXTURE_DIR feeds canned gh JSON.
#
# Pins, on fixtures/issue_fix_audit:
#   - (a) lists #101 with PR #900 and its merge date, and does NOT list #103
#     (no PR) or match #1010 as #101 (digit boundary);
#   - (b) lists verify/pending #102 with both its [after-merge] lines, and
#     drops the [after-merge] line under a different heading and the [merge] line;
#   - the script does not list #101 under (b) (no verify/pending label);
#   - (b) on a web-template-shaped body (#104) lists only its real condition,
#     not the HTML guidance comment or the empty "- [after-merge]" placeholder.
#
# Run: sh trading/devtools/checks/issue_fix_audit_test.sh
set -eu
. "$(dirname "$0")/_check_lib.sh"
ROOT="$(repo_root)"
SCRIPT="${ROOT}/dev/scripts/issue_fix_audit.sh"
export ISSUE_FIX_AUDIT_FIXTURE_DIR="${ROOT}/trading/devtools/checks/fixtures/issue_fix_audit"
[ -f "$SCRIPT" ] || { echo "FAIL: script not found: $SCRIPT" >&2; exit 1; }
OUT="$(sh "$SCRIPT")"
A=$(printf '%s\n' "$OUT" | sed -n '/^== (a)/,/^== (b)/p')
B=$(printf '%s\n' "$OUT" | sed -n '/^== (b)/,$p')
FAILED=0
check() { # label, haystack, pattern, expected-count
  n=$(printf '%s\n' "$2" | grep -c -- "$3" || true)
  if [ "$n" = "$4" ]; then echo "OK: $1"; else
    echo "FAIL: $1: expected $4 match(es) of '$3', got $n" >&2; FAILED=$((FAILED + 1)); fi
}
check "(a) lists #101 with PR #900 and date" "$A" '^#101 .*PR #900 (2026-09-01)' 1
check "(a) omits #103 (no PR)" "$A" '^#103 ' 0
check "(a) does not read #1010 (PR #901) as #101" "$A" 'PR #901' 0
check "(b) lists #102" "$B" '^#102 ' 1
check "(b) quotes both after-merge conditions" "$B" '^    - \[after-merge\] \(sweep green\|V6 = 0\)' 2
check "(b) drops other-heading and [merge] lines" "$B" 'not under Done when\|check added' 0
check "(b) omits unlabelled #101" "$B" '^#101 ' 0
check "(b) template issue: only its real condition" "$B" '^    - \[after-merge\] golden unchanged on 2 weekly runs$' 1
check "(b) template issue: comment and empty placeholder skipped" "$B" 'only provable\|^    - \[after-merge\]$' 0
[ "$FAILED" = 0 ] || exit 1
echo "issue_fix_audit_test: all passed"

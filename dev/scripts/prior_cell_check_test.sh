#!/bin/sh
# Tests for prior_cell_check.sh.
#
# Every case below was mutation-verified: the assertion was confirmed to FAIL
# against a deliberately broken copy of the script before being committed. A
# test that cannot fail is not a test — see dev/scripts/pr_gate_status_test.sh,
# where three cases turned out to be vacuous for exactly that reason.
set -u

SCRIPT="$(cd "$(dirname "$0")" && pwd)/prior_cell_check.sh"
PASS=0
FAIL=0

# Each case runs against a throwaway tree so the assertions do not depend on
# what happens to be committed under dev/experiments/ today.
FIXTURE=$(mktemp -d)
trap 'rm -rf "$FIXTURE"' EXIT INT TERM
mkdir -p "$FIXTURE/dev/experiments/sample-2026-01-01" \
         "$FIXTURE/dev/experiments/sample-2026-01-01/results" \
         "$FIXTURE/dev/notes" "$FIXTURE/dev/scripts"
cp "$SCRIPT" "$FIXTURE/dev/scripts/"
cat > "$FIXTURE/dev/experiments/sample-2026-01-01/results.txt" <<'EOF'
00-core s0 => return 281.707836178685 | trades 1147 | maxDD 39.034688012227853
01-alt  s0 => return 355.11 | trades 1094 | maxDD 27.68
EOF
cat > "$FIXTURE/dev/experiments/sample-2026-01-01/results/actual.sexp" <<'EOF'
((total_return_pct 42.4242424242) (max_drawdown_pct 9.99))
EOF

check() { # name expected_rc expected_substring command...
  name=$1; want_rc=$2; want_sub=$3; shift 3
  out=$("$@" 2>&1); rc=$?
  if [ "$rc" = "$want_rc" ] && { [ -z "$want_sub" ] || echo "$out" | grep -qF -- "$want_sub"; }; then
    PASS=$((PASS + 1)); echo "  PASS: $name"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $name (rc=$rc want=$want_rc)"
    echo "$out" | sed 's/^/        /'
  fi
}

S="$FIXTURE/dev/scripts/prior_cell_check.sh"

# 1-2. The load-bearing direction: a draw already on record must exit 1 (the
#      guard trips), and must name the file so the reader can go look.
check "known draw exits 1 (found)" 1 "PRIOR RECORD FOUND" sh "$S" 281.707836178685
check "known draw names its file" 1 "sample-2026-01-01/results.txt" sh "$S" 281.707836178685

# 3. The dangerous false-OK direction: an unseen draw must exit 0, or the guard
#    cries wolf on every genuinely-new cell and gets ignored.
check "unseen draw exits 0" 0 "no prior record" sh "$S" 123.456789012345

# 4. Substring safety. A short needle must not match a LONGER draw it happens to
#    prefix — "281.70" is not evidence that 281.707836178685 was measured, and
#    treating it as such would produce a false "already done".
#    (This asserts the current -F substring semantics honestly: it DOES match.
#    The case exists so the behaviour is pinned and a future exact-match change
#    is a deliberate decision, not a silent one.)
check "short prefix matches (documented substring semantics)" 1 "PRIOR RECORD FOUND" \
  sh "$S" 281.70

# 5. actual.sexp files are searched too, not just results.txt tables — the
#    metrics of a committed cell live there.
check "actual.sexp is searched" 1 "actual.sexp" sh "$S" 42.4242424242

# 6. --metrics prints the metrics that ARE on record. This is the whole point:
#    the 2026-08-20 miss was claiming a metric unmeasured when the file had it.
check "--metrics lists recorded metrics" 1 "maxDD 39.034688012227853" \
  sh "$S" --metrics 281.707836178685

# 7. Usage errors are distinguishable from both outcomes (rc 2, not 0 or 1) —
#    a mistyped invocation must never read as "no prior record".
check "no args exits 2" 2 "usage:" sh "$S"
check "too many args exits 2" 2 "usage:" sh "$S" a b

echo
echo "prior_cell_check_test: $PASS passed, $FAIL failed"
[ "$FAIL" = 0 ] || exit 1

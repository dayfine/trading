#!/bin/sh
# pit_twin_cooccur_check.sh -- no confirmed rename twin pair co-occurs in a pit-v12 list whose window it is one series
# in (#3266).
#
# A list that holds both legs of one instrument (old and new ticker, or a file carrying another symbol's quotes) lets
# a backtest buy it twice on the same day: the CMD/CMN (Cantel Medical) twin did exactly that in every chain-V cell
# and failed the V6 pair gate. The per-list decisions live in
# trading/test_data/backtest_scenarios/pit-v12/twin-drops.txt ("LIST DROPPED SURVIVOR" per line, '#' comments),
# produced by dev/experiments/v12-twin-scan-2026-10-22/. For every row: FAIL when DROPPED is a member of LIST again (a
# regenerated or hand-edited list re-admitting the twin), or when SURVIVOR is not (the row no longer describes the
# list).
#
# A self-test runs first on a temporary fixture (a list holding both legs FAILs, one holding only the survivor
# passes), so the check cannot rot into a no-op.
#
# The lists live outside the dune sandbox's dependency set, so they are read via repo_root() at RUN TIME and the dune
# rule needs (universe) (H-CHECK-CACHE-BLIND).
#
# Env overrides (tests): TWIN_DROPS_FILE, TWIN_LISTS_DIR.
set -eu

. "$(dirname "$0")/_check_lib.sh"

# $1 drops file, $2 lists dir. Prints one line per violation; returns 1 when any.
scan() {
  bad=0
  while read -r l d s _; do
    case "$l" in '' | '#'*) continue ;; esac
    f=$2/$l.sexp
    if [ ! -f "$f" ]; then echo "  $l: list missing"; bad=1; continue; fi
    if grep -q -F "(symbol $d)" "$f"; then echo "  $l: holds $d again (twin of $s)"; bad=1; fi
    if ! grep -q -F "(symbol $s)" "$f"; then echo "  $l: survivor $s missing"; bad=1; fi
  done < "$1"
  return "$bad"
}

self_test() {
  t=$(mktemp -d)
  printf '# fixture\ntop-3000-2009 OLD NEW\n' > "$t/drops.txt"
  mkdir "$t/both" "$t/one"
  printf '((entries (((symbol OLD) (weight 1)) ((symbol NEW) (weight 1)))))\n' > "$t/both/top-3000-2009.sexp"
  printf '((entries (((symbol NEW) (weight 1)) ((symbol OLDX) (weight 1)))))\n' > "$t/one/top-3000-2009.sexp"
  rc=0
  if scan "$t/drops.txt" "$t/both" > /dev/null; then echo "FAIL: self-test: a list holding both legs passed"; rc=1; fi
  if ! scan "$t/drops.txt" "$t/one" > /dev/null; then echo "FAIL: self-test: a list holding only the survivor failed"; rc=1; fi
  rm -rf "$t"
  return "$rc"
}

self_test || exit 1

ROOT=$(repo_root)
DROPS=${TWIN_DROPS_FILE:-$ROOT/trading/test_data/backtest_scenarios/pit-v12/twin-drops.txt}
LISTS=${TWIN_LISTS_DIR:-$ROOT/trading/test_data/backtest_scenarios/pit-v12/composition}
[ -s "$DROPS" ] || die "drops file missing or empty: $DROPS"
n_rows=$(grep -c -v -E '^(#|$)' "$DROPS")
if out=$(scan "$DROPS" "$LISTS"); then
  echo "OK: pit_twin_cooccur_check: $n_rows per-list twin drops hold in $LISTS"
else
  echo "FAIL: pit_twin_cooccur_check: a rename twin pair co-occurs again in a composition list:"
  echo "$out"
  echo "Re-apply: sh dev/experiments/v12-twin-scan-2026-10-22/apply-drops.sh <drops> <lists> (see $DROPS)"
  exit 1
fi

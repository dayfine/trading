#!/bin/sh
# pit_twin_cooccur_check.sh -- no confirmed rename twin pair co-occurs in a PIT composition list whose window it is one
# series in (#3266, #3713).
#
# A list that holds both legs of one instrument (old and new ticker, or a file carrying another symbol's quotes) lets
# a backtest buy it twice on the same day: the CMD/CMN (Cantel Medical) twin did exactly that in every chain-V cell
# and failed the V6 pair gate. The per-list decisions live in each vintage's
# trading/test_data/backtest_scenarios/pit-vN/twin-drops.txt ("LIST DROPPED SURVIVOR" per line, '#' comments; first
# produced by dev/experiments/v12-twin-scan-2026-10-22/).
#
# Every vintage dir pit-vN (N a number) that has a twin-drops.txt and a composition/ dir is checked, in version order:
#   own rows        for each row of pit-vN/twin-drops.txt: FAIL when DROPPED is a member of LIST again (a regenerated or
#                   hand-edited list re-admitting the twin), or when SURVIVOR is not (the row no longer describes the
#                   list).
#   inherited rows  for each row of every EARLIER vintage's twin-drops.txt: FAIL when any pit-vN list of the same year
#                   (LIST's trailing -YYYY; list families differ between vintages, e.g. v12 top-1000/top-3000 against
#                   v13 top-3000/top-4000) holds both DROPPED and SURVIVOR. The pair was confirmed one series over that
#                   year's window, so a rebuilt list holding both legs is the same double hold. This is the class the
#                   own-rows test cannot see: a list rebuild that re-admits a twin its predecessor dropped and writes
#                   no row for it (universe-depth K=5, #3721: 439 v12 rows had both legs back in the v13 lists).
#
# A self-test runs first on a temporary fixture (both legs FAIL, survivor only passes, an earlier vintage's pair back in
# a same-year list of another family FAILs), so the check cannot rot into a no-op.
#
# The lists live outside the dune sandbox's dependency set, so they are read via repo_root() at RUN TIME and the dune
# rule needs (universe) (H-CHECK-CACHE-BLIND).
#
# Env override (tests): TWIN_PIT_ROOT, the dir holding the pit-vN dirs.
set -eu

. "$(dirname "$0")/_check_lib.sh"

# $1 lists dir. Prints "LIST SYMBOL" for every entry of every list.
members() {
  for f in "$1"/*.sexp; do
    [ -f "$f" ] || continue
    awk -v l="$(basename "$f" .sexp)" '{
        s = $0
        while (match(s, /\(symbol [^)]*\)/)) { print l, substr(s, RSTART + 8, RLENGTH - 9); s = substr(s, RSTART + RLENGTH) }
      }' "$f"
  done
}

# $1 drops file, $2 membership file. Own rows. Prints one line per violation; returns 1 when any.
scan_own() {
  awk 'NR == FNR { m[$1 " " $2] = 1; has[$1] = 1; next }
       $1 == "" || $1 ~ /^#/ { next }
       !($1 in has) { print "  " $1 ": list missing"; bad = 1; next }
       ($1 " " $2) in m { print "  " $1 ": holds " $2 " again (twin of " $3 ")"; bad = 1 }
       !(($1 " " $3) in m) { print "  " $1 ": survivor " $3 " missing"; bad = 1 }
       END { exit bad }' "$2" "$1"
}

# $1 an earlier vintage's drops file, $2 membership file, $3 label for $1. Inherited rows. Prints one line per
# violation; returns 1 when any.
scan_inherited() {
  awk -v src="$3" '
       function year(l,   n, p) { n = split(l, p, "-"); return p[n] }
       NR == FNR { m[$1 " " $2] = 1; if (!seen[$1]++) by_year[year($1)] = by_year[year($1)] " " $1; next }
       $1 == "" || $1 ~ /^#/ { next }
       {
         n = split(by_year[year($1)], ls, " ")
         for (i = 1; i <= n; i++) if (((ls[i] " " $2) in m) && ((ls[i] " " $3) in m) && !(((ls[i] " " $2 " " $3) in done))) {
           done[ls[i] " " $2 " " $3] = 1
           print "  " ls[i] ": holds both " $2 " and " $3 " (dropped as one series in " src " row " $1 ")"; bad = 1
         }
       }
       END { exit bad }' "$2" "$1"
}

# $1 pit root. Prints the vintage dirs that carry twin drops, in version order.
vintages() {
  for d in "$1"/pit-v*; do
    v=${d##*/pit-v}
    case "$v" in '' | *[!0-9]*) continue ;; esac
    [ -s "$d/twin-drops.txt" ] && [ -d "$d/composition" ] && echo "$v $d"
  done | sort -n | awk '{ print $2 }'
}

# $1 pit root. Checks every vintage; prints OK / violation lines; returns 1 when any vintage fails.
check_root() {
  rc=0; earlier=""; mem=$(mktemp)
  for d in $(vintages "$1"); do
    members "$d/composition" > "$mem"
    n_rows=$(grep -c -v -E '^(#|$)' "$d/twin-drops.txt" || true)
    if out=$(scan_own "$d/twin-drops.txt" "$mem"); then
      echo "OK: ${d##*/}: $n_rows own twin drops hold"
    else
      echo "FAIL: ${d##*/}: a twin dropped by its own twin-drops.txt co-occurs again:"; echo "$out"; rc=1
    fi
    for e in $earlier; do
      if out=$(scan_inherited "$e/twin-drops.txt" "$mem" "${e##*/}/twin-drops.txt"); then
        echo "OK: ${d##*/}: no ${e##*/} twin pair co-occurs in a same-year list"
      else
        echo "FAIL: ${d##*/}: ${e##*/} twin pairs are both back in a same-year list:"; echo "$out"
        echo "  $(echo "$out" | wc -l | tr -d ' ') (list, pair) cells"; rc=1
      fi
    done
    earlier="$earlier $d"
  done
  rm -f "$mem"
  return "$rc"
}

self_test() {
  t=$(mktemp -d)
  mkdir -p "$t/both/pit-v1/composition" "$t/one/pit-v1/composition" "$t/inh/pit-v1/composition" \
    "$t/inh/pit-v2/composition" "$t/ok/pit-v1/composition" "$t/ok/pit-v2/composition"
  for r in both one inh ok; do printf '# fixture\ntop-3000-2009 OLD NEW\n' > "$t/$r/pit-v1/twin-drops.txt"; done
  printf '((entries (((symbol OLD) (weight 1)) ((symbol NEW) (weight 1)))))\n' > "$t/both/pit-v1/composition/top-3000-2009.sexp"
  for r in one inh ok; do
    printf '((entries (((symbol NEW) (weight 1)) ((symbol OLDX) (weight 1)))))\n' > "$t/$r/pit-v1/composition/top-3000-2009.sexp"
  done
  # v2: another family, same year; inh re-admits OLD next to NEW and writes no row for it, ok keeps only NEW.
  for r in inh ok; do printf 'top-4000-2009 X Y\n' > "$t/$r/pit-v2/twin-drops.txt"; done
  printf '((entries (((symbol Y) (weight 1))\n  ((symbol OLD) (weight 1)) ((symbol NEW) (weight 1)))))\n' > "$t/inh/pit-v2/composition/top-4000-2009.sexp"
  printf '((entries (((symbol Y) (weight 1)) ((symbol NEW) (weight 1)))))\n' > "$t/ok/pit-v2/composition/top-4000-2009.sexp"
  rc=0
  if check_root "$t/both" > /dev/null; then echo "FAIL: self-test: a list holding both legs passed"; rc=1; fi
  if ! check_root "$t/one" > /dev/null; then echo "FAIL: self-test: a list holding only the survivor failed"; rc=1; fi
  if check_root "$t/inh" > /dev/null; then echo "FAIL: self-test: an earlier vintage's twin back in a same-year list passed"; rc=1; fi
  if ! check_root "$t/ok" > /dev/null; then echo "FAIL: self-test: a later vintage holding only the survivor failed"; rc=1; fi
  rm -rf "$t"
  return "$rc"
}

self_test || exit 1

ROOT=$(repo_root)
PIT=${TWIN_PIT_ROOT:-$ROOT/trading/test_data/backtest_scenarios}
[ -n "$(vintages "$PIT")" ] || die "pit_twin_cooccur_check: no pit-vN dir with twin-drops.txt under $PIT"
if check_root "$PIT"; then
  echo "OK: pit_twin_cooccur_check: every vintage's twin drops hold, own and inherited"
else
  echo "FAIL: pit_twin_cooccur_check: a rename twin pair co-occurs in a composition list (see above)."
  echo "Re-apply the drops with dev/experiments/v12-twin-scan-2026-10-22/apply-drops.sh <drops> <lists> and record them in the vintage's twin-drops.txt."
  exit 1
fi

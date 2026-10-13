#!/bin/sh
# results/membership.txt: "<SYM> <list years...>" from the PIT top-3000 v12 lists (list Y applies from Y-05-31).
E=dev/experiments/short-setup-map-2026-10-12; C=trading/test_data/backtest_scenarios/pit-v12/composition
for f in $C/top-3000-*.sexp; do y=$(basename $f .sexp | sed 's/top-3000-//')
  grep -oE '\(symbol [^)]+\)' $f | sed "s/(symbol //;s/)//;s/\$/ $y/"; done |
  awk '{m[$1]=m[$1]" "$2} END{for(s in m) print s m[s]}' | sort > $E/results/membership.txt

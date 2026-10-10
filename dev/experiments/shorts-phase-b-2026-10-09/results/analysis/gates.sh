#!/bin/sh
# Validity gates 1-5 and 7 (README §Validity gates), from the committed logs and validator reports, plus the
# lists md5 recomputed from git for the rebaseline-v12 run SHA and both lanes' run SHAs. Gate 6 is decision8.sh.
# usage: sh gates.sh   (from the repo root)
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/common.sh"
L=trading/test_data/backtest_scenarios/pit-v12/composition
echo "=== gate 1: lists = warehouse (launch logs), lists md5 recomputed from git blobs"
grep -h -E 'lists md5|warehouse entries|staged' "$R/launch-A-pre.log" "$R/launch-B-pre.log"
for c in 3f0f6333d 10f725ffe 27881ae05; do
  printf '  md5 of top-3000-1999 + top-3000-2000..2025 at %s (git show): ' "$c"
  { git show "$c:$L/top-3000-1999.sexp"; y=2000; while [ $y -le 2025 ]; do git show "$c:$L/top-3000-$y.sexp"; y=$((y+1)); done; } | md5_of_stdin
done
echo "  (3f0f6333d = rebaseline-v12's run SHA, whose launch-pre.log printed b62da7e2c4958c42a9805c89222c2d88)"
grep -h -o 'n_symbols=[0-9]* misses_per_symbol=[0-9.]* n_symbols_touched=[0-9]* n_symbols_absent=[0-9]*' "$R/chain-A.log" "$R/chain-B.log" | sort | uniq -c
echo "  rebaseline-v12 chain-R.log, same counters:"; grep -h -o "misses=[0-9]* miss_absent=[0-9]* evictions=[0-9]* n_symbols=[0-9]*" "$R/../../rebaseline-v12-2026-10-08/results/chain-R.log" | sort | uniq -c
echo "=== gate 2: V6 per cell (validator report)"
for c in $CELLS; do
  awk -v c="$c" '/\(id V6\)/ { getline l; s=$0 " " l; match(s, /n_violations [0-9]+/); print "  " c " V6 " substr(s, RSTART, RLENGTH) }' "$R/$c-v12-validator.sexp.sexp"
done
echo "=== gate 3: validator_diff -check V6 v1 vs v0 (chain-B.log)"
grep -o 'RESULT v1-26-s[0-9]-v12 .*v6diff:[^ ]*' "$R/chain-B.log" | sed -E 's/RESULT (v1-26-s[0-9]-v12) .*(v6diff:[^ ]*)/  \1 \2/'
echo "=== gate 4: same build (lane-B replay of v0 s0)"
grep -h -E 'HEAD=|REPLAY|reused' "$R/chain-A.log" "$R/chain-B.log" | sed 's/^/  /'
echo "=== gate 5: every cell wrote actual.sexp (exit line of each log; wall and peak RSS from the chain logs)"
for c in $CELLS; do printf '  %s %s actual.sexp=%s\n' "$c" "$(tail -1 "$R/$c-v12.log")" "$( [ -s "$R/$c-v12-actual.sexp" ] && echo yes || echo NO)"; done
grep -h -o 'RESULT v[01]-26-s[0-9]-v12 => total_return_pct [-0-9.]*\|peak_rss_kb=[0-9]*\|(wall [0-9]*s)' "$R/chain-A.log" "$R/chain-B.log" | paste - - - | sed 's/^/  /'
echo "=== gate 7: run-tree SHAs and staged inputs"
for c in $CELLS; do printf '  %s code_version %s\n' "$c" "$(sed -nE 's/.*code_version ([0-9a-f]+).*/\1/p' "$R/$c-v12-params.sexp" | cut -c1-9)"; done
echo "=== metric-glob tripwire (one total_return_pct per RESULT line)"
for f in "$R/chain-A.log" "$R/chain-B.log"; do awk '{n=gsub(/total_return_pct/,"&"); if (n>1) print FILENAME": "n" per line"}' "$f"; done
echo "  (no line above = clean)"
echo "=== validator counts per cell (non-passing checks)"
for c in $CELLS; do
  awk -v c="$c" '/\(id V[0-9]+\)/ { s=$0; getline l; s=s " " l; match(s, /\(id V[0-9]+\)/); id=substr(s, RSTART+4, RLENGTH-5)
       if (match(s, /n_violations [0-9]+/)) { v=substr(s, RSTART+13, RLENGTH-13)+0; if (v>0) out=out " " id "=" v } }
     END { print "  " c out }' "$R/$c-v12-validator.sexp.sexp"
done

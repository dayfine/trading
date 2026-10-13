#!/bin/sh
# Score-threshold check (2026-10-12): does a stricter short screener score select better shorts?
# Run from the repo root. Inputs: the v0 s0 trade audit (sweep output, not committed: AUDIT=...), the committed
# v0/v1 s0 trades.csv, and host data/ bars (gitignored; SPY md5 447bca148f4385bcd3b5c19a144f21bf).
set -eu
D=dev/experiments/shorts-phase-b-2026-10-09/results/analysis/score-threshold
R=dev/experiments/shorts-phase-b-2026-10-09/results
AUDIT=${AUDIT:-.sweep-output/shorts-phase-b-v1/v0-26-s0-v12-trade_audit.sexp}
if [ -f "$AUDIT" ]; then awk -f $D/extract_pool.awk "$AUDIT" | sort -u -t, -k1,2 > $D/pool.csv; fi
: > $D/fwd.csv
for s in $(cut -d, -f1 $D/pool.csv | sort -u); do
  f=data/$(printf %s "$s" | cut -c1)/$(printf %s "$s" | rev | cut -c1)/$s/data.csv
  [ -f "$f" ] && awk -F, -v S="$s" -f $D/fwd.awk $D/pool.csv "$f" >> $D/fwd.csv
done
sort -o $D/fwd.csv $D/fwd.csv
awk -F, -f $D/excess.awk data/S/Y/SPY/data.csv $D/fwd.csv > $D/excess.csv
{ for H in 20 60 120; do echo "== +$H bars: candidate short return minus SPY short (+ = stock fell more than SPY)"
    for t in 0 85 90 95 100 105 110; do awk -F, -v H=$H -v T=$t -f $D/bucket.awk $D/excess.csv; done; done
  echo "== +60 bars, absolute"
  for t in 0 100 105; do awk -F, -v T=$t '$3>=T{n++; a+=$7; if($7>0)p++} END{printf "  score>=%3d n=%4d fell=%4.1f%% mean short return %+5.1f%%\n",T,n,100*p/n,100*a/n}' $D/fwd.csv; done
} > $D/pool-summary.txt
for a in v0 v1; do echo "== $a s0 filled shorts"; awk -F, -f $D/trades.awk $R/$a-26-s0-v12-trades.csv; done > $D/trades-summary.txt
# Sector x RS split of the filled shorts: the entry record's first sector_rating and rs_trend per position_id.
for a in v0 v1; do A=$(dirname "$AUDIT")/$a-26-s0-v12-trade_audit.sexp
  if [ -f "$A" ]; then grep -o '(position_id [^)]*)\|(sector_rating [A-Za-z]*)\|(rs_trend ([A-Za-z_]*)' "$A" | awk '
    /position_id/ { p = $2; sub(/\)/, "", p); next }
    /sector_rating/ { if (!(p in sr)) { sr[p] = $2; sub(/\)/, "", sr[p]) } }
    /rs_trend/ { if (!(p in rt)) { x = $2; gsub(/[()]/, "", x); rt[p] = x } }
    END { for (p in sr) print p "," sr[p] "," rt[p] }' | sort > $D/entry-attrs-$a.csv; fi
  echo "== $a s0 filled shorts by sector/RS"; awk -F, -f $D/sector_rs.awk $D/entry-attrs-$a.csv $R/$a-26-s0-v12-trades.csv | sort
done > $D/sector-rs-summary.txt
# Score >= 100 vs < 100 among filled shorts, with and without the HRC 2005 data-defect trade (HRC-wein-121, v0 only).
for a in v0 v1; do for x in "" HRC-wein-121; do echo "== $a s0 ${x:+excluding $x}"
  awk -F, -v CUT=100 -v EXCL="$x" -f $D/split.awk $R/$a-26-s0-v12-trades.csv; done; done > $D/trades-split-100.txt
# Pool: how many raw candidate rows were skipped for No_structural_stop (the book could not have taken them).
if [ -f "$AUDIT" ]; then printf 'raw short alternatives %s; No_structural_stop %s\n' \
  "$(grep -c '(side Short) (score' "$AUDIT")" "$(grep -A1 '(side Short) (score' "$AUDIT" | grep -c 'No_structural_stop')" > $D/pool-skip-reasons.txt; fi

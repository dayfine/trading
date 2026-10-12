#!/bin/sh
# breadth-fix-rb1-2026-10-11: regenerate the figures in the results reading (host-only; POSIX sh + awk).
#   R  = committed results dir          SO = host sweep output root (trade_audit.sexp lives only there)
#   SPY = host SPY bars (adjusted_close) PN / PO = review-pack site/data dirs for N and O (daily invested %)
# PO: sh dev/scripts/review_pack.sh --out <dir> --no-container s0=$SO/breadth-pair-O/rb1-26-s0-v12- s1=... s2=...
set -eu
H=$(cd "$(dirname "$0")" && pwd)
R=${R:?results dir}; SO=${SO:?sweep output root}; SPY=${SPY:?SPY data.csv}; PN=${PN:?N pack data}; PO=${PO:?O pack data}
W=${W:-$H/out}; mkdir -p "$W"; cd "$W"
# Read 2 -- weekly macro readings (macro_trend.sexp is identical across salts within an arm)
for a in O N; do
  sed -nE 's/.*\(date ([0-9-]+)\) \(trend ([A-Za-z]+)\) \(breadth_state ([A-Za-z_]+)\).*/\1 \2 \3/p' "$R/$a-rb1-26-s0-v12-macro_trend.sexp" > macro_$a.txt
done
paste -d' ' macro_O.txt macro_N.txt > macro_ON.txt
awk '{y=substr($1,1,4); w[y]++; if($2!=$5) t[y]++; if($3!=$6) b[y]++; o[y" "$2]++; n[y" "$5]++}
  END{for(y=2000;y<=2026;y++) printf "%d weeks %d trend_diff %d bstate_diff %d | O B/N/Bear %d/%d/%d | N %d/%d/%d\n", y, w[y], t[y], b[y],
      o[y" Bullish"], o[y" Neutral"], o[y" Bearish"], n[y" Bullish"], n[y" Neutral"], n[y" Bearish"]}' macro_ON.txt > read2_by_year.txt
awk '$2!=$5{c[$2"->"$5]++} END{for(k in c) print k, c[k]}' macro_ON.txt > read2_transitions.txt
# Read 3 -- NAV paths + SPY TR on NAV dates (holidays carry the last SPY close)
for a in O N; do for s in 0 1 2; do cut -d, -f2 "$R/$a-rb1-26-s$s-v12-equity_curve.csv" > c_$a$s; done; done
cut -d, -f1 "$R/O-rb1-26-s0-v12-equity_curve.csv" > c_d
paste -d, c_d c_O0 c_O1 c_O2 c_N0 c_N1 c_N2 | tail -n +2 > nav.csv
awk -F, 'NR>1{print $1","$6}' "$SPY" > spy_all.csv
awk -F, 'NR==FNR{s[$1]=$2; next} { if($1 in s) l=s[$1]; print $0","l }' spy_all.csv nav.csv > navspy.csv
awk -f "$H/whole.awk" navspy.csv > read3_whole.txt
awk -f "$H/years.awk" navspy.csv > read3_years.txt
# SPY regime (pack rule, with a pre-window warm-up) and the packs' daily invested %
awk -F, '$1>="1998-06-01" && $1<="2026-06-25"' spy_all.csv | awk -f "$H/regime.awk" > spy_regime.csv
for a in O N; do d=$PN; [ $a = O ] && d=$PO; for s in 0 1 2; do
  tr -d '[]"' < "$d/s${s}_nav.json" | awk -F, '{for(i=1;i<=NF;i+=4) print $i","$(i+1)","$(i+2)","$(i+3)}' > expo_${a}_s$s.csv
done; done
for s in 0 1 2; do awk -F, -f "$H/perlog.awk" expo_O_s$s.csv expo_N_s$s.csv; done > read3_period_logdelta.txt
for p in 2000-03-24:2002-10-09 2007-10-09:2009-03-09 2022-01-03:2022-10-12; do
  for a in O N; do for s in 0 1 2; do awk -F, -v d0=${p%%:*} -v d1=${p##*:} -v tag=$a-s$s -f "$H/bear.awk" spy_regime.csv expo_${a}_s$s.csv; done; done
done > read3_bears.txt
for p in 2000-01-01:2026-06-30 2000-01-01:2002-12-31 2003-01-01:2007-12-31 2008-01-01:2009-12-31 2010-01-01:2016-12-31 2017-01-01:2018-12-31 2019-01-01:2026-06-30; do
  echo "== $p"; for a in O N; do for s in 0 1 2; do awk -F, -v d0=${p%%:*} -v d1=${p##*:} -v tag=$a-s$s -f "$H/regsplit2.awk" spy_regime.csv expo_${a}_s$s.csv; done; done
  for s in 0 1 2; do printf "N-O s$s log by regime: "; awk -F, -v d0=${p%%:*} -v d1=${p##*:} -f "$H/reglog.awk" spy_regime.csv expo_O_s$s.csv expo_N_s$s.csv; done
done > rv2_regime_by_period.txt
# Read 4 -- entries gained / lost on symbol|entry_date, classified by the other arm's gate at the decision week
for a in O N; do for s in 0 1 2; do
  awk -f "$H/audit_entries.awk" "$SO/breadth-pair-$a/rb1-26-s$s-v12-trade_audit.sexp" > aud_${a}_s$s.txt
  awk -f "$H/cascade.awk" "$SO/breadth-pair-$a/rb1-26-s$s-v12-trade_audit.sexp" > casc_${a}_s$s.txt
done; done
for s in 0 1 2; do
  awk -F, -f "$H/join.awk" "$R/O-rb1-26-s$s-v12-trades.csv" "$R/N-rb1-26-s$s-v12-trades.csv" > read4_sets_s$s.txt
  awk -f "$H/classify.awk" macro_ON.txt aud_O_s$s.txt aud_N_s$s.txt "$R/O-rb1-26-s$s-v12-trades.csv" "$R/N-rb1-26-s$s-v12-trades.csv" > read4_cls_s$s.txt 2> read4_cls_summary_s$s.txt
  awk -f "$H/flipbuys.awk" macro_ON.txt aud_N_s$s.txt "$R/N-rb1-26-s$s-v12-trades.csv" | sort > read4_unlocked_week_buys_s$s.txt
done
# Pack card vs V23: fills after a Bearish reading, <= fill date (pack) and strictly before (V23)
for s in 0 1 2; do for a in O N; do c=2; [ $a = N ] && c=5
  printf "%s s%s pack-rule " $a $s; awk -v col=$c -f "$H/against.awk" macro_ON.txt "$R/$a-rb1-26-s$s-v12-trades.csv"
  printf "%s s%s V23-rule  " $a $s; awk -v col=$c -f "$H/against_lt.awk" macro_ON.txt "$R/$a-rb1-26-s$s-v12-trades.csv"
done; done > pack_vs_v23.txt
# Small extracts worth committing (cascade weeks + every non-No_structural_stop decision)
for a in O N; do for s in 0 1 2; do awk '$1=="W" || ($1=="D" && $5!="Skipped_No_structural_stop")' casc_${a}_s$s.txt > casc_small_${a}_s$s.txt; done; done
echo "done: $W"

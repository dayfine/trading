#!/bin/sh
# Pre-registered reading item 2 (liveness) and the #3131 after-merge item, per cell:
# tickets placed / filled / cancelled by reason / never filled (trade_audit.sexp); fills by calendar year and by
# screen week at fill (latest macro_trend row on or before the fill date, over trades.csv + open_positions.csv,
# as Phase A rule 3); Bearish screening weeks and how many admitted a short to the top-N (cascade_summaries);
# top-N decision outcomes; tickets placed at an order price under $17; churn signature (fill < $17 and a
# margin_call exit within 4 days); every non-Bearish fill traced (placement week, age, P&L).
# usage: sh liveness.sh   (after prep.sh)
set -eu
HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/common.sh"
for c in $CELLS; do
  T="$R/$c-v12-trades.csv"; O="$R/$c-v12-open_positions.csv"; AU="$WORK/$c.audit.tsv"
  echo "=== $c"
  if [ -s "$AU" ]; then
    awk -F'\t' '$1=="T" { n++; if ($16!="-") f++; else if ($14!="-") cr[$14]++; else nf++
        if ($15!="-" && $15+0 < 17) lo++; if ($5!="Short") ns++ }
      END { printf "  tickets placed %d, filled %d, never filled %d, non-short %d, order price < $17: %d\n", n, f, nf+0, ns+0, lo+0
            for (k in cr) printf "  cancelled %s: %d\n", k, cr[k] }' "$AU"
    awk -F'\t' '$1=="T" && $16!="-" { a=$12+0; b=(a>=4 ? "4+" : a); h[b]++ } END { printf "  fills by ticket age (weeks):"; for (k in h) printf " %s=%d", k, h[k]; print "" }' "$AU"
    awk -F'\t' '$1=="T" && $16=="-" && $13!="-" { a=$13+0; h[$14 " age " a]++ } END { for (k in h) printf "  cancel %s: %d\n", k, h[k] }' "$AU" | sort
    awk -F'\t' '$1=="C" { w[$3]++; if ($9+0>0) adm[$3]++; pl+=$11; ss+=$12; nc+=$13; sz+=$14; sc+=$15; ot+=$16 }
      END { for (k in w) printf "  screening weeks %s: %d, admitted a short to the top-N: %d\n", k, w[k], adm[k]+0
            printf "  top-N decisions: Placed %d, Skipped No_structural_stop %d, Short_notional_cap %d, Sized_to_zero %d, Share_class_held %d, other %d\n", pl, ss, nc, sz, sc, ot }' "$AU" | sort
  else echo "  (no trade audit)"; fi
  { tail -n +2 "$T" | awk -F, '{print $3 " " $1 " closed " $20 " " $6 " " $9 " " $13 " " $4}'
    tail -n +2 "$O" | awk -F, '{print $3 " " $1 " open - " $4 " 0 - -"}'; } | sort > "$WORK/$c.entries.txt"
  awk 'NR==FNR { d[NR]=$1; t[NR]=$2; n=NR; next }
       { tr="NONE"; for (i=1; i<=n; i++) { if (d[i] <= $1) tr=t[i]; else break } print $0, tr }' "$WORK/macro.txt" "$WORK/$c.entries.txt" > "$WORK/$c.entries_tr.txt"
  awk '{ c[$9]++; y[substr($1,1,4)]++; if ($3=="open") o++ } END { printf "  fills (closed + open): %d (open %d); by screen week at fill:", NR, o+0; for (k in c) printf " %s=%d", k, c[k]; print ""
        printf "  fills by year:"; for (k in y) printf " %s=%d", k, y[k]; print "" }' "$WORK/$c.entries_tr.txt"
  awk '{ y=substr($1,1,4); if (y=="2008") n8++ } END { printf "  #3131 liveness: fills %d (>= 10: %s), in 2008 %d (>= 5: %s)\n", NR, (NR>=10?"yes":"NO"), n8+0, (n8>=5?"yes":"NO") }' "$WORK/$c.entries_tr.txt"
  awk '$5+0 < 17 { n++; s=s " " $2 "@" $5 } END { printf "  fills below $17: %d%s\n", n+0, s }' "$WORK/$c.entries_tr.txt"
  awk -F, 'NR>1 && $6+0 < 17 && $13=="margin_call" && $5+0 <= 4 { n++ } END { printf "  churn signature (fill < $17, margin_call within 4 days): %d\n", n+0 }' "$T"
  if [ -s "$AU" ]; then
    awk -F'\t' '$1=="T" { print $2, $11, $12, $6 }' "$AU" > "$WORK/$c.tick.txt"
    awk 'NR==FNR { pl[$1]=$2; ag[$1]=$3; md[$1]=$4; next }
      $9!="Bearish" && $3=="closed" { printf "  non-Bearish fill: %s %s (screen %s) placed %s (%s) age %s wk, pnl %s, exit %s %s\n", $2, $1, $9, pl[$4], md[$4], ag[$4], $6, $7, $8; n++; s+=$6 }
      END { printf "  non-Bearish fills: %d, P&L %.0f\n", n+0, s }' "$WORK/$c.tick.txt" "$WORK/$c.entries_tr.txt"
  fi
done

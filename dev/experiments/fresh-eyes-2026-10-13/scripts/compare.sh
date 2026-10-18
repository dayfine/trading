#!/bin/sh
# compare.sh: the forward pass against our classifier (plan section 5), host only, no model calls.
# Inputs: results/forward/{decisions,trades}.csv (collected from the run dirs) and our weekly stages per symbol
# (STAGES, default .sweep-output/short-setup-map/stages/<SYM>.csv). Writes results/forward/compare-*.txt.
# Run from the repo root. Our record run took none of the finished symbols (capital-bound top-N book), so trades
# are compared with our stage at entry, not with our trades.
set -eu
E=dev/experiments/fresh-eyes-2026-10-13; F=$E/results/forward
STAGES=${STAGES:-.sweep-output/short-setup-map/stages}
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
for s in $(awk -F, 'NR>1{print $1}' "$F/decisions.csv" | sort -u); do
  [ -f "$STAGES/$s.csv" ] && awk -F, -v s="$s" 'NR>1{print s","$2","substr($5,6,1)}' "$STAGES/$s.csv"
done > "$tmp"
awk -F, -v out="$F/compare-stages.txt" '
  FNR==NR { ours[$1","$2]=$3; next }
  FNR==1 { next }
  { k=$1","$2; if (!(k in ours)) { miss++; next }
    a=$3; o=ours[k]; n++; m[a","o]++; if (a==o) agree++
    y=substr($2,1,4); ny[y]++; if (a==o) ay[y]++ }
  END {
    printf "matched cuts %d (no stage row: %d)\nagreement %.1f %%\n\nconfusion (rows: reader stage, cols: our stage)\n", n, miss, 100*agree/n > out
    printf "      ours1  ours2  ours3  ours4\n" > out
    for (a=1;a<=4;a++) { printf "rd%d  ", a > out; for (o=1;o<=4;o++) printf "%6d ", m[a","o] > out; printf "\n" > out }
    printf "\nagreement by year\n" > out
    for (y=2000;y<=2026;y++) if (ny[y]) printf "%d %4d %5.1f %%\n", y, ny[y], 100*ay[y]/ny[y] > out
  }' "$tmp" "$F/decisions.csv"
# trades: our stage on the last Friday on or before the entry date
awk -F, -v out="$F/compare-trades.txt" '
  FNR==NR { d[$1]=d[$1] " " $2 ":" $3; next }
  FNR==1 { next }
  { s=$1; side=$2; e=$3; st="?"; nf=split(d[s], w, " ")
    for (i=1;i<=nf;i++) { split(w[i], p, ":"); if (p[1] <= e) st=p[2]; else break }
    k=side",ours"st; n[k]++; r[k]+=$8; x[k]+=$10; if ($10>0) b[k]++
    ns[side]++; rs[side]+=$8; xs[side]+=$10; if ($10>0) bs[side]++; h[side","$7]++ }
  END {
    printf "reader trades by side\nside   n  mean_ret  mean_excess_vs_spy  beat_spy\n" > out
    for (sd in ns) printf "%-6s %3d %8.2f %%  %8.2f %%  %5.1f %%\n", sd, ns[sd], 100*rs[sd]/ns[sd], 100*xs[sd]/ns[sd], 100*bs[sd]/ns[sd] > out
    printf "\nexits\n" > out; for (k in h) printf "%s %d\n", k, h[k] > out
    printf "\nby our stage at entry\nkey             n  mean_ret  mean_excess  beat_spy\n" > out
    for (k in n) printf "%-14s %3d %8.2f %% %8.2f %%  %5.1f %%\n", k, n[k], 100*r[k]/n[k], 100*x[k]/n[k], 100*b[k]/n[k] > out
  }' "$tmp" "$F/trades.csv"
cat "$F/compare-stages.txt" "$F/compare-trades.txt"

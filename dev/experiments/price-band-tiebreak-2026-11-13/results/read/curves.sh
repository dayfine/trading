#!/bin/sh
# curves.sh -- from the two equity curves of each seed: (1) each arm's max drawdown with its peak and trough dates and
# its second-worst distinct episode; (2) year-end ln(NAV_P / NAV_S), the running log gap, per seed.
# usage: sh curves.sh RESULTS_DIR
R=${1:?usage: sh curves.sh RESULTS_DIR}
for k in 0 1 2 3 4; do
  for a in S P; do
    awk -F, -v k="k$k" -v a="$a" 'FNR > 1 { v = $2 + 0
        if (v > pk) { if (pk > 0 && dd > 0.10) { ep[++ne] = sprintf("%.1f%% %s->%s", 100 * dd, pkd, trd) } pk = v; pkd = $1; dd = 0 }
        else if (1 - v / pk > dd) { dd = 1 - v / pk; trd = $1 } }
      END { if (dd > 0.10) ep[++ne] = sprintf("%.1f%% %s->%s (open)", 100 * dd, pkd, trd)
            printf "%s %s DD episodes >10%%:", k, a; for (i = 1; i <= ne; i++) printf " [%s]", ep[i]; print "" }' \
      "$R/k$k/pb-$a-k$k-s0-equity_curve.csv"
  done
done
echo
printf 'year-end ln(NAV_P/NAV_S)\nyear'; for k in 0 1 2 3 4; do printf '\tk%s' "$k"; done; printf '\n'
for k in 0 1 2 3 4; do
  awk -F, -v k="$k" 'FNR == 1 { f++; next } { y = substr($1, 1, 4); if (f == 1) s[y] = $2; else p[y] = $2; ys[y] = 1 }
    END { for (y in ys) printf "%s\t%d\t%.4f\n", y, k, log(p[y] / s[y]) }' \
    "$R/k$k/pb-S-k$k-s0-equity_curve.csv" "$R/k$k/pb-P-k$k-s0-equity_curve.csv"
done | sort -k1,1 -k2,2n | awk -F'\t' '{ if ($1 != y) { if (y != "") print line; y = $1; line = y } line = line "\t" $3 } END { print line }'

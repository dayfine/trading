#!/bin/sh
# arm_table.sh -- the per-seed, per-arm figures the price-band README pre-registers (§Decision rule, §Reported
# regardless), recomputed from the collected artifacts only. POSIX sh + awk.
#
# usage: sh arm_table.sh RESULTS_DIR      (RESULTS_DIR holds k0..k4/pb-{S,P}-kK-s0-*)
#
# Entries = trades.csv rows + open_positions.csv rows (README §Decision rule). Price = trades.csv entry_price ($6) /
# open_positions.csv entry_price ($4). Bands follow the mechanism's price_band (#3587 screener_ranking.ml:24): band =
# number of edges [8;14;33] <= price, i.e. <8 | [8,14) | [14,33) | >=33. The rule's liveness shares use <= 14 and <= 8
# (inclusive), as written. ge100 = closed trades with pnl_percent >= 100 (trades.csv $10).
# Output (TSV): seed arm R% ln(1+R) maxDD sharpe calmar trades open entries le14 le8 s14% s8% b0 b1 b2 b3 ge100 anchors
R=${1:?usage: sh arm_table.sh RESULTS_DIR}
printf 'seed\tarm\tR_pct\tln1R\tmaxDD\tsharpe\tcalmar\ttrades\topen\tentries\tle14\tle8\ts14\ts8\tb_lt8\tb_8_14\tb_14_33\tb_ge33\tge100\tanchors\n'
for k in 0 1 2 3 4; do
  for a in S P; do
    p=$R/k$k/pb-$a-k$k-s0-
    tr '\n' ' ' < "${p}actual.sexp" | awk -v k="$k" -v a="$a" '
      function grab(key,   re) { re = "\\(" key " [-0-9.e+]+\\)"
        if (match($0, re)) return substr($0, RSTART + length(key) + 2, RLENGTH - length(key) - 3); return "NA" }
      { r = grab("total_return_pct"); printf "%s\t%s\t%.2f\t%.4f\t%.2f\t%.3f\t%.3f\t", "k" k, a, r, log(1 + r / 100),
          grab("max_drawdown_pct"), grab("sharpe_ratio"), grab("calmar_ratio") }'
    awk -F, '
      FNR == 1 { next }
      FILENAME ~ /trades\.csv$/ { px = $6 + 0; nt++; if ($10 + 0 >= 100) g++; an[$24]++ }
      FILENAME ~ /open_positions\.csv$/ { px = $4 + 0; no++ }
      { n++; if (px <= 14) l14++; if (px <= 8) l8++
        b = (px >= 8) + (px >= 14) + (px >= 33); bc[b]++ }
      END { printf "%d\t%d\t%d\t%d\t%d\t%.2f\t%.2f\t%d\t%d\t%d\t%d\t%d\t", nt, no, n, l14, l8, 100 * l14 / n, 100 * l8 / n,
              bc[0], bc[1], bc[2], bc[3], g
            s = ""; for (x in an) s = s x ":" an[x] ","; print s }' "${p}trades.csv" "${p}open_positions.csv"
  done
done

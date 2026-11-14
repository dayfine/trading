#!/bin/sh
# report.sh -- the README's §Reported regardless tables for ONE cell, from the collected artifacts and positions.tsv.
# Descriptive only; the verdict is decide.sh's. Prints:
#   A. per seed and arm: R, ln(1+R), max DD, Sharpe, Ulcer, closed trades, open, entries by band (<8 | 8-14 | 14-33 |
#      >=33, split-restatement corrected, positions.sh column 9) and closed trades at >= +100 %;
#   B. the one-arm net (P-only minus S-only, points of entry NAV) by band, per seed and pooled, and by entry era;
#   C. year-end ln(NAV_P / NAV_S) per seed, and its change from the end of 2012 to the last date (the 2013-26 increment);
#   D. the five largest one-arm contributors per seed and side: entry date, entry_price (marked "split-restated" when
#      positions.sh px_ratio is outside 0.80-1.25, #3595 §Defects 2), band (corrected), P&L %, share of entry NAV.
#      The ratio itself is not printed: with entry_price it would give the raw close, which stays out of any output.
#
# usage: sh report.sh RESULTS_DIR TAG POSITIONS_TSV
R=${1:?usage: sh report.sh RESULTS_DIR TAG POSITIONS_TSV}; T=${2:?}; POS=${3:?}

echo "A. per seed and arm"
printf 'seed\tarm\tR_pct\tln1R\tmaxDD\tsharpe\tulcer\tclosed\topen\tentries\tb_lt8\tb_8_14\tb_14_33\tb_ge33\tge100\n'
for k in 0 1 2 3 4; do
  for a in S P; do
    p=$R/k$k/$T-$a-k$k-s0-; [ -s "${p}actual.sexp" ] || continue
    m=$(tr '\n' ' ' < "${p}actual.sexp" | awk '
      function grab(key,   re) { re = "\\(" key " [-0-9.e+]+\\)"
        if (match($0, re)) return substr($0, RSTART + length(key) + 2, RLENGTH - length(key) - 3); return "NA" }
      { r = grab("total_return_pct"); printf "%.2f\t%.4f\t%.2f\t%.3f\t%.2f", r, log(1 + r / 100), grab("max_drawdown_pct"),
          grab("sharpe_ratio"), grab("ulcer_index") }')
    e=$(awk -F'\t' -v k="k$k" -v a="$a" 'NR > 1 && $1 == k && $3 == a { n++; b[$9]++; if ($7 == "closed") { c++; if ($14 + 0 >= 100) g++ } else o++ }
      END { printf "%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d", c, o, n, b[0], b[1], b[2], b[3], g }' "$POS")
    printf 'k%s\t%s\t%s\t%s\n' "$k" "$a" "$m" "$e"
  done
done

echo; echo "B. one-arm net by band (P-only minus S-only, points of entry NAV; n = P-only/S-only positions)"
awk -F'\t' 'NR > 1 && $2 != "shared" { s[$1, $2, $9] += $13; c[$1, $2, $9]++; S[$1] = 1; t[$2, $9] += $13; tc[$2, $9]++ }
  END { for (k in S) { printf "%s", k; tot = 0
          for (b = 0; b <= 3; b++) { x = s[k, "P-only", b] - s[k, "S-only", b]; tot += x
            printf "  b%d %+.1f (%d/%d)", b, x, c[k, "P-only", b], c[k, "S-only", b] }
          printf "  total %+.1f\n", tot }
        printf "pooled"; tot = 0
        for (b = 0; b <= 3; b++) { x = t["P-only", b] - t["S-only", b]; tot += x; printf "  b%d %+.1f (%d/%d)", b, x, tc["P-only", b], tc["S-only", b] }
        printf "  total %+.1f\n", tot }' "$POS" | sort
awk -F'\t' 'NR > 1 && $2 != "shared" { y = substr($5, 1, 4) + 0
    e = (y <= 2009) ? "2000-09" : (y <= 2012) ? "2010-12" : (y <= 2017) ? "2013-17" : (y <= 2023) ? "2018-23" : "2024-26"
    s[e, $2] += $13; c[e, $2]++; E[e] = 1 }
  END { for (e in E) printf "era %s: P-only %d/%+.1f  S-only %d/%+.1f  net %+.1f\n", e, c[e, "P-only"], s[e, "P-only"], c[e, "S-only"], s[e, "S-only"], s[e, "P-only"] - s[e, "S-only"] }' "$POS" | sort

echo; echo "C. year-end ln(NAV_P / NAV_S); the incr row = change from end-2012 (0 if the cell starts in 2013) to the last date"
for k in 0 1 2 3 4; do
  s=$R/k$k/$T-S-k$k-s0-equity_curve.csv; p=$R/k$k/$T-P-k$k-s0-equity_curve.csv; [ -s "$s" ] && [ -s "$p" ] || continue
  awk -F, -v k="$k" 'FNR == 1 { f++; next } { y = substr($1, 1, 4); if (f == 1) s[y] = $2; else p[y] = $2; ys[y] = 1 }
    END { for (y in ys) { printf "%s\t%d\t%.4f\n", y, k, log(p[y] / s[y]); if (y > last) last = y }
          b = ("2012" in ys) ? log(p["2012"] / s["2012"]) : 0; printf "incr-2013-%s\t%d\t%+.4f\n", substr(last, 3), k, log(p[last] / s[last]) - b }' "$s" "$p"
done | sort -k1,1 -k2,2n | awk -F'\t' '{ if ($1 != y) { if (y != "") print line; y = $1; line = y } line = line "\t" "k" $2 " " $3 } END { print line }'

echo; echo "D. five largest one-arm contributors per seed and side (entry, entry_price, band, P&L %, % of entry NAV)"
for side in P-only S-only; do
  awk -F'\t' -v c="$side" 'NR > 1 && $2 == c { rs = ($15 != "NA" && ($15 < 0.80 || $15 > 1.25)) ? " (split-restated)" : ""
      print $1 "\t" $13 "\t" $4 " " $5 " $" $8 rs " b" $9 " " $14 "% " sprintf("%.1f", $13) }' "$POS" |
    sort -t "$(printf '\t')" -k1,1 -k2,2gr | awk -F'\t' -v c="$side" '{ if ($1 != k) { k = $1; n = 0 } if (++n <= 5) printf "%s %s %d: %s\n", k, c, n, $3 }'
done

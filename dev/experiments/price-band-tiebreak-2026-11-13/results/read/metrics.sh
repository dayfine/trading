#!/bin/sh
# metrics.sh -- per-arm figures the price-band README pre-registers, from collected artifacts.
# usage: sh metrics.sh LABEL=PREFIX ...   (PREFIX + actual.sexp / trades.csv / open_positions.csv)
# prints: label R% ln(1+R) maxDD sharpe trades | entries le14 le8 share14 share8 | ge100 | anchors
for a in "$@"; do
  lab=${a%%=*}; p=${a#*=}
  m=$(tr '\n' ' ' < "${p}actual.sexp" | awk '{
        match($0, /total_return_pct [-0-9.e]+/); r = substr($0, RSTART + 17, RLENGTH - 17)
        match($0, /sharpe_ratio [-0-9.e]+/); s = substr($0, RSTART + 13, RLENGTH - 13)
        match($0, /max_drawdown_pct [-0-9.e]+/); d = substr($0, RSTART + 17, RLENGTH - 17)
        match($0, /total_trades [0-9]+/); t = substr($0, RSTART + 13, RLENGTH - 13)
        printf "R=%.2f%% ln=%.4f dd=%.2f sh=%.3f trades=%d", r, log(1 + r / 100), d, s, t }')
  e=$(awk -F, 'FNR == 1 { next }
        FILENAME ~ /trades\.csv$/ { px = $6; n++; if ($10 + 0 >= 100) g++; an[$24]++ }
        FILENAME ~ /open_positions\.csv$/ { px = $4; n++; an["(open)"]++ }
        { if (px + 0 <= 14) l14++; if (px + 0 <= 8) l8++ }
        END { printf "entries=%d le14=%d le8=%d s14=%.1f%% s8=%.1f%% ge100=%d anchors=", n, l14, l8, 100 * l14 / n, 100 * l8 / n, g
              for (k in an) printf "%s:%d,", k, an[k] }' "${p}trades.csv" "${p}open_positions.csv")
  echo "$lab $m $e"
done

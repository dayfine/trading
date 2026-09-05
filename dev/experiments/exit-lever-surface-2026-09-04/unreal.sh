#!/bin/sh
# unreal.sh OPEN_POSITIONS.csv FINAL_PRICES.csv
# Per-open-position unrealised P&L at window end ((final - entry) * qty),
# largest first, plus the total. The return-vs-realised gap of an arm that
# holds longer (e.g. laggard rotation off) lives here, not in trades.csv.
set -u
awk -F, 'NR == FNR { if (FNR > 1) fp[$1] = $2; next }
  FNR > 1 { u = (fp[$1] - $4) * $5; tot += u
            printf "%+12.0f  %-6s entry %s @%.2f x%d final %.2f\n", u, $1, $3, $4, $5, fp[$1] | "sort -gr" }
  END { close("sort -gr"); printf "%+12.0f  TOTAL unrealised over %d open\n", tot, FNR - 1 }' "$2" "$1"

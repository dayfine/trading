#!/bin/sh
# levels.sh -- README §"Pre-registered reads" #3136 T1, T2 and T4, and §Data P0, from the committed artifacts:
#   P0  W0's actual.sexp / trades.csv / equity_curve.csv against the committed rk-k0 s0 files (cmp)
#   T1  the last line of cw-Wtd-s0.v6diff-W0.log (exit=0 passes); also W0's against the record (label R)
#   T2  trades.csv identical or not; row counts
#   T4  total return, end NAV and the end-NAV log ratio ln(NAV_Wtd / NAV_W0), MaxDD, trades, Sharpe, Calmar
#       (actual.sexp); then the arms' log gap at every calendar year end, and its change per year, so the level delta
#       can be placed in time; the 0.45-log floor is README §Base spec (2 SD of the 26y seed band)
# usage: sh levels.sh RESULTS_DIR RECORD_RESULTS_DIR
#   RESULTS_DIR         dev/experiments/chain-w-2026-11-10/results
#   RECORD_RESULTS_DIR  dev/experiments/record-kseed-2026-10-27/results
set -u
R=${1:?usage: sh levels.sh RESULTS_DIR RECORD_RESULTS_DIR}; K=${2:?}
FLOOR=0.45

echo "P0 parity (W0 vs rk-k0 s0):"
for f in actual.sexp trades.csv equity_curve.csv; do
  if cmp -s "$K/rk-k0-s0-$f" "$R/cw-W0-s0-$f"; then echo "  $f identical"; else echo "  $f DIFFERS"; fi
done
first=$(awk -F, 'NR == FNR { a[$1] = $2; next } FNR > 1 && ($1 in a) && a[$1] != $2 { print $1; exit }' \
  "$K/rk-k0-s0-equity_curve.csv" "$R/cw-W0-s0-equity_curve.csv")
echo "  equity_curve first differing date (W0 vs rk-k0): ${first:-none}"

echo "T1 validity: Wtd vs W0 $(tail -1 "$R/cw-Wtd-s0.v6diff-W0.log"); W0 vs record $(tail -1 "$R/cw-W0-s0.v6diff-R.log")"
if cmp -s "$R/cw-W0-s0-trades.csv" "$R/cw-Wtd-s0-trades.csv"; then t2=identical; else t2=differs; fi
echo "T2 liveness: trades.csv $t2 (W0 $(($(wc -l < "$R/cw-W0-s0-trades.csv") - 1)) rows, Wtd $(($(wc -l < "$R/cw-Wtd-s0-trades.csv") - 1)) rows)"

echo "T4 level (reported, no verdict):"
for a in W0 Wtd; do
  tr -s '() \n' '    ' < "$R/cw-$a-s0-actual.sexp" | awk -v a="$a" '{
    for (i = 1; i < NF; i++) v[$i] = $(i + 1)
    printf "  %-4s total_return_pct %.2f  max_drawdown_pct %.2f  total_trades %d  sharpe %.4f  calmar %.4f\n",
      a, v["total_return_pct"], v["max_drawdown_pct"], v["total_trades"], v["sharpe_ratio"], v["calmar_ratio"] }'
done
awk -F, -v floor="$FLOOR" '
  FNR == 1 { f++; next }
  f == 1 { w0[$1] = $2; last = $1; y = substr($1, 1, 4); ye[y] = $1; next }
  f == 2 { td[$1] = $2 }
  END {
    g = log(td[last] / w0[last])
    printf "  end NAV %s: W0 %.2f  Wtd %.2f  ln(Wtd/W0) = %.4f  (|delta| %s the %.2f-log floor)\n", last, w0[last], td[last], g, (g < floor && g > -floor ? "below" : "AT OR ABOVE"), floor
    print "  arms log gap ln(Wtd/W0) at each year end, and its change in the year:"
    prev = 0
    for (y = 2000; y <= 2026; y++) { d = ye[y]; if (d == "") continue
      x = log(td[d] / w0[d]); printf "    %d  %s  gap %+.4f  change %+.4f\n", y, d, x, x - prev; prev = x }
  }' "$R/cw-W0-s0-equity_curve.csv" "$R/cw-Wtd-s0-equity_curve.csv"

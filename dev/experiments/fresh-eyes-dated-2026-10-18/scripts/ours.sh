#!/bin/sh
# ours.sh <date> <date dir>: our side for one decision date (plan §5), read from the record run's artifacts; no
# model calls. The record is rb1 + full NYSE A-D, 26y, salts 0-2 (not committed): REC (default the parent repo's
# .sweep-output/breadth-pair-N), files $REC/$PFX<salt>-v12-{trade_audit.sexp,trades.csv}, PFX default rb1-26-s.
# Writes into <date dir>/ours/:
#   week.csv     salt,week,macro_trend,long_top_n,short_top_n,entered   the cascade header for that week
#   top.csv      salt,rank,symbol,side,outcome   the screener's decision list for the week of the date (the top-N
#                after the cascade, in list order; outcome Placed or the skip reason)
#   entries.csv  salt,symbol,side,entry_date,exit_date,exit_trigger,ret,spy_ret,excess,days,r104,max104,min104,
#                spy104,end104,position_id   our entries in the 4 weeks after the date (entry_date in
#                [date, date + 28 days]), the trade as the record ran it; ret is a total return (adjusted basis); the
#                104-week path from path.awk (adjusted basis)
# Run from the repo root. DATA = the daily store.
set -e
d=$1; DD=$2
S0=dev/experiments/fresh-eyes-2026-10-13/scripts; S=dev/experiments/fresh-eyes-dated-2026-10-18/scripts
REC=${REC:-/Users/difan/Projects/trading-1/.sweep-output/breadth-pair-N}; PFX=${PFX:-rb1-26-s}
DATA=${DATA:-/Users/difan/Projects/trading-1/data}; SALTS=${SALTS:-0 1 2}
O=$DD/ours; mkdir -p "$O"
echo "salt,rank,symbol,side,outcome" > "$O/top.csv.tmp"; echo "salt,week,macro_trend,long_top_n,short_top_n,entered" > "$O/week.csv.tmp"
echo "salt,symbol,side,entry_date,exit_date,exit_trigger,ret,spy_ret,excess,days,r104,max104,min104,spy104,end104,position_id" > "$O/entries.csv.tmp"
for k in $SALTS; do
  a=$REC/$PFX$k-v12-trade_audit.sexp; t=$REC/$PFX$k-v12-trades.csv
  [ -s "$a" ] && [ -s "$t" ] || { echo "ours.sh: missing $a or $t" >&2; exit 2; }
  awk -v want="$d" -v salt="$k" -v hdr="$O/week.csv.tmp" -f $S0/days.awk -f $S/ours_top.awk "$a" >> "$O/top.csv.tmp"
  hi=$(awk -v d="$d" -f $S0/days.awk -f $S/plus.awk)
  # trades.csv: symbol,side,entry_date,exit_date,days_held,entry_price,exit_price,quantity,pnl_dollars,pnl_percent,
  # entry_stop,exit_stop,exit_trigger ($13),...,position_id ($20). The raw prices go onto the adjusted basis in
  # path.awk (each day's adjusted_close / close), so ret is a total return, comparable with the stepper's.
  awk -F, -v lo="$d" -v hi="$hi" 'NR > 1 && $3 >= lo && $3 <= hi { print $1, tolower($2), $3, $4, $6, $7, $13, $20 }' "$t" |
  while read -r sym side ed xd epx xpx trig pid; do
    p=$DATA/$(printf %s "$sym" | cut -c1)/$(printf %s "$sym" | rev | cut -c1)/$sym/data.csv
    [ -f "$p" ] || { echo "ours.sh: no daily file for $sym" >&2; continue; }
    pr=$(awk -F, -v side="$side" -v ed="$ed" -v xd="$xd" -v epx="$epx" -v xpx="$xpx" -v basis=raw -v xo=0 \
      -f $S0/days.awk -f $S/path.awk "$DATA/S/Y/SPY/data.csv" "$p")
    echo "$k,$sym,$side,$ed,$xd,$trig,$pr,$pid" >> "$O/entries.csv.tmp"
  done
done
mv "$O/week.csv.tmp" "$O/week.csv"; mv "$O/top.csv.tmp" "$O/top.csv"; mv "$O/entries.csv.tmp" "$O/entries.csv"
echo "ours.sh: $d top $(($(wc -l < "$O/top.csv") - 1)) rows, entries $(($(wc -l < "$O/entries.csv") - 1)) rows"

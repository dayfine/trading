#!/bin/sh
# compare_dates.sh <run root> [<out dir>]: the plan §6 reads over every finished date dir under <run root>
# (named YYYY-MM-DD, or YYYY-MM-DD-r<k> for a self-consistency repeat). No model calls. Writes to <out dir>
# (default <run root>/compare):
#   trades.csv    who,date,rep,symbol,side,entry_date,exit_date,how,ret,spy_ret,excess,days,ann_excess,r104,spy104
#                 one row per filled trade, who = reader or ours-s<salt>; ann_excess = ((1 + ret) / (1 + spy_ret))
#                 ^ (365 / days) - 1 (days floored at 7)
#   overlap.csv   read 1: date,rep,side,orders,filled,shortlist,ours_top,orders_in_top,orders_in_entries,
#                 shortlist_in_top (ours = the union over salts)
#   paired.csv    read 3: date,rep,reader_n,reader_mean_excess,ours_n,ours_mean_excess,diff (ours = salt 0;
#                 dates where either side has no trade are listed with an empty diff)
#   shared.csv    read 4: date,rep,symbol,reader_entry,reader_exit,reader_how,reader_ret,reader_r104,ours_entry,
#                 ours_exit,ours_trigger,ours_ret,ours_r104 (salt 0)
#   consistency.csv  read 5: date,rep_a,rep_b,orders_a,orders_b,common,jaccard,median_stop_gap (relative gap of the
#                 initial stop on common names)
#   report.txt    the distributions (read 2: n, mean, median, p10/p25/p75/p90 of excess and ann_excess per who),
#                 the overlap distribution, the paired sign rate, and the consistency summary
set -e
ROOT=$1; O=${2:-$ROOT/compare}
S=dev/experiments/fresh-eyes-dated-2026-10-18/scripts
mkdir -p "$O"
f() { if [ -f "$1" ]; then echo "$1"; else echo /dev/null; fi; }
H="who,date,rep,symbol,side,entry_date,exit_date,how,ret,spy_ret,excess,days,ann_excess,r104,spy104"
echo "$H" > "$O/trades.csv"
echo "date,rep,side,orders,filled,shortlist,ours_top,orders_in_top,orders_in_entries,shortlist_in_top" > "$O/overlap.csv"
for DD in "$ROOT"/[12][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*; do
  [ -f "$DD/reader-trades.csv" ] || [ "$(cat "$DD/side.txt" 2>/dev/null)" = neither ] || continue
  b=$(basename "$DD"); d=$(printf %s "$b" | cut -c1-10); rep=$(printf %s "$b" | cut -c12-); [ -n "$rep" ] || rep=r0
  side=$(cat "$DD/side.txt" 2>/dev/null || echo "?")
  [ -f "$DD/reader-trades.csv" ] && awk -F, -v d="$d" -v rep="$rep" 'NR > 1 && $4 != "" {
      print "reader," d "," rep "," $2 "," $3 "," $4 "," $5 "," $6 "," $7 "," $8 "," $9 "," $10 ",," $11 "," $14 }' "$DD/reader-trades.csv" >> "$O/trades.csv"
  [ "$rep" = r0 ] && [ -f "$DD/ours/entries.csv" ] && awk -F, -v d="$d" 'NR > 1 && $7 != "" {
      print "ours-s" $1 "," d ",r0," $2 "," $3 "," $4 "," $5 "," $6 "," $7 "," $8 "," $9 "," $10 ",," $11 "," $14 }' "$DD/ours/entries.csv" >> "$O/trades.csv"
  awk -F, -v d="$d" -v rep="$rep" -v side="$side" -f $S/overlap.awk "$(f "$DD/ours/top.csv")" "$(f "$DD/ours/entries.csv")" \
    "$(f "$DD/orders.csv")" "$(f "$DD/shortlist.txt")" "$(f "$DD/pool.csv")" "$(f "$DD/reader-trades.csv")" >> "$O/overlap.csv"
done
awk -F, -v OFS=, 'NR == 1 { print; next } { dy = ($12 < 7) ? 7 : $12; $13 = sprintf("%.6f", exp(log((1 + $9) / (1 + $10)) * 365 / dy) - 1); print }' \
  "$O/trades.csv" > "$O/trades.tmp" && mv "$O/trades.tmp" "$O/trades.csv"
awk -F, -v out="$O" -f $S/compare.awk "$O/trades.csv" "$O/overlap.csv" > "$O/report.txt"
# Read 5: self-consistency across repeats of one date (initial stops from orders.csv, symbols via pool.csv).
echo "date,rep_a,rep_b,orders_a,orders_b,common,jaccard,median_stop_gap" > "$O/consistency.csv"
for DD in "$ROOT"/[12][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-r*; do
  [ -f "$DD/orders.csv" ] || continue
  d=$(basename "$DD" | cut -c1-10)
  for EE in "$ROOT/$d" "$ROOT/$d"-r*; do
    [ -f "$EE/orders.csv" ] && [ "$EE" \< "$DD" ] || continue
    awk -F, -v d="$d" -v a="$(basename "$EE")" -v b="$(basename "$DD")" -f $S/consist.awk "$EE/orders.csv" "$DD/orders.csv" >> "$O/consistency.csv"
  done
done
awk -F, 'NR > 1 { n++; j += $7 } END { if (n) printf "\nread 5, self-consistency: %d repeat pairs, mean pick Jaccard %.2f (consistency.csv)\n", n, j / n }' "$O/consistency.csv" >> "$O/report.txt"
cat "$O/report.txt"

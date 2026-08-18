#!/bin/sh
# Realized P&L by ticket REST TIME, joined on position_id.
#
# The metric the TTL re-test README says is needed to resolve the clock arms:
# a clock's gross effect on the top line is 8-30pp against a 132.5pp null, so it
# cannot be read from total_return_pct — but the per-bucket realized P&L of the
# arm's OWN trades is a direct measurement of what a given cut would remove.
#
# Two inputs, joined by position_id (NOT by date proximity — that join is the
# #2317 defect, project_audit_join_date_proximity):
#   trade_audit.sexp : position_id -> ticket_age_weeks_at_fill
#   trades.csv       : position_id -> pnl_dollars
#
# REQUIRES a post-#2317 run: before that fix ticket_age_weeks_at_fill could only
# read 0 or 1 (the 7-day reach-back), and every bucket above 1 week is empty.
# The script refuses to report if that signature is present.
#
# Both trades.csv columns it reads (position_id, pnl_dollars) are resolved by
# NAME from the file's own header and the script refuses if either is absent —
# no fixed indices, no fallback. See the comment above the resolution below.
#
# Usage: sh rest_time_pnl.sh <trade_audit.sexp> <trades.csv>

SEXP=${1:?usage: rest_time_pnl.sh <trade_audit.sexp> <trades.csv>}
CSV=${2:?usage: rest_time_pnl.sh <trade_audit.sexp> <trades.csv>}

# position_id -> fill age in weeks. Only the FIRST position_id of each record is
# the entry's own; the ones under alternatives_considered are other candidates.
awk '
  /\(\(entry$/ { pid = ""; age = ""; in_rec = 1; next }
  in_rec && pid == "" && /\(position_id / {
    v = $0; sub(/.*\(position_id /, "", v); sub(/\).*/, "", v); pid = v
  }
  in_rec && age == "" && /\(ticket_age_weeks_at_fill / {
    v = $0; sub(/.*\(ticket_age_weeks_at_fill /, "", v); sub(/\).*/, "", v); age = v
    if (pid != "") { print pid "\t" age; in_rec = 0 }
  }
' "$SEXP" | sort -u > /tmp/_ages.tsv

AGES=$(wc -l < /tmp/_ages.tsv | tr -d ' ')
echo "tickets with a fill age: $AGES"
[ "$AGES" -gt 0 ] || { echo "  none — pre-PR-5 artifact, or no fills"; exit 0; }

MAXAGE=$(cut -f2 /tmp/_ages.tsv | sort -n | tail -1)
echo "max fill age (weeks): $MAXAGE"
if [ "$MAXAGE" -le 1 ]; then
  echo "REFUSING to report: max age <= 1 week is the pre-#2317 date-proximity"
  echo "join signature. This artifact cannot measure rest time."
  exit 1
fi

# trades.csv columns are resolved by NAME from the file's own header, never by
# fixed index. position_id sits INSIDE the trailing per-trade context block
# (stop_fill_distance_pct already follows it), so any writer that inserts at or
# ahead of it shifts the index and a positional read silently returns a
# neighbouring cell. This mirrors Trades_csv_schema.of_header_line
# (trading/trading/backtest/lib/trades_csv_schema.mli), whose contract is
# "silently reading the wrong cell is worse than reading nothing" — hence the
# hard refusal below rather than a fallback index.
COLS=$(head -n 1 "$CSV" | awk -F, '
  { for (i = 1; i <= NF; i++) {
      name = $i
      gsub(/^[ \t]+/, "", name); gsub(/[ \t\r]+$/, "", name)
      if (name == "position_id") pid = i
      if (name == "pnl_dollars") pnl = i
    }
    printf "%d %d\n", pid + 0, pnl + 0 }')
PID_COL=${COLS% *}
PNL_COL=${COLS#* }
if [ "$PID_COL" -eq 0 ] || [ "$PNL_COL" -eq 0 ]; then
  echo "REFUSING to report: cannot resolve trades.csv columns by header name"
  echo "  (position_id -> ${PID_COL}, pnl_dollars -> ${PNL_COL}; 0 = absent)."
  echo "  A layout without position_id cannot be joined on it, and this script"
  echo "  does not fall back to a fixed column index. See"
  echo "  trading/trading/backtest/lib/trades_csv_schema.mli."
  exit 1
fi
echo "trades.csv columns from header: position_id=$PID_COL pnl_dollars=$PNL_COL"

awk -F, -v pid="$PID_COL" -v pnl="$PNL_COL" \
  'NR > 1 && $pid != "" { print $pid "\t" $pnl }' "$CSV" | sort -u > /tmp/_pnl.tsv
echo "round trips with a position_id: $(wc -l < /tmp/_pnl.tsv | tr -d ' ')"

join -t "$(printf '\t')" /tmp/_ages.tsv /tmp/_pnl.tsv > /tmp/_rest_pnl.tsv
echo "joined: $(wc -l < /tmp/_rest_pnl.tsv | tr -d ' ')"
echo

awk -F'\t' '
  function bucket(w) {
    if (w <= 1) return "1 <=1wk"
    if (w <= 4) return "2 2-4wk"
    if (w <= 13) return "3 5-13wk"
    if (w <= 26) return "4 14-26wk"
    if (w <= 52) return "5 27-52wk"
    if (w <= 156) return "6 1-3yr"
    return "7 >3yr"
  }
  { b = bucket($2 + 0); n[b]++; p[b] += $3; tot += $3; tn++
    if ($3 > 0) w[b]++ }
  END {
    printf "%-10s %6s %7s %14s %11s %6s\n", "bucket", "n", "share", "pnl_$", "per_trade", "win%"
    for (k in n)
      printf "%-10s %6d %6.1f%% %14.0f %11.0f %5.0f%%\n",
             substr(k, 3), n[k], 100 * n[k] / tn, p[k], p[k] / n[k], 100 * (w[k] + 0) / n[k]
    printf "%-10s %6d %6.1f%% %14.0f\n", "TOTAL", tn, 100, tot
  }' /tmp/_rest_pnl.tsv | sort

echo
echo "== what each candidate clock would have cut =="
awk -F'\t' '
  { age = $2 + 0; pnl = $3
    if (age > 13)  { n13++;  p13 += pnl }
    if (age > 26)  { n26++;  p26 += pnl }
    if (age > 52)  { n52++;  p52 += pnl }
    if (age > 156) { n156++; p156 += pnl }
    tot += pnl; tn++ }
  END {
    printf "  clock 13w : cuts %4d fills, %12.0f of %12.0f realized (%.1f%%)\n", n13+0, p13+0, tot, 100*(p13+0)/tot
    printf "  clock 26w : cuts %4d fills, %12.0f of %12.0f realized (%.1f%%)\n", n26+0, p26+0, tot, 100*(p26+0)/tot
    printf "  clock 52w : cuts %4d fills, %12.0f of %12.0f realized (%.1f%%)\n", n52+0, p52+0, tot, 100*(p52+0)/tot
    printf "  clock 156w: cuts %4d fills, %12.0f of %12.0f realized (%.1f%%)\n", n156+0, p156+0, tot, 100*(p156+0)/tot
  }' /tmp/_rest_pnl.tsv

echo
echo "  NOTE: a cut is not a counterfactual. Removing a fill frees its capital,"
echo "  which the walk redeploys — these figures bound the GROSS effect only."

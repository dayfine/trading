#!/bin/sh
# positions.sh -- one row per position (closed trade or open position) of both arms of every seed, keyed by
# symbol|entry_date (the firstdiff key), classed shared / P-only / S-only, with its NAV contribution.
#
# usage: sh positions.sh RESULTS_DIR [DATA_DIR] > positions.tsv
#
# contribution $ = pnl_dollars + dividends_received (trades.csv $9 + $25; pnl_dollars excludes dividends: the gap
# between $9 and (exit-entry)*qty is <= 1 cent/share and does not track $25). Open positions are marked at the last
# raw close on or before END = 2026-06-25 (bar store, read-only; only the mark/entry ratio and the $ gain are printed, never a bar).
# nav_pct = 100 * contribution / the arm's NAV on the last equity-curve date <= entry_date ("of entry NAV").
# band = #3587 price_band of the entry price: 0 (<8) 1 [8,14) 2 [14,33) 3 (>=33).
# Columns: seed class arm symbol entry_date exit_date status entry_price band qty contrib nav_entry nav_pct pnl_pct
R=${1:?usage: sh positions.sh RESULTS_DIR [DATA_DIR]}; D=${2:-data}; END=2026-06-25   # the last equity-curve date; marks there reproduce actual.sexp open_positions_value exactly (k0 S and P)
T=${TMPDIR:-/tmp}/positions.$$; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
printf 'seed\tclass\tarm\tsymbol\tentry_date\texit_date\tstatus\tentry_price\tband\tqty\tcontrib\tnav_entry\tnav_pct\tpnl_pct\n'
for k in 0 1 2 3 4; do
  for a in S P; do
    p=$R/k$k/pb-$a-k$k-s0-
    # open positions: symbol,side,entry_date,entry_price,quantity -> add the mark ratio
    awk -F, 'FNR > 1 { print $1, $3, $4, $5 }' "${p}open_positions.csv" | while read -r sym d px q; do
      l1=$(printf %s "$sym" | cut -c1); l2=$(printf %s "$sym" | rev | cut -c1 | tr '[:lower:]' '[:upper:]')
      f=$D/$l1/$l2/$sym/data.csv
      if [ -f "$f" ]; then m=$(awk -F, -v e="$END" -v px="$px" 'FNR > 1 && $1 <= e { c = $5 } END { if (c) printf "%.6f", c / px; else print "NA" }' "$f")
      else m=NA; fi
      echo "$sym,$d,$px,$q,$m"
    done > "$T/open-$a-$k.csv"
  done
  awk -F, -v OFS='\t' -v k="k$k" -v T="$T" -v kk="$k" '
    function band(x) { return (x >= 8) + (x >= 14) + (x >= 33) }
    function navat(arm, d,   lo, hi, mid) {   # last curve date <= d (binary search over sorted dates)
      lo = 1; hi = nc[arm]; if (cd[arm, 1] > d) return cv[arm, 1]
      while (lo < hi) { mid = int((lo + hi + 1) / 2); if (cd[arm, mid] <= d) lo = mid; else hi = mid - 1 }
      return cv[arm, lo] }
    FILENAME ~ /equity_curve/ { if (FNR == 1) next; arm = (FILENAME ~ /pb-P-/) ? "P" : "S"; nc[arm]++; cd[arm, nc[arm]] = $1; cv[arm, nc[arm]] = $2; next }
    FILENAME ~ /trades\.csv$/ { if (FNR == 1) next; arm = (FILENAME ~ /pb-P-/) ? "P" : "S"
      key = $1 "|" $3; row[arm, key] = $1 OFS $3 OFS $4 OFS "closed" OFS $6 OFS band($6 + 0) OFS $8
      con[arm, key] = $9 + $25; ppct[arm, key] = $10; ent[arm, key] = $3; has[arm, key] = 1; keys[key] = 1; next }
    FILENAME ~ /open-/ { arm = (FILENAME ~ /open-P-/) ? "P" : "S"; key = $1 "|" $2
      g = ($5 == "NA") ? "NA" : ($5 - 1); row[arm, key] = $1 OFS $2 OFS "-" OFS "open" OFS $3 OFS band($3 + 0) OFS $4
      con[arm, key] = (g == "NA") ? 0 : $4 * $3 * g; ppct[arm, key] = (g == "NA") ? "NA" : sprintf("%.2f", 100 * g)
      ent[arm, key] = $2; has[arm, key] = 1; keys[key] = 1; next }
    END { for (key in keys) {
        cls = (has["S", key] && has["P", key]) ? "shared" : (has["P", key] ? "P-only" : "S-only")
        for (i = 1; i <= 2; i++) { arm = (i == 1) ? "S" : "P"; if (!has[arm, key]) continue
          n = navat(arm, ent[arm, key])
          printf "%s\t%s\t%s\t%s\t%.2f\t%.2f\t%.4f\t%s\n", k, cls, arm, row[arm, key], con[arm, key], n, 100 * con[arm, key] / n, ppct[arm, key] } } }
  ' "$R/k$k/pb-S-k$k-s0-equity_curve.csv" "$R/k$k/pb-P-k$k-s0-equity_curve.csv" \
    "$R/k$k/pb-S-k$k-s0-trades.csv" "$R/k$k/pb-P-k$k-s0-trades.csv" "$T/open-S-$k.csv" "$T/open-P-$k.csv" | sort -t "$(printf '\t')" -k5,5 -k4,4 -k3,3
done

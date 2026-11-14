#!/bin/sh
# positions.sh -- one row per position (closed trade or open position) of both arms of every seed of one cell, keyed
# by symbol|entry_date (the firstdiff key), classed shared / P-only / S-only, with its NAV contribution.
# Adapted from ../../price-band-tiebreak-2026-11-13/results/read/positions.sh (#3595). Two changes:
#   1. the cell tag is a parameter, and the open-position mark date is each arm's last equity-curve date;
#   2. trades.csv entry_price is restated for splits during the hold (#3595 §Defects 2, #3384). Column 15 is
#      entry_price / the RAW close on the entry date (bar store): near 1 for a fill on the raw basis, the in-hold split
#      factor for a restated row. The band (column 9) is the band of entry_price when that ratio is within 0.80-1.25
#      (#3595 basis_check's "raw" test), else the band of the raw close. Without a bar file the band falls back to
#      entry_price and column 15 reads NA.
#
# usage: sh positions.sh RESULTS_DIR TAG [DATA_DIR] > positions-TAG.tsv
#   TAG = pbc1 | pbc2, or pb with RESULTS_DIR = the #3595 results (a reproduction check)
#
# contribution $ = pnl_dollars + dividends_received (trades.csv $9 + $25). Open positions are marked at the last raw
# close on or before the arm's last equity-curve date. nav_pct = 100 * contribution / the arm's NAV on the last
# equity-curve date <= entry_date ("of entry NAV"). Raw closes stay in a temporary file and are never printed; only
# bands, ratios and dollar results are.
# Columns: seed class arm symbol entry_date exit_date status entry_price band qty contrib nav_entry nav_pct pnl_pct px_ratio
R=${1:?usage: sh positions.sh RESULTS_DIR TAG [DATA_DIR]}; T=${2:?TAG}; D=${3:-data}
TMP=${TMPDIR:-/tmp}/pbc-positions.$$; mkdir -p "$TMP"; trap 'rm -rf "$TMP"' EXIT

# 1. Every (symbol, date) whose raw close is needed: entry dates, and the mark date of open positions.
for k in 0 1 2 3 4; do
  for a in S P; do
    p=$R/k$k/$T-$a-k$k-s0-; [ -f "${p}trades.csv" ] || continue
    end=$(tail -1 "${p}equity_curve.csv" | cut -d, -f1)
    awk -F, 'FNR > 1 { print $1 "\t" $3 }' "${p}trades.csv"
    awk -F, -v e="$end" 'FNR > 1 { print $1 "\t" $3; print $1 "\t" e }' "${p}open_positions.csv"
  done
done | LC_ALL=C sort -u |
awk -F'\t' '{ if ($1 != s) { if (s != "") print s "\t" ds; s = $1; ds = $2 } else ds = ds "," $2 } END { if (s != "") print s "\t" ds }' |
while IFS="$(printf '\t')" read -r sym dates; do
  l1=$(printf %s "$sym" | cut -c1); l2=$(printf %s "$sym" | rev | cut -c1 | tr '[:lower:]' '[:upper:]')
  f=$D/$l1/$l2/$sym/data.csv
  [ -f "$f" ] || continue
  awk -F, -v s="$sym" -v ds="$dates" '
    BEGIN { n = split(ds, want, ","); i = 1 }
    FNR == 1 { next }
    { while (i <= n && $1 > want[i]) { if (have) print s "\t" want[i] "\t" last; i++ } if (i > n) exit
      last = $5; have = 1; if ($1 == want[i]) { print s "\t" want[i] "\t" last; i++ } }
    END { while (i <= n) { if (have) print s "\t" want[i] "\t" last; i++ } }' "$f"
done > "$TMP/raw.tsv"

# 2. Positions, joined to the raw closes.
printf 'seed\tclass\tarm\tsymbol\tentry_date\texit_date\tstatus\tentry_price\tband\tqty\tcontrib\tnav_entry\tnav_pct\tpnl_pct\tpx_ratio\n'
for k in 0 1 2 3 4; do
  [ -f "$R/k$k/$T-S-k$k-s0-trades.csv" ] && [ -f "$R/k$k/$T-P-k$k-s0-trades.csv" ] || continue
  awk -F'[,\t]' -v OFS='\t' -v k="k$k" '
    function band(x) { return (x >= 8) + (x >= 14) + (x >= 33) }
    function navat(arm, d,   lo, hi, mid) {   # last curve date <= d (binary search over sorted dates)
      lo = 1; hi = nc[arm]; if (cd[arm, 1] > d) return cv[arm, 1]
      while (lo < hi) { mid = int((lo + hi + 1) / 2); if (cd[arm, mid] <= d) lo = mid; else hi = mid - 1 }
      return cv[arm, lo] }
    function rawb(sym, d, px,   r) {   # the fill price unless it is split-restated (ratio outside 0.80-1.25)
      if (!((sym "|" d) in raw) || raw[sym "|" d] + 0 <= 0) return band(px + 0)
      r = px / raw[sym "|" d]; return (r >= 0.80 && r <= 1.25) ? band(px + 0) : band(raw[sym "|" d] + 0) }
    function ratio(sym, d, px) { return ((sym "|" d) in raw && raw[sym "|" d] + 0 > 0) ? sprintf("%.3f", px / raw[sym "|" d]) : "NA" }
    FILENAME ~ /raw\.tsv$/ { raw[$1 "|" $2] = $3; next }
    FILENAME ~ /equity_curve/ { if (FNR == 1) next; arm = (FILENAME ~ /-P-k/) ? "P" : "S"; nc[arm]++; cd[arm, nc[arm]] = $1; cv[arm, nc[arm]] = $2; next }
    FILENAME ~ /trades\.csv$/ { if (FNR == 1) next; arm = (FILENAME ~ /-P-k/) ? "P" : "S"
      key = $1 "|" $3; row[arm, key] = $1 OFS $3 OFS $4 OFS "closed" OFS $6 OFS rawb($1, $3, $6) OFS $8
      con[arm, key] = $9 + $25; ppct[arm, key] = $10; ent[arm, key] = $3; rat[arm, key] = ratio($1, $3, $6)
      has[arm, key] = 1; keys[key] = 1; next }
    FILENAME ~ /open_positions\.csv$/ { if (FNR == 1) next; arm = (FILENAME ~ /-P-k/) ? "P" : "S"; key = $1 "|" $3
      e = cd[arm, nc[arm]]; m = ((($1 "|" e) in raw)) ? raw[$1 "|" e] / $4 : "NA"; g = (m == "NA") ? "NA" : (m - 1)
      row[arm, key] = $1 OFS $3 OFS "-" OFS "open" OFS $4 OFS rawb($1, $3, $4) OFS $5
      con[arm, key] = (g == "NA") ? 0 : $5 * $4 * g; ppct[arm, key] = (g == "NA") ? "NA" : sprintf("%.2f", 100 * g)
      ent[arm, key] = $3; rat[arm, key] = ratio($1, $3, $4); has[arm, key] = 1; keys[key] = 1; next }
    END { for (key in keys) {
        cls = (has["S", key] && has["P", key]) ? "shared" : (has["P", key] ? "P-only" : "S-only")
        for (i = 1; i <= 2; i++) { arm = (i == 1) ? "S" : "P"; if (!has[arm, key]) continue
          n = navat(arm, ent[arm, key])
          printf "%s\t%s\t%s\t%s\t%.2f\t%.2f\t%.4f\t%s\t%s\n", k, cls, arm, row[arm, key], con[arm, key], n,
            100 * con[arm, key] / n, ppct[arm, key], rat[arm, key] } } }
  ' "$TMP/raw.tsv" "$R/k$k/$T-S-k$k-s0-equity_curve.csv" "$R/k$k/$T-P-k$k-s0-equity_curve.csv" \
    "$R/k$k/$T-S-k$k-s0-trades.csv" "$R/k$k/$T-P-k$k-s0-trades.csv" \
    "$R/k$k/$T-S-k$k-s0-open_positions.csv" "$R/k$k/$T-P-k$k-s0-open_positions.csv" |
    sort -t "$(printf '\t')" -k5,5 -k4,4 -k3,3
done

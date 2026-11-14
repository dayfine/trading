#!/bin/sh
# split.sh -- the pre-registered read of stale-e-cap-k5-2026-11-14 (../README.md §Decision rule, §The price/size split,
# §Reported regardless). POSIX sh + awk; reads only the committed per-arm artifacts, plus the bar store for the
# open-position marks when DATA_DIR is given.
#
# usage: sh split.sh RESULTS_DIR [DATA_DIR] > read.txt
#   RESULTS_DIR holds k0..k4/ as `chain.sh collect` writes them: sec-{S,C}-kK-s0-{tickets.tsv,entries.tsv,trades.csv,
#     open_positions.csv,equity_curve.csv,splits.csv,actual.sexp}, sec-C-kK-s0.v6diff-S.log and chain-kK.log.
#   DATA_DIR (optional) is the bar store (data/<first letter>/<last letter>/<SYMBOL>/data.csv). Open positions are then
#     marked at the last raw close on or before the arm's last equity-curve date. Without it they are left out of every
#     NAV-% sum, and the outcome is printed as PROVISIONAL (the in-session read in chain.sh is that case).
#   VALIDITY=skip reads pairs without the chain's validity lines (the local smoke only). Default: check.
#   KEYS=FILE also writes the per-key rows (keys.awk) to FILE. With DATA_DIR they carry marked open-position
#     contributions, from which a raw close can be recovered, so that file is never committed.
# Only summaries reach stdout: counts, NAV-% sums, ratios and simulator dollars. No price or bar is printed.
R=${1:?usage: sh split.sh RESULTS_DIR [DATA_DIR]}; D=${2:-}
LIB=$(cd "$(dirname "$0")/lib" && pwd)
TMP=$(mktemp -d "${TMPDIR:-/tmp}/sec-split.XXXXXX"); trap 'rm -rf "$TMP"' EXIT
: > "$TMP/rows.tsv"

marks() { # $1 S prefix, $2 C prefix -> symbol, date, raw close of every open position at its arm's last curve date
  for p in "$1" "$2"; do
    e=$(tail -1 "${p}equity_curve.csv" | cut -d, -f1)
    awk -F, -v e="$e" 'FNR > 1 { print $1 "\t" e }' "${p}open_positions.csv"
  done | LC_ALL=C sort -u | while IFS="$(printf '\t')" read -r sym d; do
    l1=$(printf %s "$sym" | cut -c1); l2=$(printf %s "$sym" | rev | cut -c1 | tr '[:lower:]' '[:upper:]')
    f=$D/$l1/$l2/$sym/data.csv; [ -f "$f" ] || continue
    awk -F, -v s="$sym" -v d="$d" 'FNR > 1 && $1 <= d { last = $5; have = 1 } END { if (have) print s "\t" d "\t" last }' "$f"
  done
}

metrics() { # $1 seed, $2 arm, $3 prefix -> one M row
  awk -v k="$1" -v a="$2" '
    FILENAME ~ /actual\.sexp$/ { l = $0; gsub(/[()]/, " ", l); m = split(l, t, " "); for (i = 1; i < m; i++) v[t[i]] = t[i + 1]; next }
    FILENAME ~ /trades\.csv$/ { if (FNR > 1) { n++; if ($10 + 0 >= 100) b++ } next }
    FILENAME ~ /open_positions\.csv$/ { if (FNR > 1) o++; next }
    END { printf "M\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\t%d\n", k, a, v["total_return_pct"], v["max_drawdown_pct"], v["sharpe_ratio"],
          v["ulcer_index"], n, o, b }' FS=, "$3actual.sexp" "$3trades.csv" "$3open_positions.csv"
}

validity() { # $1 seed dir, $2 K -> one V row
  v6=missing; f=$1/sec-C-k$2-s0.v6diff-S.log
  [ -f "$f" ] && { [ "$(tail -1 "$f")" = exit=0 ] && v6=ok || v6=fail; }
  tw=missing; ab=missing; l=$1/chain-k$2.log
  if [ -f "$l" ]; then
    if grep -q "TRIPWIRE MATCH sec-S-k$2-s0 " "$l"; then tw=match
    elif grep -q "TRIPWIRE WAIVED for sec-S-k$2-s0:" "$l"; then tw=waived
    elif grep -q "TRIPWIRE MISMATCH sec-S-k$2-s0 " "$l"; then tw=mismatch; fi
    na=$(grep -E "RESULT sec-[SC]-k$2-s0 " "$l" | grep -c 'n_symbols_absent=1 ')
    nr=$(grep -cE "RESULT sec-[SC]-k$2-s0 " "$l")
    [ "$nr" = 2 ] && { [ "$na" = 2 ] && ab=ok || ab=bad; }
  fi
  printf 'V\tk%s\t%s\t%s\t%s\n' "$2" "$v6" "$tw" "$ab"
}

# A stop-gate skip does not depend on the portfolio, so any S seed's record of one is evidence for every seed.
cat "$R"/k[0-4]/sec-S-k[0-4]-s0-entries.tsv 2>/dev/null |
  awk -F'\t' '$4 == "skipped" && ($6 == "No_structural_stop" || $6 == "Stop_too_wide") { print $2 "|" $3 }' | LC_ALL=C sort -u > "$TMP/gate.tsv"

for k in 0 1 2 3 4; do
  d=$R/k$k; s=$d/sec-S-k$k-s0-; c=$d/sec-C-k$k-s0-
  for f in tickets.tsv entries.tsv trades.csv open_positions.csv equity_curve.csv splits.csv actual.sexp; do
    [ -f "$s$f" ] && [ -f "$c$f" ] || continue 2; done
  validity "$d" "$k" >> "$TMP/rows.tsv"
  metrics "k$k" S "$s" >> "$TMP/rows.tsv"; metrics "k$k" C "$c" >> "$TMP/rows.tsv"
  mk=""; if [ -n "$D" ]; then marks "$s" "$c" > "$TMP/marks-k$k.tsv"; mk=$TMP/marks-k$k.tsv; fi
  awk -v seed="k$k" -f "$LIB/keys.awk" "$TMP/gate.tsv" $mk \
    "${s}equity_curve.csv" "${c}equity_curve.csv" "${s}splits.csv" "${c}splits.csv" "${s}tickets.tsv" "${c}tickets.tsv" \
    "${s}entries.tsv" "${c}entries.tsv" "${s}trades.csv" "${c}trades.csv" "${s}open_positions.csv" "${c}open_positions.csv" \
    | LC_ALL=C sort -t "$(printf '\t')" -k1,1 -k2,2 -k3,3 >> "$TMP/rows.tsv"
done
[ -n "${KEYS:-}" ] && grep '^K' "$TMP/rows.tsv" > "$KEYS"
awk -v validity="${VALIDITY:-check}" -v marked="$([ -n "$D" ] && echo 1 || echo 0)" -f "$LIB/summary.awk" "$TMP/rows.tsv"

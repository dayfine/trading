#!/bin/sh
# m3183.sh -- README §"#3183: symbol-class membership" reads M1-M4 from the committed policy-run outputs
# (results/3183/membership.csv, dropped.csv, the "on" arm's per-list reports) and the committed pit-v12 lists:
#   M1  per vintage: committed n, off n, on n, dropped = off - on split warrant / unit / non-USD (chain.sh's suffix
#       counts), the off-vs-committed dual-class collapse (the control), and the class drops the "on" report lists
#       (larger than off - on when the off arm's dual-class collapse already removed a twin warrant); totals
#   M2  every dropped name: the lists it is dropped from, its rank and avg_dollar_volume range in the committed lists
#       (rank = position in the list, which is sorted by avg_dollar_volume); then each #3183 specimen: the lists it is
#       a committed member of, and the lists whose "on" report excludes it by class
#   M3  dropped names in rk-k0's trades.csv (traded), and their rows in W0's entries extract (placed / skipped)
#   M4  members of the on-lists spelled -WT, -U, -R, -RI, -RT (membership.csv's missed_spellings_in_on), per name:
#       the lists, rank and avg_dollar_volume range
#
# usage: sh m3183.sh RESULTS_3183_DIR LISTS_DIR RECORD_TRADES_CSV W0_ENTRIES_TSV
#   RESULTS_3183_DIR   dev/experiments/chain-w-2026-11-10/results/3183
#   LISTS_DIR          trading/test_data/backtest_scenarios/pit-v12/composition
#   RECORD_TRADES_CSV  dev/experiments/record-kseed-2026-10-27/results/rk-k0-s0-trades.csv
#   W0_ENTRIES_TSV     dev/experiments/chain-w-2026-11-10/results/cw-W0-s0-entries.tsv
set -u
M=${1:?usage: sh m3183.sh RESULTS_3183_DIR LISTS_DIR RECORD_TRADES_CSV W0_ENTRIES_TSV}; L=${2:?}; K=${3:?}; E=${4:?}
W=${TMPDIR:-/tmp}/m3183.$$; mkdir -p "$W"; trap 'rm -rf "$W"' EXIT
SPECIMENS="HSBA CELSIA SBER CTRA_old AIG-WS C-WS-A LHC-UN LDG"

# rank and avg_dollar_volume of every member of every committed list: list, symbol, rank, adv
for f in "$L"/top-*-*.sexp; do
  b=$(basename "$f" .sexp)
  tr -s '\n\t ' '   ' < "$f" | awk -v b="$b" '{
    s = $0
    while (match(s, /\(symbol [^ )]+\)/)) { sym = substr(s, RSTART + 8, RLENGTH - 9); s = substr(s, RSTART + RLENGTH)
      adv = ""; if (match(s, /\(avg_dollar_volume [^ )]+\)/)) adv = substr(s, RSTART + 19, RLENGTH - 20)
      print b "\t" sym "\t" (++r) "\t" adv } }'
done > "$W/ranks"
# class drops listed by each "on" report: list, symbol, class
for f in "$M"/top-*-*.report.txt; do
  b=$(basename "$f" .report.txt)
  awk -v b="$b" '/^\[/ { sec = $1 } sec == "[symbol_class_exclusion]" && /symbol class excluded/ {
      sym = $2; sub(/:$/, "", sym); cls = $NF; sub(/^\(Symbol_class\./, "", cls); sub(/\)$/, "", cls); print b "\t" sym "\t" cls }' "$f"
done > "$W/classdrops"

echo "M1 per vintage (list, committed, off, on, dropped=off-on, warrant, unit, non-USD, dual-class collapse=committed-off, class drops in the on report):"
cut -f1 "$W/classdrops" | LC_ALL=C sort | uniq -c | awk '{ print $2 "," $1 }' > "$W/ncd"
awk -F, 'FILENAME == ARGV[1] { n[$1] = $2; next } FNR > 1 {
    printf "  %s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%d\t%d\n", $1, $2, $3, $4, $5, $6, $7, $8, $2 - $3, n[$1]
    td += $5; tw += $6; tu += $7; tn += $8; tc += $2 - $3; tr += n[$1]; nl++; if ($5 == 0) z = z " " $1 }
  END { printf "  totals over %d lists: dropped %d (warrant %d, unit %d, non-USD %d); dual-class collapse %d; class drops in the reports %d\n", nl, td, tw, tu, tn, tc, tr
        printf "  lists with nothing dropped:%s\n", z }' "$W/ncd" "$M/membership.csv"

echo "M2 dropped names (name, lists dropped from, rank min-max, avg_dollar_volume min-max in the committed lists):"
awk -F'\t' 'FILENAME == ARGV[1] { r[$1 "|" $2] = $3; a[$1 "|" $2] = $4; next }
  { split($0, p, ","); k = p[1] "|" p[2]; s = p[2]; n[s]++
    if (!(s in rmin) || r[k] + 0 < rmin[s]) rmin[s] = r[k] + 0; if (r[k] + 0 > rmax[s]) rmax[s] = r[k] + 0
    if (!(s in amin) || a[k] + 0 < amin[s]) amin[s] = a[k] + 0; if (a[k] + 0 > amax[s]) amax[s] = a[k] + 0 }
  END { for (s in n) printf "  %-10s %2d lists  rank %d-%d  adv %.3g-%.3g\n", s, n[s], rmin[s], rmax[s], amin[s], amax[s] }' \
  "$W/ranks" "$M/dropped.csv" | LC_ALL=C sort -k2,2nr -k1,1
echo "  distinct names: $(cut -d, -f2 "$M/dropped.csv" | LC_ALL=C sort -u | wc -l | tr -d ' '), list-drops: $(wc -l < "$M/dropped.csv" | tr -d ' ')"
echo "M2 specimens (committed member of N lists; excluded by class in M of them; lists where a member was not excluded):"
for s in $SPECIMENS; do
  awk -F'\t' -v s="$s" '$2 == s { print $1 }' "$W/ranks" | LC_ALL=C sort -u > "$W/in"
  awk -F'\t' -v s="$s" '$2 == s { print $1 }' "$W/classdrops" | LC_ALL=C sort -u > "$W/out"
  miss=$(LC_ALL=C comm -23 "$W/in" "$W/out" | tr '\n' ' ')
  echo "  $s: member of $(wc -l < "$W/in" | tr -d ' '), excluded in $(wc -l < "$W/out" | tr -d ' ')${miss:+; kept in: $miss}"
done

echo "M3 dropped names traded by rk-k0 s0:"
cut -d, -f2 "$M/dropped.csv" | LC_ALL=C sort -u > "$W/dropped"
cut -d, -f1 "$K" | sed 1d | LC_ALL=C sort -u > "$W/traded"
t=$(LC_ALL=C comm -12 "$W/dropped" "$W/traded" | tr '\n' ' '); echo "  ${t:-none}"
echo "M3 dropped names in W0's entries extract (decision date, kind, skip reason):"
awk -F'\t' 'FILENAME == ARGV[1] { d[$1] = 1; next } ($2 in d) { printf "  %s %s %s %s\n", $2, $3, $4, $6 }' "$W/dropped" "$E"

echo "M4 on-list members spelled -WT, -U, -R, -RI, -RT (name, lists, rank min-max, avg_dollar_volume min-max):"
awk -F, 'NR > 1 && $10 != "" { n = split($10, x, " "); for (i = 1; i <= n; i++) if (x[i] != "") print $1 "\t" x[i] }' "$M/membership.csv" > "$W/m4"
awk -F'\t' 'FILENAME == ARGV[1] { r[$1 "|" $2] = $3; a[$1 "|" $2] = $4; next }
  { k = $1 "|" $2; s = $2; n[s]++
    if (!(s in rmin) || r[k] + 0 < rmin[s]) rmin[s] = r[k] + 0; if (r[k] + 0 > rmax[s]) rmax[s] = r[k] + 0
    if (!(s in amin) || a[k] + 0 < amin[s]) amin[s] = a[k] + 0; if (a[k] + 0 > amax[s]) amax[s] = a[k] + 0 }
  END { for (s in n) printf "  %-10s %2d lists  rank %d-%d  adv %.3g-%.3g\n", s, n[s], rmin[s], rmax[s], amin[s], amax[s] }' \
  "$W/ranks" "$W/m4" | LC_ALL=C sort -k2,2nr -k1,1
echo "  distinct names: $(cut -f2 "$W/m4" | LC_ALL=C sort -u | wc -l | tr -d ' '), list-memberships: $(wc -l < "$W/m4" | tr -d ' ')"

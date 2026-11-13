#!/bin/sh
# The trait-Y population screen (PREREG.md) that motivated the price-band tiebreak. Host only, POSIX sh + awk, no
# container; about 15 min. Reads the gitignored bar store data/ (EODHD; never committed) and the committed pit-v12
# lists. Writes everything to WORK; only the aggregate tables in results/ are committed.
# usage: sh dev/experiments/price-band-tiebreak-2026-11-13/screen/screen.sh WORK      (from the repo root)
#   1. windows.tsv  every pit-v12 top-3000 list Y as (symbol, Y-05-31, Y+1-05-30)
#   2. events.tsv   every book-style weekly breakout of a member in its window (lib/mscan.awk; 20,195 rows on 11-13)
#   3. ytrait-capped.txt  quintile cut-offs from the 2000-2012 events, the pass rule in both halves (lib/ytrait.awk)
#   3b. price-bands.txt  the same events split by the tiebreak's fixed bands $8 / $14 / $33 (lib/bands.awk)
#   4. funnel-by-price.txt  the 08-23 monster funnel split by raw price at the monster's start
set -u
WORK=${1:?usage: screen.sh WORK}; mkdir -p "$WORK"
D=dev/experiments/price-band-tiebreak-2026-11-13/screen; L=$D/lib
P=trading/test_data/backtest_scenarios/pit-v12/composition
FUN=dev/experiments/instrumented-record-2026-08-23/results/monster-ep100-outcomes.tsv
path() { awk '{ printf "data/%s/%s/%s/data.csv", toupper(substr($0, 1, 1)), toupper(substr($0, length($0), 1)), $0 }'; }

for y in $(seq 1999 2025); do
  grep -o '(symbol [^)]*)' "$P/top-3000-$y.sexp" | sed 's/(symbol //; s/)//' | awk -v y="$y" '{ print $1 "\t" y "-05-31\t" (y + 1) "-05-30" }'
done > "$WORK/windows.tsv"
awk -F, -f "$L/gspc_weekly.awk" data/G/X/GSPC.INDX/data.csv > "$WORK/gspc_weekly.tsv"

: > "$WORK/events.tsv"
cut -f1 "$WORK/windows.tsv" | sort -u | while read -r s; do
  f=$(printf '%s\n' "$s" | path); [ -f "$f" ] || continue
  awk -F'\t' -v s="$s" '$1 == s' "$WORK/windows.tsv" > "$WORK/w1.tsv"
  awk -F'\t' -v SYM="$s" -f "$L/mscan.awk" "$WORK/gspc_weekly.tsv" "$WORK/w1.tsv" "$f" >> "$WORK/events.tsv"
done
echo "events: $(wc -l < "$WORK/events.tsv")"

# Quintile cut-offs per trait column (6-15, 17) from the 2000-2012 events; column 16 (regime) is binary.
CUTS=""
for c in 6 7 8 9 10 11 12 13 14 15 17; do
  cs=$(awk -F'\t' -v c="$c" 'substr($2, 1, 4) <= "2012" && $c != "" { print $c }' "$WORK/events.tsv" | sort -g |
    awk '{ v[NR] = $1 } END { printf "%s,%s,%s,%s", v[int(NR / 5)], v[int(2 * NR / 5)], v[int(3 * NR / 5)], v[int(4 * NR / 5)] }')
  CUTS="$CUTS$c:$cs;"
done
awk -F'\t' -v OFS='\t' -v CAP=1.90 -v CUTS="$CUTS" -f "$L/ytrait.awk" "$WORK/events.tsv" > "$WORK/ytrait-capped.txt"
awk -F'\t' -v CAP=1.90 -f "$L/bands.awk" "$WORK/events.tsv" > "$WORK/price-bands.txt"

# Funnel: raw close on or before each monster's start date, then the stage share per price band.
awk -F'\t' '{ print $1 "\t" $2 "\t" $5 }' "$FUN" | sort -k1,1 > "$WORK/funnel.tsv"
cut -f1 "$WORK/funnel.tsv" | sort -u | while read -r s; do
  f=$(printf '%s\n' "$s" | path); [ -f "$f" ] || continue
  awk -F'\t' -v s="$s" '$1 == s { print $2 "\t" $3 }' "$WORK/funnel.tsv" > "$WORK/f1.tsv"
  awk -F, -v s="$s" 'FNR == NR { split($0, a, "\t"); d[a[1]] = a[2]; next }
    FNR > 1 { dt[++n] = $1; c[n] = $5 }
    END { for (x in d) { best = 0; for (i = 1; i <= n; i++) if (dt[i] <= x) best = i; print s "\t" x "\t" d[x] "\t" (best ? c[best] : "") } }' "$WORK/f1.tsv" "$f"
done > "$WORK/funnel_price.tsv"
awk -F'\t' '$4 != "" { p = $4 + 0; b = (p < 8) ? "1 <$8" : (p < 14) ? "2 $8-14" : (p < 33) ? "3 $14-33" : "4 >$33"; n[b]++; st[b, $3]++; S[$3] = 1 }
  END { for (b in n) { printf "%-8s n=%4d", b, n[b]; for (s in S) printf " | %s %4.1f%%", s, 100 * st[b, s] / n[b]; print "" } }' \
  "$WORK/funnel_price.tsv" | sort > "$WORK/funnel-by-price.txt"
echo "wrote $WORK/ytrait-capped.txt $WORK/price-bands.txt $WORK/funnel-by-price.txt"

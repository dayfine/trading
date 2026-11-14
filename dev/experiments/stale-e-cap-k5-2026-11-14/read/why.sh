#!/bin/sh
# why.sh -- the derived tables behind the stale-e-cap-k5 Results "Why" (results-analyst, 2026-11-14).
# POSIX sh + awk. Prints NAV-%, %, ratios, counts and dates only: no price, mark or dollar figure.
#
# usage: sh read/why.sh MERGED KEYS PACKS SCREEN > why.txt
#   MERGED  a results dir holding k0..k4/ with BOTH the public files (entries.tsv, actual.sexp, chain log) and the
#           price-bearing ones from dayfine/trading-results (tickets.tsv, trades.csv, equity_curve.csv, ...),
#           e.g. symlinks of both trees.
#   KEYS    the per-key file written by `KEYS=FILE sh read/split.sh MERGED data` (never committed: open-leg rows
#           carry marks). Only rows with no open leg (column 25 = 0) are read here.
#   PACKS   the review-pack root holding kK/site/data/{S,C,G}_nav.json, spy.json, spy_warmup.json (not committed).
#   SCREEN  ../entry-timing-screen-2026-11-12/results (the committed replay-kK.csv).
# The regime rule is the pack's (dev/lib/review_pack/index.html spyRegimeByDay): SPY weekly close vs its 30-week
# MA and the MA's 4-week slope, known at the week's last close, applied to the following week.
M=${1:?MERGED}; K=${2:?KEYS}; P=${3:?PACKS}; SC=${4:?SCREEN}
LIB=$(cd "$(dirname "$0")/lib" && pwd); T=$(mktemp -d "${TMPDIR:-/tmp}/why.XXXXXX"); trap 'rm -rf "$T"' EXIT

echo "== 1. Max-drawdown episode per arm and seed (equity_curve.csv)"
for k in 0 1 2 3 4; do for a in S C G; do
  awk -F, -v t="k$k $a" 'NR > 1 { v = $2 + 0; if (v > pk) { pk = v; pkd = $1 } dd = 1 - v / pk; if (dd > m) { m = dd; tr = $1; mp = pkd } }
    END { printf "%s maxDD %.2f%% peak %s trough %s\n", t, 100 * m, mp, tr }' "$M/k$k/sec-$a-k$k-s0-equity_curve.csv"
done; done

echo; echo "== 2. Each arm over C's episode (2007-07-19..2009-07-08) and the dot-com bear (2000-01-03..2003-03-31)"
for w in "2007-07-19 2009-07-08" "2000-01-03 2003-03-31"; do set -- $w
  for k in 0 1 2 3 4; do for a in S C G; do
    awk -F, -v a="$1" -v b="$2" -v t="k$k $a" 'NR > 1 && $1 >= a && $1 <= b { v = $2 + 0; if (!s) s = v; e = v; if (v > pk) pk = v; dd = 1 - v / pk; if (dd > m) m = dd }
      END { printf "%s %s..%s return %+.1f%% maxDD inside %.1f%%\n", t, a, b, 100 * (e / s - 1), 100 * m }' "$M/k$k/sec-$a-k$k-s0-equity_curve.csv"
  done; done; done

echo; echo "== 3. Tickets placed (capped) and entries by year, bear and recovery years (tickets.tsv, trades.csv, equity_curve.csv)"
for y in 2000 2001 2002 2007 2008 2009; do for k in 0 1 2 3 4; do line="$y k$k"
  for a in S C G; do d=$M/k$k/sec-$a-k$k-s0-
    r=$(awk -F'\t' -v y=$y 'FNR > 1 && substr($3, 1, 4) == y && $4 == "Long" { n++; if ($5 == "Local_range_top") c++ } END { printf "%d/%d", n, c }' "${d}tickets.tsv")
    e=$(awk -F, -v y=$y 'FILENAME ~ /equity/ { if (FNR > 1) { cd[++nc] = $1; cv[nc] = $2 } next }
      FNR > 1 && substr($3, 1, 4) == y { lo = 1; hi = nc; while (lo < hi) { mid = int((lo + hi + 1) / 2); if (cd[mid] <= $3) lo = mid; else hi = mid - 1 }
        s += 100 * ($9 + $25) / cv[lo]; n++; if ($9 > 0) w++ } END { printf "%d entries %+.1f NAV-%% (%d won)", n, s, w }' "${d}equity_curve.csv" "${d}trades.csv")
    line="$line | $a tickets/capped $r, $e"; done; echo "$line"; done; done

echo; echo "== 4. S's recorded lists in 2001, 2002, 2008: Fridays, placed, stop-gate skips, other skips (entries.tsv)"
for k in 0 1 2 3 4; do
  awk -F'\t' -v k=$k 'FNR > 1 { y = substr($3, 1, 4); if (y != "2001" && y != "2002" && y != "2008") next; f[y, $3] = 1
      if ($4 == "placed") p[y]++; else if ($6 == "No_structural_stop" || $6 == "Stop_too_wide") g[y]++; else o[y]++ }
    END { for (y in p) { n = 0; for (x in f) { split(x, z, SUBSEP); if (z[1] == y) n++ }
      printf "k%d %s Fridays %d placed %d gate-skips %d other %d\n", k, y, n, p[y], g[y], o[y] } }' "$M/k$k/sec-S-k$k-s0-entries.tsv"
done | sort -k2,2 -k1,1
echo "C's keys by year (S:C, pooled): all C-placed keys, of which capped admissions (KEYS)"
awk -F'\t' '$1 == "S:C" && $25 == 0 && $5 != "PS" { y = substr($4, index($4, "|") + 1, 4); if (y == "2001" || y == "2002" || y == "2008") { n[y]++; if ($5 == "PC" && $6 == 1) a[y]++ } }
  END { for (y in n) print y, n[y], a[y] + 0 }' "$K" | sort

echo; echo "== 5. Exposure and return by period x SPY regime (pack site data)"
flat() { tr -d '[]"' < "$1" | tr ',' ' ' | awk -v n="$2" '{ for (i = 1; i <= NF; i += n) { l = $i; for (j = 1; j < n; j++) l = l " " $(i + j); print l } }'; }
for k in 0 1 2 3 4; do D=$P/k$k/site/data
  { flat "$D/spy_warmup.json" 3 | awk '$1 < "2000-01-03" { print $1, $2 }'; flat "$D/spy.json" 2; } > "$T/spy.txt"
  for a in S C G; do flat "$D/${a}_nav.json" 4 | awk -v a=$a '{ print a, $1, $2, $3 }'; done > "$T/nav.txt"
  awk -f "$LIB/regime.awk" "$T/spy.txt" "$T/nav.txt" | sort -k1,1 -k2,2 | sed "s/^/k$k /"
  for a in S C G; do tr -d '[]"' < "$D/${a}_nav.json" | tr ',' '\n' | awk -v t="k$k $a" 'NR % 4 == 3 { inv += $1 } NR % 4 == 0 { pos += $1; n++ }
    END { printf "%s mean positions %.1f, mean invested %.1f%%\n", t, pos / n, inv / n }'; done
  awk -v seed=k$k 'FILENAME ~ /nav\.txt/ { if ($1 == "C") inv[$2] = $4; if ($1 == "S") sinv[$2] = $4; next }
    $1 == "S:C" && $3 == seed && $5 == "PS" && $25 == 0 && ($20 == "nolist" || $20 == "skip:Insufficient_cash") { split($4, x, "|"); g = ($20 == "nolist") ? "no C list" : "C cash skip"
      n[g]++; s[g] += inv[x[2]]; ss[g] += sinv[x[2]]; if (inv[x[2]] >= 65) h[g]++ }
    END { for (g in n) printf "k%s S-only tickets, %s: n %d, C invested that Friday %.1f%% (>= 65%% on %d), S %.1f%%\n", substr(seed, 2), g, n[g], s[g] / n[g], h[g], ss[g] / n[g] }' FS=' ' "$T/nav.txt" FS='\t' "$K"
done

echo; echo "== 6. Admissions vs the S tickets C could not take: per-trade return distribution (KEYS, tickets, trades)"
for k in 0 1 2 3 4; do d=$M/k$k
  awk -v seed=k$k -F'[\t,]' -f "$LIB/cohort.awk" "$K" "$d/sec-C-k$k-s0-equity_curve.csv" "$d/sec-S-k$k-s0-equity_curve.csv" \
    "$d/sec-C-k$k-s0-tickets.tsv" "$d/sec-S-k$k-s0-tickets.tsv" "$d/sec-C-k$k-s0-trades.csv" "$d/sec-S-k$k-s0-trades.csv"
done | sort -k2,2 -k1,1
echo "stop width (fraction of the ticket's trigger), k0: S all, C capped admissions, G capped (tickets.tsv)"
q() { sort -g | awk -v t="$1" '{ x[NR] = $1 } END { printf "%-26s n %4d p10 %.3f p50 %.3f p90 %.3f\n", t, NR, x[int(NR * .1) + 1], x[int(NR * .5) + 1], x[int(NR * .9) + 1] }'; }
awk -F'\t' 'FNR > 1 && $4 == "Long" { print $7 }' "$M/k0/sec-S-k0-s0-tickets.tsv" | q "S k0 all"
awk -F'\t' 'FILENAME == ARGV[1] { if ($1 == "S:C" && $3 == "k0" && $5 == "PC" && $6 == 1) a[$4] = 1; next } FNR > 1 && ($2 "|" $3) in a { print $7 }' "$K" "$M/k0/sec-C-k0-s0-tickets.tsv" | q "C k0 capped admissions"
awk -F'\t' 'FNR > 1 && $5 == "Local_range_top" { print $7 }' "$M/k0/sec-G-k0-s0-tickets.tsv" | q "G k0 capped"

echo; echo "== 7. Capped keys both arms filled, by fill week (fill age S vs test arm), per seed and pooled (KEYS)"
for pr in S:G S:C; do
  awk -F'\t' -v pr=$pr '$1 == pr && $5 == "MF" && $6 == 1 && $25 == 0 { d = $21 - $22; g = (d > 0) ? "test earlier" : ((d < 0) ? "test later" : "same week")
      t[$3, g] += $12 - $11; n[g]++; p[g] += $13; z[g] += $14; e[g] += $15; s[g] += $12 - $11
      b = (d <= 0) ? "0" : (d == 1) ? "1" : (d <= 3) ? "2-3" : (d <= 8) ? "4-8" : "9+"; bn[b]++; bs[b] += $12 - $11; if ($4 !~ /^(ROL|LMT)\|/) bx[b] += $12 - $11 }
    END { for (g in n) { line = sprintf("%s %-12s pooled n %3d price %+6.2f size %+6.2f exit %+7.2f total %+7.2f | per seed", pr, g, n[g], p[g], z[g], e[g], s[g])
            for (k = 0; k <= 4; k++) line = line sprintf(" %+.2f", t["k" k, g]); print line }
          for (b in bn) printf "%s gap %-4s weeks: n %3d total %+7.2f, without ROL/LMT %+7.2f\n", pr, b, bn[b], bs[b], bx[b] }' "$K" | sort
done
echo "the screen's H2' gain by replay fill timing (screen replay-kK.csv, NAV-% vs its null)"
for k in 0 1 2 3 4; do
  awk -F, -v k=$k 'NR > 1 && $4 != "NODATA" && $10 == 1 && $19 != "-" && $21 != "" && !($14 < $15 * 1.005 - 1e-9) { d = 100 * ($32 - $22) / $9
      g = ($29 < $19) ? "earlier" : (($29 == $19) ? "same" : "later"); n[g]++; s[g] += d; t += d }
    END { printf "k%d total %+.2f", k, t; for (g in n) printf " | %s n %d %+.2f (%.0f%%)", g, n[g], s[g], 100 * s[g] / t; print "" }' "$SC/replay-k$k.csv"
done

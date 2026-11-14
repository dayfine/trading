#!/bin/sh
# analyst_checks.sh -- every derived figure the results-analyst draft quotes for price-band-binding-2026-11-13,
# computed from COMMITTED files only (this cell's results/cell/ and #3595's results/k0..k4). POSIX sh + awk.
# usage: sh analyst_checks.sh <repo root>
# Prints aggregates and per-trade results already in committed trades.csv; never a bar or a price from the store.
set -u
ROOT=${1:?usage: sh analyst_checks.sh <repo root>}
B=$ROOT/dev/experiments/price-band-binding-2026-11-13/results/cell
T=$ROOT/dev/experiments/price-band-tiebreak-2026-11-13/results
R=$B/read
TAB=$(printf '\t')

echo "== A. cell parity: every per-arm artifact against #3595 pb-S-k0"
for s in actual.sexp trades.csv equity_curve.csv splits.csv open_positions.csv entries.tsv summary.sexp \
         macro_trend.sexp validator.sexp.sexp validator.sexp.md params.sexp; do
  a=$( (md5sum "$B/pbb-S-k0-s0-$s" 2>/dev/null || md5 -r "$B/pbb-S-k0-s0-$s") | cut -c1-32)
  b=$( (md5sum "$T/k0/pb-S-k0-s0-$s" 2>/dev/null || md5 -r "$T/k0/pb-S-k0-s0-$s") | cut -c1-32)
  [ "$a" = "$b" ] && echo "  same  $s" || echo "  DIFF  $s (expected only for params.sexp: code_version, data_dir)"
done

echo "== B. proxy precondition, strict denominator (every placed ticket)"
sed -n 's/.*: \([0-9]*\) of \([0-9]*\) placed tickets.*; \([0-9]*\) without a bar.*/\1 \2 \3/p' "$R/selfcheck.txt" |
  awk '{ printf "  agree %d of %d with a bar = %.1f %%; of all %d placed = %.1f %% (bar 90 %%)\n", $1, $2, 100*$1/$2, $2+$3, 100*$1/($2+$3) }'

echo "== C. E_net arithmetic from binding.txt (README Measurement 2) and its sensitivity"
awk '
  /^fill ratio/ { fill = $5 / $9 }
  /expected tickets re-drawn in/ { nb++; I[nb] = $(NF-5) + 0; O[nb] = $(NF-3) + 0 }
  END {
    split("9 10 8 15", K, " "); split("112 217 828 1685", N, " "); split("<$8 $8-14 $14-33 >=$33", L, " ")
    for (b = 1; b <= 4; b++) r[b] = K[b] / N[b]
    for (b = 1; b <= 4; b++) { d = I[b] - O[b]; c = fill * d * r[b]; e += c; v += (d * sqrt(K[b]) / N[b])^2; ti += I[b]; to += O[b]; vi += I[b] * r[b]; vo += O[b] * r[b]
      printf "  %-7s in %6.2f out %6.2f net %+7.2f r %.5f -> %+.3f\n", L[b], I[b], O[b], d, r[b], c }
    printf "  E_net %.3f (fill %.4f); Poisson SE from the pooled counts %.3f\n", e, fill, fill * sqrt(v)
    printf "  in tickets %.1f (%.1f %% under $14), value %.4f each; out tickets %.1f (%.1f %% >= $33), value %.4f each\n", ti, 100*(I[1]+I[2])/ti, vi/ti, to, 100*O[4]/to, vo/to
    printf "  net value per re-drawn in-ticket after fills %.4f (pre-registration assumed 0.0166)\n", e / ti
    split("9 5 13 15", K2, " "); split("112 212 833 1685", N2, " "); for (b = 1; b <= 4; b++) e2 += fill * (I[b]-O[b]) * K2[b] / N2[b]
    printf "  E_net with ADSK 2003-09-15 (5 doublers, 5 entries) in its decision band $14-33: %.3f\n", e2
    for (b = 1; b <= 4; b++) { k = (I[b]-O[b] > 0) ? K[b] + sqrt(K[b]) : K[b] - sqrt(K[b]); e3 += fill * (I[b]-O[b]) * k / N[b] }
    printf "  E_net with every rate 1 SE in P favour: %.3f (FRESH bar 1.5)\n", e3
    printf "  log value at 0.10-0.15 per doubler (pre-registration): %.3f-%.3f\n", 0.10*e, 0.15*e
  }' "$R/binding.txt"

echo "== D. distinct >= +100 % trades behind r(b), #3595 S cells (band of trades.csv entry_price)"
for k in 0 1 2 3 4; do
  awk -F, 'NR > 1 && $10 + 0 >= 100 { p = $6 + 0; print (p >= 8) + (p >= 14) + (p >= 33) "\t" $1 "|" $3 }' "$T/k$k/pb-S-k$k-s0-trades.csv"
done | awk -F'\t' '{ n[$1]++; d[$1 SUBSEP $2]++ }
  END { for (b = 0; b <= 3; b++) { s = ""; m = 0; for (k in d) { split(k, a, SUBSEP); if (a[1] == b) { m++; s = s " " a[2] " x" d[k] } }
        printf "  band %d: %d trades, %d distinct:%s\n", b, n[b], m, s } }'

echo "== E. log value of each >= +100 % trade: ln(1 + (pnl_dollars + dividends_received) / NAV on the entry date)"
for arm in S P; do for k in 0 1 2 3 4; do
  awk -F, -v ARM=$arm -v K=$k 'FNR == NR { if (FNR > 1) { nd++; D[nd] = $1; V[nd] = $2 } next }
    FNR > 1 && $10 + 0 >= 100 { i = 1; nav = V[1]; while (i <= nd && D[i] <= $3) { nav = V[i]; i++ }
      printf "%s\t%s\t%.4f\n", ARM, $1 "|" $3, log(1 + ($9 + $25) / nav) }' \
    "$T/k$k/pb-$arm-k$k-s0-equity_curve.csv" "$T/k$k/pb-$arm-k$k-s0-trades.csv"
done; done | LC_ALL=C sort -t "$TAB" -k1,1 -k3,3n | awk -F'\t' '{ n[$1]++; s[$1] += $3; v[$1, n[$1]] = $3 }
  END { for (a in n) { m = (n[a] % 2) ? v[a, (n[a]+1)/2] : (v[a, n[a]/2] + v[a, n[a]/2+1]) / 2
        printf "  %s cells: %d trades, median %.3f, mean %.3f log each\n", a, n[a], m, s[a]/n[a] } }'
for k in 0 1 2 3 4; do
  s=$(awk -F, 'NR > 1 && $10 + 0 >= 100' "$T/k$k/pb-S-k$k-s0-trades.csv" | wc -l | tr -d ' ')
  p=$(awk -F, 'NR > 1 && $10 + 0 >= 100' "$T/k$k/pb-P-k$k-s0-trades.csv" | wc -l | tr -d ' ')
  echo "  k$k: >= +100 % closed trades S $s, P $p, P - S $((p - s))"
done

echo "== F. swaps traced to the arms' own walks (#3595 P-k0 ran the band order on its own path; V6 vs S-k0 agree)"
trace() { # $1 side  $2 entries.tsv  $3 trades.csv  $4 label
  awk -F'\t' -v DIR="$1" -v TR="$3" -v LAB="$4" 'BEGIN { while ((getline l < TR) > 0) { split(l, t, ","); if (t[20] != "position_id") R[t[20]] = t[3] " " t[6] " " t[10] } }
    FNR == NR { if (FNR > 1 && $4 == "placed") PID[$3, $2] = $1; next }
    FNR > 1 && $2 == DIR && (($1, $3) in PID) { id = PID[$1, $3]; n[$4]++; if (id in R) { split(R[id], q, " "); c[$4]++; if (q[3] + 0 >= 100) big[$4] = big[$4] " " $3 "(" $1 " " sprintf("%+.0f", q[3]) "%)" } }
    END { for (b = 0; b <= 3; b++) if (n[b]) printf "  %s band %d: placed %d, closed trades %d, >= +100 %%:%s\n", LAB, b, n[b], c[b], big[b] }' "$2" "$R/swaps.tsv"
}
trace in  "$T/k0/pb-P-k0-s0-entries.tsv" "$T/k0/pb-P-k0-s0-trades.csv" "swapped in,  placed by P-k0 that date:"
trace out "$B/pbb-S-k0-s0-entries.tsv"   "$B/pbb-S-k0-s0-trades.csv"   "swapped out, placed by S-k0 that date:"
trace out "$T/k0/pb-P-k0-s0-entries.tsv" "$T/k0/pb-P-k0-s0-trades.csv" "swapped out, placed by P-k0 anyway:   "
awk -F'\t' 'NR > 1 { n[$6]++ } END { printf "  walk rows on S-k0 placement Fridays: %d, of which No_structural_stop %d (%.1f %%)\n", NR - 1, n["No_structural_stop"], 100 * n["No_structural_stop"] / (NR - 1) }' "$B/pbb-S-k0-s0-entries.tsv"

echo "== G. swap rows the store truncates (tail.awk dedup replicated: one row per side and symbol per 182 days)"
tail -n +2 "$R/swaps.tsv" | LC_ALL=C sort -s -t "$TAB" -k1,1 | awk -F'\t' '
  function days(d,   y, m, dd) { y = substr(d,1,4)+0; m = substr(d,6,2)+0; dd = substr(d,9,2)+0; if (m < 3) { y--; m += 12 }
    return 365*y + int(y/4) - int(y/100) + int(y/400) + int((153*(m-3)+2)/5) + dd }
  { last = lk[$2, $3]; if (last != "" && days($1) - days(last) < 182) next; lk[$2, $3] = $1; n[$2]++
    if ($1 >= "2025-06-27") a[$2]++; if ($1 > "2025-09-12") b[$2]++ }
  END { for (s in n) printf "  %-3s deduped %d (committed swap_tail.txt must match); dated >= 2025-06-27: %d; after 2025-09-12: %d\n", s, n[s], a[s], b[s] }'
grep '^deduped rows' "$R/swap_tail.txt" | sed 's/^/  committed: /'

echo "== H. what the FD - F difference implies for the D rows (one-decimal means, so ranges)"
awk 'function num(s, key,   t) { t = s; sub(".*" key "[ ]*", "", t); sub(/[ %].*/, "", t); return t + 0 }
  /^  swapped in / && !f { nFi = num($0, "n="); mFi = num($0, "mean ride") } /^  swapped out / && !f { nFo = num($0, "n="); mFo = num($0, "mean ride") }
  /^screen convention F/ { f = 1 } f && /^  swapped in / { nGi = num($0, "n="); mGi = num($0, "mean ride") } f && /^  swapped out / { nGo = num($0, "n="); mGo = num($0, "mean ride") }
  END { for (s = 1; s <= 2; s++) { nF = (s == 1) ? nFi : nFo; mF = (s == 1) ? mFi : mFo; nG = (s == 1) ? nGi : nGo; mG = (s == 1) ? mGi : mGo
          nD = nF - nG
          lo = (nF * (mF - 0.05) - nG * (mG + 0.05)) / nD; hi = (nF * (mF + 0.05) - nG * (mG - 0.05)) / nD
          printf "  %s: FD n %d mean %+.1f, F n %d mean %+.1f -> %d D rows, mean between %+.1f and %+.1f %%\n", (s == 1) ? "in " : "out", nF, mF, nG, mG, nD, lo, hi } }' "$R/swap_tail.txt"

echo "== I. swaps by half and by year"
awk -F'\t' 'NR > 1 { h = ($1 <= "2012-12-31") ? "2000-12" : "2013-26"; n[$2 " " h]++; if ($2 == "in" && $4 == 0) c[h]++; if ($2 == "out" && $4 < 3) { y = substr($1, 1, 4); o[y]++ } }
  END { printf "  swaps in 2000-12 %d / 2013-26 %d; < $8 swapped in 2000-12 %d / 2013-26 %d\n", n["in 2000-12"], n["in 2013-26"], c["2000-12"], c["2013-26"]
        printf "  swapped-out rows below $33 by year:"; for (y = 2000; y <= 2026; y++) if (o[y]) printf " %d:%d", y, o[y]; print "" }' "$R/swaps.tsv"

echo "== J. fundable share of S's top-20 slots; value of the swapped names the arms placed; standard errors"
awk '/^  (<\$8|\$8-14|\$14-33|>=\$33) +[0-9]+ \// { gsub(/[()%]/, " "); adm += $2; fund += $(NF-3) }
  END { printf "  top-20 slots on open dates %d, fundable %d = %.1f %%, never fundable %.1f %%\n", adm, fund, 100*fund/adm, 100 - 100*fund/adm }' "$R/binding.txt"
awk 'BEGIN { f = 581/683; r0 = 9/112; r1 = 10/217; r2 = 8/828; r3 = 15/1685
  printf "  P-k0 placed swapped-in 8 / 10 / 25 (< $8 / $8-14 / $14-33): %.2f expected doublers at S rates after fills\n", f * (8*r0 + 10*r1 + 25*r2)
  printf "  S-k0 placed swapped-out 7 / 52 ($14-33 / >= $33): %.2f expected doublers\n", f * (7*r2 + 52*r3) }'
awk 'function num(s, key,   t) { t = s; sub(".*" key "[ ]*", "", t); sub(/[ %].*/, "", t); return t + 0 }
  /^primary convention/ { p = 1 } /^screen convention/ { p = 0 }
  p && /^  swapped in / { ni = num($0, "n="); i10 = num($0, "p10"); i90 = num($0, "p90") }
  p && /^  swapped out / { no = num($0, "n="); o10 = num($0, "p10"); o90 = num($0, "p90") }
  /^paired per changed date/ { np = num($0, "n="); q10 = num($0, "p10"); q90 = num($0, "p90"); pos = num($0, "in > out on") }
  END { si = (i90 - i10) / 2.563; so = (o90 - o10) / 2.563; sp = (q90 - q10) / 2.563
        printf "  normal reading of the p10-p90 spread: SD in %.1f, out %.1f pp -> SE of the mean difference %.2f pp (heavier with the capped tail)\n", si, so, sqrt(si*si/ni + so*so/no)
        printf "  paired per date: SD %.1f pp over %d dates -> SE of the mean %.2f pp; sign rate %.1f %% -> z %.2f against 50 %%\n", sp, np, sp/sqrt(np), pos, (pos/100*np - np/2)/sqrt(np/4) }' "$R/swap_tail.txt"

echo "== K. pool sizes and the top-20 change rate by calendar year (fridays.tsv, open dates)"
awk -F'\t' 'NR > 1 && $2 > 0 { n++; s += $3; if (mn == "" || $3 < mn) mn = $3; if ($3 > mx) mx = $3; y = substr($1, 1, 4); o[y]++; c[y] += $8 }
  END { printf "  pool: mean %.0f, min %d, max %d over %d open dates\n", s/n, mn, mx, n
        lo = 101; for (y in o) { r = 100 * c[y] / o[y]; printf "  %s %d/%d = %.0f %%\n", y, c[y], o[y], r; if (r < lo) { lo = r; ly = y } }
        printf "  lowest year: %s at %.0f %%\n", ly, lo }' "$R/fridays.tsv" | LC_ALL=C sort

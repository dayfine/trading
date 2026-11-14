#!/bin/sh
# impact.sh -- decomposes the W0 / Wtd level gap (README T4, the "why") into the gate's own decisions and the
# displacement that followed them. For every one-arm row (arm-only / base-only) and every changed pair whose exit
# changed, from the T3 table (read/t3.sh output) and the trades.csv rows in firstdiff.txt:
#   pnl$    pnl_dollars + dividends_received of the row (the arm that holds it)
#   impact  pnl$ / that arm's NAV on the entry date (equity_curve.csv, last row on or before the date), signed for
#           Wtd - W0: a W0-only row counts negative (W0 earned it, Wtd did not), a Wtd-only row positive; a changed
#           pair counts arm minus base, each over its own arm's NAV
# then the sums by class and by entry year, and the same sums without the single largest |impact| row (the
# perturbation check: does one trade carry the split?). Sizing-only changed pairs scale with NAV and are left out.
#
# usage: sh impact.sh RESULTS_DIR T3_OUTPUT
#   T3_OUTPUT  the stdout of read/t3.sh (its table gives each row's class)
set -u
R=${1:?usage: sh impact.sh RESULTS_DIR T3_OUTPUT}; T3=${2:?}
awk -F'\t' '
  FILENAME == ARGV[1] { if (FNR > 1) { split($0, e, ","); nav0[++n0] = e[2]; d0[n0] = e[1] }; next }
  FILENAME == ARGV[2] { if (FNR > 1) { split($0, e, ","); nav1[++n1] = e[2]; d1[n1] = e[1] }; next }
  FILENAME == ARGV[3] { if (NF >= 11 && $1 != "id(s)") { cls[$3 "|" $4] = $11 }; next }
  $3 == "arm-only" || $3 == "base-only" || $3 == "changed-base" || $3 == "changed-arm" {
    split($4, f, ","); key = $2 "|" $1; c = cls[key]
    arm = ($3 ~ /arm/) ? 1 : 0
    nav = navat(arm, f[3]); p = f[9] + f[25]; imp = (nav > 0) ? p / nav : 0
    if ($3 == "changed-base") { cbp[key] = p; cbi[key] = imp; next }
    if ($3 == "changed-arm") { if (c == "displacement") next          # sizing-only (or a moved week): NAV-scaled
      add(c, key, f[3], p - cbp[key], imp - cbi[key], "changed"); next }
    add(c, key, f[3], p, (arm ? imp : -imp), $3)
  }
  function navat(arm, d,    lo, hi, mid, n) {   # last equity row on or before d
    n = arm ? n1 : n0; lo = 1; hi = n
    while (lo < hi) { mid = int((lo + hi + 1) / 2); if ((arm ? d1[mid] : d0[mid]) <= d) lo = mid; else hi = mid - 1 }
    return arm ? nav1[lo] : nav0[lo]
  }
  function add(c, key, d, p, imp, kind) {
    m++; rk[m] = key; rc[m] = c; rd[m] = d; rp[m] = p; ri[m] = imp; rkind[m] = kind
    s[c] += imp; ns[c]++; y = substr(d, 1, 4); sy[y] += imp; tot += imp
  }
  END {
    printf "%-26s %-12s %-18s %12s %10s\n", "row (symbol|entry)", "kind", "class", "pnl$", "impact%"
    for (i = 1; i <= m; i++) printf "%-26s %-12s %-18s %12.0f %+10.3f\n", rk[i], rkind[i], rc[i], rp[i], 100 * ri[i]
    print ""; print "sum of impact (Wtd - W0, % of NAV) by class:"
    for (c in s) printf "  %-18s %3d rows %+8.3f%%\n", c, ns[c], 100 * s[c]
    printf "  %-18s %3d rows %+8.3f%%\n", "all", m, 100 * tot
    print "by entry year:"; for (y = 2000; y <= 2026; y++) if (y in sy) printf "  %d %+8.3f%%\n", y, 100 * sy[y]
    big = 0; for (i = 1; i <= m; i++) if (ri[i] * ri[i] > big * big) { big = ri[i]; bi = i }
    printf "perturbation: without the largest |impact| row (%s, %s, %+.3f%%): class %s %+.3f%%, all %+.3f%%\n",
      rk[bi], rc[bi], 100 * big, rc[bi], 100 * (s[rc[bi]] - big), 100 * (tot - big)
  }' "$R/cw-W0-s0-equity_curve.csv" "$R/cw-Wtd-s0-equity_curve.csv" "$T3" "$R/firstdiff.txt"

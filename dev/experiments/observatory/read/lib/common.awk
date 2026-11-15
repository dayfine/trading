# common.awk -- helpers shared by pair.awk and row.awk. dn and the Monday-aligned week index come from
# ../../../stale-e-cap-k5-2026-11-14/read/lib/regime.awk, navat from its keys.awk. POSIX awk (mawk, BWK, gawk).
function dn(d,   y, m) {   # days from a fixed origin, for a YYYY-MM-DD date
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; if (m <= 2) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + substr(d, 9, 2)
}
function wk(d) { return int((dn(d) - dn("2000-01-03") + 7000) / 7) }   # 2000-01-03 is a Monday; 7000 = 1000 weeks
function navat(a, d,   lo, hi, mid) {   # arm a's last curve value dated <= d (the first value if d precedes it)
  if (cd[a, 1] > d) return cv[a, 1]
  lo = 1; hi = nc[a]
  while (lo < hi) { mid = int((lo + hi + 1) / 2); if (cd[a, mid] <= d) lo = mid; else hi = mid - 1 }
  return cv[a, lo]
}
function fmt(x, p,   s) {   # fixed-point with p decimals; never prints a negative zero
  s = sprintf("%." p "f", x); if (s ~ /^-0\.?0*$/) s = substr(s, 2)
  return s
}
function sgn(x, p,   s) { s = fmt(x, p); return (s ~ /^-/) ? s : "+" s }   # fmt with an explicit sign

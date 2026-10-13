# Sector strength (copied from short-setup-map-2026-10-12/scripts/sector.awk; symbol from the parent dir): every list member's 26-week (182-day) adjusted return, by sector.
# Usage: awk -f sector.awk dates.txt membership.txt sectors.csv <.../SYM/data.csv ...> (symbol = parent dir name)
# Prints: date,sector,return   (sector "SPY" for SPY itself, whether or not it is a list member).
# The earlier close must sit within 10 days before date-182, else the member is skipped (no stale prices).

function dn(s,   y, m, d) {
  y = substr(s, 1, 4) + 0; m = substr(s, 6, 2) + 0; d = substr(s, 9, 2) + 0
  if (m <= 2) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + d
}
function list_year(s,   y) { y = substr(s, 1, 4) + 0; return (substr(s, 6, 5) >= "05-31") ? y : y - 1 }

FNR == 1 { fi++; if (fi >= 4) { flush(); n = 0; np = split(FILENAME, pp, "/"); sym = pp[np - 1] } }
fi == 1 { ne++; ed[ne] = $1; next }
fi == 2 { split($0, f, " "); for (k = 2; k in f; k++) mem[f[1], f[k]] = 1; next }
fi == 3 { if (FNR > 1) { split($0, f, ","); sec[f[1]] = f[2] } next }
FNR > 1 { split($0, f, ","); if (f[5] + 0 > 0) { n++; dd[n] = f[1]; dk[n] = dn(f[1]); da[n] = f[6] } }
END { flush() }

function flush(   e, j, i0, i1, t0, s) {
  if (n < 2 || sym == "") return
  s = (sym == "SPY") ? "SPY" : sec[sym]
  if (s == "") return
  j = 1
  for (e = 1; e <= ne; e++) {
    if (s != "SPY" && !((sym, list_year(ed[e])) in mem)) continue
    i1 = 0; for (; j <= n && dd[j] <= ed[e]; j++) i1 = j
    if (j > 1 && i1 == 0) i1 = j - 1
    if (i1 == 0 || dd[i1] > ed[e] || dn(ed[e]) - dk[i1] > 10) continue
    t0 = dn(ed[e]) - 182; i0 = 0
    for (k = i1; k >= 1 && dk[k] > t0; k--) ;
    if (k >= 1 && t0 - dk[k] <= 10 && da[k] > 0) print ed[e] "," s "," sprintf("%.5f", da[i1] / da[k] - 1)
  }
}

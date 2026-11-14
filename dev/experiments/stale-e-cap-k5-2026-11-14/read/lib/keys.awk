# keys.awk -- one row per ticket key (symbol|decision_date) of one seed's pair, with each arm's outcome and, for keys
# both arms filled, the price / size / exit split. Definitions: ../../README.md §The price/size split.
#
# Input files, in this order (the arm is read from the file name, "-S-k" or "-C-k"):
#   gate.tsv     symbol|date pairs that any S seed's entries.tsv lists as skipped at the stop gate (split.sh)
#   [marks-kK.tsv]  symbol, date, raw close: the open-position marks (split.sh writes it from DATA; optional)
#   S and C equity_curve.csv, splits.csv, tickets.tsv, entries.tsv, trades.csv, open_positions.csv
# Variables: seed (e.g. k0).
#
# Output rows, tab-separated, prefixed "K" (columns named in split.sh), and "W" warnings.
# Contributions are NAV-%: 100 x (pnl_dollars + dividends_received) / the arm's NAV on the last equity-curve date on or
# before the decision date. Prices never leave this script; only their ratios do.
BEGIN { FS = "[,\t]"; OFS = "\t" }
function arm(f) { return (f ~ /-C-k[0-9]/) ? "C" : "S" }
function navat(a, d,   lo, hi, mid) {   # last curve value dated <= d (binary search; the first value if d precedes it)
  if (nc[a] == 0) return 0
  if (cd[a, 1] > d) return cv[a, 1]
  lo = 1; hi = nc[a]
  while (lo < hi) { mid = int((lo + hi + 1) / 2); if (cd[a, mid] <= d) lo = mid; else hi = mid - 1 }
  return cv[a, lo]
}
function splitf(a, sym, from, to,   i, f) {   # product of this arm's in-hold split factors: from < split date <= to
  f = 1
  for (i = 1; i <= nsp[a]; i++) if (ssym[a, i] == sym && sdt[a, i] > from && sdt[a, i] <= to) f *= sfac[a, i]
  return f
}
function status(a, k,   r) {
  if ((a, k) in st) return st[a, k]
  if (!((a, k) in placed)) return "none"
  r = crs[a, k]
  if (r == "-") return "resting"
  if (r == "entry_fill_rejected_by_portfolio") return "cash"
  if (r == "entry_ticket_ttl_expired") return "ttl"
  if (r == "entry_ticket_requalification_failed") return "requal"
  if (r == "delisted") return "delisted"
  return "cancel:" r
}
function other(a, k, d) {   # what arm a did with this key's symbol on its decision Friday
  if ((a, k) in skip) return "skip:" skip[a, k]
  if (a == "S" && k in gate) return "gate-other-seed"   # another S seed skipped it at the stop gate that Friday
  if ((a, d) in listed) return "notlisted"
  return "nolist"
}
function filled(s) { return s == "closed" || s == "open" }
function dn(d,   y, m) {   # days from a fixed origin, for a YYYY-MM-DD date
  y = substr(d, 1, 4) + 0; m = substr(d, 6, 2) + 0; if (m <= 2) { y--; m += 12 }
  return 365 * y + int(y / 4) - int(y / 100) + int(y / 400) + int((153 * (m - 3) + 2) / 5) + substr(d, 9, 2)
}
function near(a, sym, d,   i, x) {   # 1 when arm a placed the same symbol on another Friday within 28 days
  for (i = 1; i <= nt[a, sym]; i++) { x = dn(tdl[a, sym, i]) - dn(d); if (x != 0 && x >= -28 && x <= 28) return 1 }
  return 0
}
FILENAME ~ /marks-k[0-9]\.tsv$/ { mark[$1 "|" $2] = $3; next }
FILENAME ~ /gate\.tsv$/ { gate[$1] = 1; next }   # symbol|date pairs any S seed skipped at the stop gate (split.sh)
FILENAME ~ /equity_curve\.csv$/ { if (FNR == 1) next; a = arm(FILENAME); nc[a]++; cd[a, nc[a]] = $1; cv[a, nc[a]] = $2; next }
FILENAME ~ /splits\.csv$/ { if (FNR == 1) next; a = arm(FILENAME); nsp[a]++; ssym[a, nsp[a]] = $1; sdt[a, nsp[a]] = $2; sfac[a, nsp[a]] = $3; next }
FILENAME ~ /tickets\.tsv$/ {
  if (FNR == 1 || $4 != "Long") next
  a = arm(FILENAME); k = $2 "|" $3
  if ((a, k) in placed) { print "W", seed, a, "duplicate ticket key " k; next }
  placed[a, k] = 1; keys[k] = 1; ksym[k] = $2; kdate[k] = $3; tid[a, $1] = k
  anc[a, k] = $5; lrt[a, k] = $6; crs[a, k] = $11; fage[a, k] = $13; cav[a, k] = $15
  nt[a, $2]++; tdl[a, $2, nt[a, $2]] = $3
  next
}
FILENAME ~ /entries\.tsv$/ { if (FNR == 1) next; a = arm(FILENAME); listed[a, $3] = 1; if ($4 == "skipped") skip[a, $2 "|" $3] = $6; next }
FILENAME ~ /trades\.csv$/ {
  if (FNR == 1) next
  a = arm(FILENAME)
  if (!((a, $20) in tid)) { print "W", seed, a, "closed trade without a ticket: " $20; next }
  k = tid[a, $20]; st[a, k] = "closed"; ent[a, k] = $3; ext[a, k] = $4; px[a, k] = $6; qty[a, k] = $8; con[a, k] = $9 + $25
  next
}
FILENAME ~ /open_positions\.csv$/ {
  if (FNR == 1) next
  a = arm(FILENAME); best = ""
  for (i = 1; i <= nt[a, $1]; i++) { d = tdl[a, $1, i]; if (d <= $3 && !((a, $1 "|" d) in st) && crs[a, $1 "|" d] == "-" && d > best) best = d }
  if (best == "") { print "W", seed, a, "open position without a ticket: " $1 " " $3; next }
  k = $1 "|" best; e = cd[a, nc[a]]
  st[a, k] = "open"; ent[a, k] = $3; ext[a, k] = e; px[a, k] = $4; qty[a, k] = $5
  if (($1 "|" e) in mark) con[a, k] = $5 * (mark[$1 "|" e] - $4); else { con[a, k] = 0; unm[a, k] = 1 }
  next
}
END {
  for (k in keys) {
    d = kdate[k]; sS = status("S", k); sC = status("C", k)
    pS = ("S", k) in placed; pC = ("C", k) in placed
    cls = (pS && pC) ? (filled(sS) ? (filled(sC) ? "MF" : "RS") : (filled(sC) ? "RC" : "RN")) : (pC ? "PC" : "PS")
    cap = pC ? (anc["C", k] == "Local_range_top" ? 1 : 0) : "-"
    capS = pS ? (anc["S", k] == "Local_range_top" ? 1 : 0) : "-"
    lrtok = (pC && ((lrt["C", k] == 1) != (cap == 1))) ? 0 : 1
    nS = navat("S", d); nC = navat("C", d)
    cS = filled(sS) && nS > 0 ? 100 * con["S", k] / nS : 0
    cC = filled(sC) && nC > 0 ? 100 * con["C", k] / nC : 0
    price = "-"; size = "-"; ex = "-"; lower = "-"; rc = "-"; wr = "-"; fit = "-"; oth = "-"
    if (cls == "MF") {
      fS = splitf("S", ksym[k], ent["S", k], ext["S", k]); fC = splitf("C", ksym[k], ent["C", k], ext["C", k])
      p0S = px["S", k] * fS; q0S = qty["S", k] / fS; p0C = px["C", k] * fC; q0C = qty["C", k] / fC
      u0C = (q0C > 0) ? con["C", k] / q0C : 0
      price = 100 * q0S / nS * (p0S - p0C); size = 100 * (q0C / nC - q0S / nS) * u0C; ex = cC - cS - price - size
      lower = (p0C < p0S - 1e-9) ? 1 : 0; rc = sprintf("%.4f", p0C / p0S); wr = sprintf("%.4f", (q0C / nC) / (q0S / nS))
      price = sprintf("%.4f", price); size = sprintf("%.4f", size); ex = sprintf("%.4f", ex)
    }
    # Would S's position, as a share of NAV, have fitted in the cash C had when it refused its own (larger) fill?
    if (cls == "RS" && sC == "cash") fit = (cav["C", k] != "-" && nS > 0 && cav["C", k] + 0 >= px["S", k] * qty["S", k] / nS * nC) ? 1 : 0
    nr = "-"
    if (cls == "PC") { oth = other("S", k, d); nr = near("S", ksym[k], d) }
    if (cls == "PS") { oth = other("C", k, d); nr = near("C", ksym[k], d) }
    um = (("S", k) in unm || ("C", k) in unm) ? 1 : 0
    print "K", seed, k, cls, cap, capS, lrtok, sS, sC, sprintf("%.4f", cS), sprintf("%.4f", cC), price, size, ex,
      lower, rc, wr, fit, oth, (pS ? fage["S", k] : "-"), (pC ? fage["C", k] : "-"), um, nr
  }
}

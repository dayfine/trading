# gbc.awk -- the gate-before-cap screen (README §Decision rule): on how many open Fridays was a name the shadow calls
# Buyable cut at the top-N while cash for another ticket was free, and how many tickets could that cash have bought?
# POSIX awk.
#
# usage: awk -F'\t' -v M=0.12 -v FILL=0.85 -v HOLD=92 -v G3=0 -v CAP=20 -v FRIDAYS=f.tsv -v CROWD=c.tsv -v GATES=g.txt \
#          -f ../../../price-band-binding-2026-11-13/read/lib/dates.awk -f gbc.awk open.tsv weeks.tsv pool.tsv
#   open.tsv   date open live_blocked                                                        (check.awk OPEN)
#   weeks.tsv  date n_long tickets_placed long_cash_left_pct long_resting_reserved_pct       (cands.awk WEEKS)
#   pool.tsv   the Admitted and Dropped_at_top_n Long rows of rows.tsv, in date order        (cands.awk columns)
# M is m (the median NAV fraction of a placed long ticket's cost), FILL is f (placed -> filled, long tickets).
# Two cash conventions, both reported (README §Definitions):
#   gross  free = long_cash_left_pct                                  (what the walk left unspent this Friday)
#   net    free = max(0, long_cash_left_pct - long_resting_reserved_pct)   (less tickets still resting from earlier
#          Fridays; the decision uses net; NA when the field is absent). Under G3 (reserve_cash_for_resting_tickets,
#          G3=1, off in the record) the walk's budget already excludes them, so net = gross.
# Per open Friday, for each convention: free-cash Friday iff free >= M; slots k = floor(free / M); crowded-out names
# n = the cut rows with shadow Buyable on a free-cash Friday; x = min(n, k), the first x of them in rank order being
# the would-be-funded set C*. Refined (net only): x_ref = E[min(B, k)], B ~ Binomial(n, 1 - s), s = the share of
# Admitted rows on open Fridays that an entry-assembly gate removed before the walk (walk Not_reached).
# Writes FRIDAYS (counts and fractions, no names), CROWD (date symbol rank gross_in_C* net_in_C*; WORK only: names),
# GATES, and prints the gate-before-cap tables. Mark-free: no price, bar or return appears.
FILENAME == ARGV[1] { OP[$1] = $2; next }
FILENAME == ARGV[2] { nwk++; WK[nwk] = $1; CL[$1] = $4; RR[$1] = $5; next }
{
  d = $1; if (OP[d] != 1) next
  if ($3 == "Admitted") {
    adm[d]++; adm_all++
    if ($7 == "Funded") fun[d]++
    else if ($7 == "Not_reached") { nr[d]++; nr_all++ }
    else if ($7 == "Skipped_No_structural_stop") wns[d]++
    else if ($7 == "Skipped_Stop_too_wide") wtw[d]++
    else if ($7 == "Skipped_Insufficient_cash") wca[d]++
    else if ($7 == "Skipped_Already_held") whd[d]++
    else { woth[d]++; woth_all++ }
  } else {
    cut[d]++
    if ($9 == "Buyable") { nb[d]++; BR[d, nb[d]] = $6 + 0; BS[d, nb[d]] = $2 }
    else if ($9 == "No_structural_stop") cns[d]++
    else if ($9 == "Stop_too_wide") ctw[d]++
    else if ($9 == "Already_held") chd[d]++
  }
}
# E[min(B, k)] for B ~ Binomial(n, p): k - sum_{j<k} (k - j) P(B = j), with P computed in logs (no underflow trap).
function emin(n, p, k,   j, lp, q, s) {
  if (k <= 0 || n <= 0) return 0
  if (p >= 1) return (n < k) ? n : k
  if (p <= 0) return 0
  q = 1 - p; lp = n * log(q); s = 0
  for (j = 0; j < k && j <= n; j++) {
    s += (k - j) * exp(lp)
    if (j < n) lp += log((n - j) / (j + 1)) + log(p / q)
  }
  return k - s
}
function slots(free) { return (M > 0 && free >= M) ? int(free / M + 1e-9) : 0 }   # M = 0: no placed ticket (a short preflight)
function yr(d) { return substr(d, 1, 4) }
# The path-aware variant (reported, never decides): each name C* would have funded holds m of cash for HOLD days (the
# cell's avg_holding_days), so a later Friday's free cash is reduced by m per name still held. Convention c: g or n.
function path(c, d, free, n,   t, held, i, k, x) {
  t = days(d); held = 0
  for (i = PH[c] + 1; i <= PQ[c]; i++) { if (t - QD[c, i] >= HOLD) { PH[c] = i; continue } held += QN[c, i] }
  k = slots(free - held * M); x = (n < k) ? n : k
  if (x > 0) { PQ[c]++; QD[c, PQ[c]] = t; QN[c, PQ[c]] = x }
  return x
}
END {
  s = (adm_all > 0) ? nr_all / adm_all : 0
  net_ok = 1
  for (i = 1; i <= nwk; i++) if (OP[WK[i]] == 1) { nopen++; if (RR[WK[i]] == "NA") net_ok = 0 }
  for (i = 1; i <= nwk; i++) {
    d = WK[i]; if (OP[d] != 1) continue
    y = yr(d); YO[y]++; bear = (y == "2000" || y == "2001" || y == "2002" || y == "2008"); if (bear) bear_open++
    fg = CL[d] + 0; kg = slots(fg); ng = (kg > 0) ? nb[d] + 0 : 0; xg = (ng < kg) ? ng : kg
    if (net_ok) { fn = (G3 == 1) ? fg : fg - RR[d]; if (fn < 0) fn = 0; kn = slots(fn); nn = (kn > 0) ? nb[d] + 0 : 0; xn = (nn < kn) ? nn : kn; xr = emin(nn, 1 - s, kn) }
    else { fn = "NA"; kn = "NA"; nn = "NA"; xn = "NA"; xr = "NA" }
    PG += path("g", d, fg, nb[d] + 0); if (net_ok) PN += path("n", d, fn, nb[d] + 0)
    if (kg > 0) { FG++; YFG[y]++ } ; XG += xg; YXG[y] += xg; YCG[y] += ng
    if (net_ok) { if (kn > 0) { FN++; YFN[y]++ }; XN += xn; YXN[y] += xn; YCN[y] += nn; XR += xr; YXR[y] += xr; if (bear) XRB += xr }
    YCUT[y] += cut[d]; YB[y] += nb[d]; YF[y] += fun[d]
    # C*: the first x Buyable cut rows in rank order (bucketed by rank for the report; names go to CROWD only).
    m = nb[d] + 0; delete ord; for (j = 1; j <= m; j++) ord[j] = j
    for (a = 2; a <= m; a++) { t = ord[a]; b = a - 1; while (b >= 1 && BR[d, ord[b]] > BR[d, t]) { ord[b + 1] = ord[b]; b-- } ord[b + 1] = t }
    for (j = 1; j <= m; j++) {
      r = BR[d, ord[j]]; ig = (j <= xg) ? 1 : 0; in_ = (net_ok && j <= xn) ? 1 : 0
      print d "\t" BS[d, ord[j]] "\t" r "\t" ig "\t" in_ > CROWD
      bk = (r <= 40) ? "21-40" : (r <= 100) ? "41-100" : "101+"
      if (ig) RBG[bk]++; if (in_) RBN[bk]++; if (kg > 0) RBA[bk]++
    }
    printf "%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.4f\t%s\t%s\t%d\t%s\t%d\t%s\t%d\t%s\t%s\n", d, adm[d], fun[d], nr[d], wns[d], wtw[d], wca[d], whd[d], woth[d], cut[d], nb[d], cns[d], ctw[d], chd[d], fg, (RR[d] == "NA" ? "NA" : sprintf("%.4f", RR[d])), (fn == "NA" ? "NA" : sprintf("%.4f", fn)), kg, kn, xg, xn, ng, nn, (xr == "NA" ? "NA" : sprintf("%.3f", xr)) > FRIDAYS
  }
  print "== Gate before cap (README §Decision rule; §Definitions) =="
  printf "m (median NAV fraction of a placed long ticket's cost) %.4f | f (placed -> filled, long) %.4f | s (Admitted rows an entry-assembly gate removed: walk Not_reached) %d / %d = %.4f | other non-stop, non-cash skips among Admitted %d\n", M, FILL, nr_all, adm_all, s, woth_all
  printf "open Fridays %d | free-cash Fridays: gross %d, net %s | resting-ticket field: %s\n", nopen, FG, (net_ok ? FN : "NA"), (net_ok ? "present on every open Friday" : "ABSENT on some open Friday: net X is not computable")
  print "year  open  free(g)  free(n)  cut rows  Buyable cut  crowded(g)  crowded(n)  X gross  X net  X ref  placed(funded)"
  for (y = 2000; y <= 2026; y++) if (YO[y] > 0)
    printf "%s  %4d  %7d  %7s  %8d  %11d  %10d  %10s  %7d  %5s  %5s  %d\n", y, YO[y], YFG[y], (net_ok ? YFN[y] + 0 : "NA"), YCUT[y], YB[y], YCG[y], (net_ok ? YCN[y] + 0 : "NA"), YXG[y], (net_ok ? YXN[y] + 0 : "NA"), (net_ok ? sprintf("%.1f", YXR[y]) : "NA"), YF[y]
  printf "total: X gross %d (X.f %.1f) | X net %s (X.f %s) | X ref %s (X.f %s)\n", XG, XG * FILL, (net_ok ? XN : "NA"), (net_ok ? sprintf("%.1f", XN * FILL) : "NA"), (net_ok ? sprintf("%.1f", XR) : "NA"), (net_ok ? sprintf("%.1f", XR * FILL) : "NA")
  printf "path-aware (reported, not in the rule): each would-be-funded name holds m for %d days (avg_holding_days), so later Fridays' cash shrinks: X gross %d, X net %s\n", HOLD, PG, (net_ok ? PN : "NA")
  printf "C* by cut rank (gross / net / every Buyable cut row on a gross free-cash Friday): 21-40 %d / %d / %d, 41-100 %d / %d / %d, 101+ %d / %d / %d\n", RBG["21-40"], RBN["21-40"], RBA["21-40"], RBG["41-100"], RBN["41-100"], RBA["41-100"], RBG["101+"], RBN["101+"], RBA["101+"]
  bx = (net_ok && XR > 0) ? XRB / XR : 0; bo = (nopen > 0) ? bear_open / nopen : 0
  printf "bear years 2000-02 + 2008: share of X ref %s, share of open Fridays %.4f\n", (net_ok ? sprintf("%.4f", bx) : "NA"), bo
  printf "G_m %.6f G_f %.6f G_s %.6f G_XG %d G_net_ok %d G_XN %s G_XR %s G_bear_x %s G_bear_open %.6f G_open %d G_PG %d G_PN %s\n", M, FILL, s, XG, net_ok, (net_ok ? XN : "NA"), (net_ok ? sprintf("%.4f", XR) : "NA"), (net_ok ? sprintf("%.6f", bx) : "NA"), bo, nopen, PG, (net_ok ? PN : "NA") > GATES
}
